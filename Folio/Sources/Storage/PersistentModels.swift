import Foundation
import SwiftData

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

    init(
        title: String,
        language: String,
        html: String,
        cachedAt: Date = .now,
        focalPointX: Double? = nil,
        focalPointY: Double? = nil
    ) {
        self.title = title
        self.language = language
        self.html = html
        self.cachedAt = cachedAt
        self.focalPointX = focalPointX
        self.focalPointY = focalPointY
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
