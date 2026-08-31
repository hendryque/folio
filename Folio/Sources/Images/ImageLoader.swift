import UIKit
import ImageIO

/// Thread-safe wrapper so the decoded-bitmap cache can be peeked synchronously
/// from view inits. NSCache is documented thread-safe; UIImage is immutable.
private final class DecodedImageCache: @unchecked Sendable {
    private let cache = NSCache<NSString, UIImage>()

    init(totalCostLimit: Int) {
        cache.totalCostLimit = totalCostLimit
    }

    subscript(key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, forKey key: String) {
        let pixels = image.size.width * image.scale * image.size.height * image.scale
        cache.setObject(image, forKey: key as NSString, cost: Int(pixels) * 4)
    }
}

/// Mean luminance measurements, keyed like the bitmap cache. Small enough
/// to keep in a plain dictionary behind a lock.
private final class LuminanceCache: @unchecked Sendable {
    private var values: [String: Double] = [:]
    private let lock = NSLock()

    subscript(key: String) -> Double? {
        get { lock.lock(); defer { lock.unlock() }; return values[key] }
        set { lock.lock(); defer { lock.unlock() }; values[key] = newValue }
    }
}

/// Folio's one image pipeline: a dedicated URLSession with a real disk cache,
/// an NSCache of decoded bitmaps, and in-flight request coalescing. Every
/// remote image in the app — tiles, rows, heroes, lightbox, Vision input —
/// goes through here, so the same URL is never downloaded or decoded twice.
actor ImageLoader {
    static let shared = ImageLoader()

    private static let memory = DecodedImageCache(totalCostLimit: 64 * 1024 * 1024)
    private static let luminance = LuminanceCache()

    private let session: URLSession
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": UserAgent.value]
        // Wikimedia thumbs ship long-lived Cache-Control headers; a properly
        // sized URLCache is the entire disk layer. The shared URLCache refuses
        // responses this large, which is why AsyncImage re-downloaded on every
        // scroll-back.
        config.urlCache = URLCache(
            memoryCapacity: 8 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024
        )
        config.requestCachePolicy = .useProtocolCachePolicy
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
    }

    /// Synchronous memory-cache peek — lets RemoteImage render a cached bitmap
    /// on its first frame instead of flashing a placeholder for one actor hop.
    nonisolated static func cached(_ url: URL, maxPixelSize: CGFloat? = nil) -> UIImage? {
        memory[key(url, maxPixelSize)]
    }

    /// Fetch + decode, cached and coalesced. `maxPixelSize` caps the decoded
    /// bitmap's longest edge (the download is untouched) — pass it when the
    /// source may be far larger than any view, e.g. lightbox originals.
    func image(for url: URL, maxPixelSize: CGFloat? = nil) async -> UIImage? {
        let key = Self.key(url, maxPixelSize)
        if let hit = Self.memory[key] { return hit }
        if let running = inFlight[key] { return await running.value }

        let session = session
        // Detached: decoding is the CPU-heavy part and must not serialize
        // every other load behind this actor.
        let task = Task<UIImage?, Never>.detached(priority: .userInitiated) {
            guard
                let (data, response) = try? await session.data(from: url),
                (response as? HTTPURLResponse).map({ 200..<300 ~= $0.statusCode }) ?? true
            else { return nil }
            let decoded = Self.decode(data, maxPixelSize: maxPixelSize)
            // Measured here, off-main, so the value is ready the moment the
            // image is. Computing it later would darken tiles after they paint.
            if let cg = decoded?.cgImage {
                Self.luminance[key] = Self.titleBandLuminance(cg)
            }
            return decoded
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image { Self.memory.set(image, forKey: key) }
        return image
    }

    /// Warm the caches for images the user is about to see. Fire-and-forget,
    /// low priority; results land in the same memory/disk caches.
    nonisolated func prefetch(_ urls: [URL]) {
        for url in urls {
            Task(priority: .utility) { _ = await self.image(for: url) }
        }
    }

    /// Mean luminance of the band a Today tile puts its title in, or nil if
    /// the image has not been decoded yet.
    nonisolated static func cachedLuminance(_ url: URL, maxPixelSize: CGFloat? = nil) -> Double? {
        luminance[key(url, maxPixelSize)]
    }

    /// Tiles crop 3:4 from the top and set the title 25-58% up from the
    /// bottom, so only that band decides whether white text will hold.
    private nonisolated static func titleBandLuminance(_ image: CGImage) -> Double? {
        let cropH = min(image.height, Int(Double(image.width) * 4.0 / 3.0))
        guard cropH > 0, let visible = image.cropping(
            to: CGRect(x: 0, y: 0, width: image.width, height: cropH)
        ) else { return nil }
        let w = 24, h = 32
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(visible, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return nil }
        let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        var total = 0.0, count = 0
        for y in 0..<h {
            let fromBottom = Double(h - 1 - y) / Double(h)
            guard fromBottom >= 0.25, fromBottom <= 0.58 else { continue }
            for x in 0..<w {
                let i = (y * w + x) * 4
                total += 0.2126 * Double(px[i]) / 255
                    + 0.7152 * Double(px[i + 1]) / 255
                    + 0.0722 * Double(px[i + 2]) / 255
                count += 1
            }
        }
        return count > 0 ? total / Double(count) : nil
    }

    private nonisolated static func key(_ url: URL, _ maxPixelSize: CGFloat?) -> String {
        maxPixelSize.map { "\(url.absoluteString)#\(Int($0))" } ?? url.absoluteString
    }

    private nonisolated static func decode(_ data: Data, maxPixelSize: CGFloat?) -> UIImage? {
        if let maxPixelSize {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
            ]
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            else { return nil }
            return UIImage(cgImage: cgImage)
        }
        // Decompress up front (we're off-main here) so first display during a
        // scroll never pays JPEG decoding on the render loop.
        let image = UIImage(data: data)
        return image?.preparingForDisplay() ?? image
    }
}
