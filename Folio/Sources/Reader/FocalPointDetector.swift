import Foundation
import Vision
import CoreGraphics
import UIKit

/// Detects faces in remote images and returns the dominant focal point as
/// CSS-style normalized coordinates (top-left origin, 0…1 in each axis).
/// Cached by URL for the process lifetime. Returns nil if no face is found
/// — the caller falls back to a default crop (e.g. `50% 28%`).
actor FocalPointDetector {
    static let shared = FocalPointDetector()

    /// The crop used when no face is found — identical to article.css's
    /// default `background-position: 50% 28%`, so persisting it as a resolved
    /// focal point changes nothing visually while marking detection as done.
    static let defaultCrop = CGPoint(x: 0.5, y: 0.28)

    private var cache: [URL: CGPoint?] = [:]

    func focalPoint(for url: URL) async -> CGPoint? {
        if let cached = cache[url] { return cached }

        let result = await compute(for: url)
        cache[url] = result
        return result
    }

    private func compute(for url: URL) async -> CGPoint? {
        // Same loader (and cache key) the display views use, so detection
        // shares the display's download and decode instead of re-fetching.
        guard let cgImage = await ImageLoader.shared.image(for: url)?.cgImage else {
            return nil
        }
        return Self.detectFace(in: cgImage)
    }

    private static func detectFace(in image: CGImage) -> CGPoint? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observations = request.results, !observations.isEmpty else {
            return nil
        }

        // Weighted centroid: bigger face boxes pull harder. Vision's boundingBox
        // is bottom-left origin, normalized 0…1 — convert to CSS top-left below.
        var weightedX: CGFloat = 0
        var weightedY: CGFloat = 0
        var totalWeight: CGFloat = 0
        for obs in observations {
            let box = obs.boundingBox
            let weight = box.width * box.height
            weightedX += box.midX * weight
            weightedY += box.midY * weight
            totalWeight += weight
        }
        guard totalWeight > 0 else { return nil }

        let cx = weightedX / totalWeight
        let cy = 1.0 - (weightedY / totalWeight)  // flip Y for CSS top-left origin
        return CGPoint(x: cx, y: cy)
    }
}
