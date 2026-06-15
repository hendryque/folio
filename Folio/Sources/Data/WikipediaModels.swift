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
    let url: URL?

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

/// OpenSearch returns four parallel arrays rather than a JSON object.
/// `[query, [titles], [descriptions], [urls]]`
struct OpenSearchResponse: Decodable, Sendable {
    let query: String
    let titles: [String]
    let descriptions: [String]
    let urls: [URL]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.query = try container.decode(String.self)
        self.titles = try container.decode([String].self)
        self.descriptions = try container.decode([String].self)
        self.urls = try container.decode([URL].self)
    }

    var results: [SearchResult] {
        let count = min(titles.count, descriptions.count, urls.count)
        return (0..<count).map { i in
            SearchResult(title: titles[i], summary: descriptions[i], url: urls[i])
        }
    }
}
