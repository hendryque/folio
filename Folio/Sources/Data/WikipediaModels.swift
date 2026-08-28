import Foundation

struct ArticleSummary: Decodable, Identifiable, Hashable, Sendable {
    let title: String
    let displayTitle: String?
    let description: String?
    let extract: String?
    let extractHTML: String?
    let thumbnail: ImageRef?
    let originalImage: ImageRef?
    let contentURLs: ContentURLs?
    let lang: String?

    var id: String { title }
    var thumbnailURL: URL? { thumbnail?.source }
    var originalImageURL: URL? { originalImage?.source }
    var pageURL: URL? { contentURLs?.mobile?.page ?? contentURLs?.desktop?.page }

    /// The subject phrase Wikipedia sets bold at the start of the lead, read
    /// from `extract_html`. The preview mirrors it so swapping in the real
    /// article does not restyle the opening words.
    var leadBoldPhrase: String? {
        guard let html = extractHTML,
              let open = html.range(of: "<b>"),
              let close = html.range(of: "</b>", range: open.upperBound..<html.endIndex)
        else { return nil }
        let inner = String(html[open.upperBound..<close.lowerBound])
        let plain = inner.replacingOccurrences(
            of: "<[^>]+>", with: "", options: .regularExpression
        )
        let decoded = plain
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: "\u{00A0}")
        let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    enum CodingKeys: String, CodingKey {
        case title
        case displayTitle = "displaytitle"
        case description
        case extract
        case extractHTML = "extract_html"
        case thumbnail
        case originalImage = "originalimage"
        case contentURLs = "content_urls"
        case lang
    }
}

struct ImageRef: Decodable, Hashable, Sendable {
    let source: URL
    let width: Int?
    let height: Int?
}

struct ContentURLs: Decodable, Hashable, Sendable {
    let desktop: ContentURL?
    let mobile: ContentURL?
}

struct ContentURL: Decodable, Hashable, Sendable {
    let page: URL?
}

struct FeaturedFeed: Decodable, Sendable {
    let tfa: ArticleSummary?
    let mostRead: MostRead?
    let image: PictureOfTheDay?
    let news: [NewsItem]?
    let onThisDay: [OnThisDayItem]?

    enum CodingKeys: String, CodingKey {
        case tfa
        case mostRead = "mostread"
        case image
        case news
        case onThisDay = "onthisday"
    }
}

struct MostRead: Decodable, Sendable {
    let articles: [ArticleSummary]
}

struct PictureOfTheDay: Decodable, Sendable, Hashable {
    let title: String?
    let thumbnail: ImageRef?
    let image: ImageRef?
    let description: LocalizedText?
    let credit: LocalizedText?

    struct LocalizedText: Decodable, Sendable, Hashable {
        let html: String?
        let text: String?
        let lang: String?
    }
}

struct NewsItem: Decodable, Sendable, Identifiable, Hashable {
    let story: String
    let links: [ArticleSummary]

    var id: String { story }
}

struct OnThisDayItem: Decodable, Sendable, Identifiable, Hashable {
    let text: String
    let year: Int?
    let pages: [ArticleSummary]?

    var id: String { "\(year ?? 0)-\(text.hashValue)" }
}

struct SearchResult: Sendable, Hashable, Identifiable {
    let title: String
    let summary: String
    let thumbnailURL: URL?

    var id: String { title }
}

struct LangLink: Decodable, Sendable, Hashable {
    let lang: String
    let title: String

    enum CodingKeys: String, CodingKey {
        case lang
        case title
    }
}

struct MediaItem: Sendable, Identifiable, Hashable {
    let id: String          // Wikipedia file title (stable, unique)
    let thumbnailURL: URL
    let originalURL: URL
    let caption: String?
}

struct MediaListResponse: Decodable, Sendable {
    let items: [Item]?

    struct Item: Decodable, Sendable {
        let title: String?
        let type: String?
        let showInGallery: Bool?
        let srcset: [SrcSet]?
        let caption: Caption?

        struct SrcSet: Decodable, Sendable {
            let src: String
            let scale: String?
        }
        struct Caption: Decodable, Sendable {
            let text: String?
            let html: String?
        }
    }

    /// Just the images Wikipedia thinks are worth showing in a gallery. Skips audio, video,
    /// SVG icons / diagrams (logos, flags, trophy outlines — they look broken in a thumbnail
    /// grid), Wikipedia's own `showInGallery=false` items, and anything without a srcset.
    var galleryImages: [MediaItem] {
        guard let items else { return [] }
        return items.compactMap { item -> MediaItem? in
            guard item.type == "image" else { return nil }
            if item.showInGallery == false { return nil }
            guard let srcs = item.srcset, !srcs.isEmpty else { return nil }
            guard
                let small = absoluteURL(srcs.first?.src),
                let large = absoluteURL(srcs.last?.src) ?? absoluteURL(srcs.first?.src)
            else { return nil }
            if isLikelySVG(small) || isLikelySVG(large) { return nil }
            let title = item.title ?? small.absoluteString
            return MediaItem(
                id: title,
                thumbnailURL: small,
                originalURL: large,
                caption: item.caption?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    private func absoluteURL(_ src: String?) -> URL? {
        guard var src else { return nil }
        if src.hasPrefix("//") { src = "https:" + src }
        return URL(string: src)
    }

    private func isLikelySVG(_ url: URL) -> Bool {
        url.path.lowercased().contains(".svg")
    }
}

struct NearbyArticle: Sendable, Identifiable, Hashable {
    let id: Int
    let title: String
    let description: String?
    let thumbnailURL: URL?
    let latitude: Double
    let longitude: Double
}

struct NearbyResponse: Decodable, Sendable {
    let query: Query?

    struct Query: Decodable, Sendable {
        let pages: [Page]?
    }

    struct Page: Decodable, Sendable {
        let pageid: Int
        let title: String
        let description: String?
        let thumbnail: Thumbnail?
        let coordinates: [Coordinate]?

        struct Thumbnail: Decodable, Sendable { let source: URL }
        struct Coordinate: Decodable, Sendable {
            let lat: Double
            let lon: Double
        }
    }

    var articles: [NearbyArticle] {
        guard let pages = query?.pages else { return [] }
        return pages.compactMap { page in
            guard let coord = page.coordinates?.first else { return nil }
            return NearbyArticle(
                id: page.pageid,
                title: page.title,
                description: page.description,
                thumbnailURL: page.thumbnail?.source,
                latitude: coord.lat,
                longitude: coord.lon
            )
        }
    }
}

/// Decoded response from /w/api.php?action=query&generator=prefixsearch&prop=pageimages|description.
struct PrefixSearchResponse: Decodable, Sendable {
    let query: Query?

    struct Query: Decodable, Sendable {
        let pages: [Page]?
    }

    struct Page: Decodable, Sendable {
        let title: String
        let index: Int?
        let description: String?
        let thumbnail: Thumbnail?

        struct Thumbnail: Decodable, Sendable { let source: URL }
    }

    /// Returns results ordered by Wikipedia's relevance ranking (`index`),
    /// not the arbitrary order they come back as JSON pages.
    var results: [SearchResult] {
        guard let pages = query?.pages else { return [] }
        return pages
            .sorted { ($0.index ?? .max) < ($1.index ?? .max) }
            .map { page in
                SearchResult(
                    title: page.title,
                    summary: page.description ?? "",
                    thumbnailURL: page.thumbnail?.source
                )
            }
    }
}
