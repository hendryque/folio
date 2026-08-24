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

/// Folio's one image pipeline: a dedicated URLSession with a real disk cache,
/// an NSCache of decoded bitmaps, and in-flight request coalescing. Every
/// remote image in the app — tiles, rows, heroes, lightbox, Vision input —
/// goes through here, so the same URL is never downloaded or decoded twice.
actor ImageLoader {
    static let shared = ImageLoader()

    private static let memory = DecodedImageCache(totalCostLimit: 64 * 1024 * 1024)

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
            return Self.decode(data, maxPixelSize: maxPixelSize)
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
