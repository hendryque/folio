import Foundation
import SwiftData
import CoreGraphics

@Model
final class Bookmark {
    var title: String
    var language: String
    var summary: String?
    var thumbnailURL: URL?
    var addedAt: Date

    init(title: String, language: String, summary: String? = nil, thumbnailURL: URL? = nil, addedAt: Date = .now) {
        self.title = title
        self.language = language
        self.summary = summary
        self.thumbnailURL = thumbnailURL
        self.addedAt = addedAt
    }
}

@Model
final class SearchHistoryEntry {
    var query: String
    var language: String
    var searchedAt: Date

    init(query: String, language: String, searchedAt: Date = .now) {
        self.query = query
        self.language = language
        self.searchedAt = searchedAt
    }
}

@Model
final class HistoryEntry {
    var title: String
    var language: String
    var summary: String?
    var thumbnailURL: URL?
    var readAt: Date
    var scrollY: Double = 0

    init(
        title: String,
        language: String,
        summary: String? = nil,
        thumbnailURL: URL? = nil,
        readAt: Date = .now,
        scrollY: Double = 0
    ) {
        self.title = title
        self.language = language
        self.summary = summary
        self.thumbnailURL = thumbnailURL
        self.readAt = readAt
        self.scrollY = scrollY
    }
}

@Model
final class CachedArticle {
    var title: String
    var language: String
    var html: String
    var cachedAt: Date
    var focalPointX: Double?
    var focalPointY: Double?
    // Persisted so a cached article can mount its WebView — hero, focal crop
    // and all — before the summary round trip returns.
    var heroImageURL: URL?

    init(
        title: String,
        language: String,
        html: String,
        cachedAt: Date = .now,
        focalPointX: Double? = nil,
        focalPointY: Double? = nil,
        heroImageURL: URL? = nil
    ) {
        self.title = title
        self.language = language
        self.html = html
        self.cachedAt = cachedAt
        self.focalPointX = focalPointX
        self.focalPointY = focalPointY
        self.heroImageURL = heroImageURL
    }
}

extension CachedArticle {
    /// Cached HTML older than this still renders instantly; the reader then
    /// refreshes it silently in the background.
    static let ttl: TimeInterval = 24 * 3600

    var isFresh: Bool { Date.now.timeIntervalSince(cachedAt) < Self.ttl }

    var focalPoint: CGPoint? {
        guard let focalPointX, let focalPointY else { return nil }
        return CGPoint(x: focalPointX, y: focalPointY)
    }

    @MainActor
    static func fetch(title: String, language: String, in context: ModelContext) -> CachedArticle? {
        let descriptor = FetchDescriptor<CachedArticle>(
            predicate: #Predicate { entry in
                entry.title == title && entry.language == language
            }
        )
        return try? context.fetch(descriptor).first
    }

    /// Insert-or-update. Nil `focalPoint`/`heroImageURL` leave any previously
    /// stored value in place — callers pass what they know, not a full row.
    @MainActor
    static func upsert(
        title: String,
        language: String,
        html: String,
        focalPoint: CGPoint? = nil,
        heroImageURL: URL? = nil,
        in context: ModelContext
    ) {
        if let existing = fetch(title: title, language: language, in: context) {
            existing.html = html
            existing.cachedAt = .now
            if let focalPoint {
                existing.focalPointX = focalPoint.x
                existing.focalPointY = focalPoint.y
            }
            if let heroImageURL {
                existing.heroImageURL = heroImageURL
            }
        } else {
            context.insert(
                CachedArticle(
                    title: title,
                    language: language,
                    html: html,
                    focalPointX: focalPoint.map { Double($0.x) },
                    focalPointY: focalPoint.map { Double($0.y) },
                    heroImageURL: heroImageURL
                )
            )
        }
        try? context.save()
    }
}

@Model
final class AppSettings {
    var defaultLanguage: String
    var theme: String
    var fontScale: Double

    init(defaultLanguage: String = "en", theme: String = Theme.system.rawValue, fontScale: Double = 1.0) {
        self.defaultLanguage = defaultLanguage
        self.theme = theme
        self.fontScale = fontScale
    }

    static var `default`: AppSettings { AppSettings() }
}
