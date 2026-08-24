import Foundation

enum WikipediaEndpoint {
    case featured(language: String, date: Date)
    case summary(title: String, language: String)
    case mobileHTML(title: String, language: String)
    case random(language: String)
    case prefixSearch(query: String, language: String, limit: Int)
    case langlinks(title: String, language: String)
    case related(title: String, language: String)
    case nearby(language: String, latitude: Double, longitude: Double, radiusMeters: Int, limit: Int)
    case mediaList(title: String, language: String)

    func url() -> URL? {
        switch self {
        case .featured(let language, let date):
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy/MM/dd"
            let path = formatter.string(from: date)
            return URL(string: "https://\(language).wikipedia.org/api/rest_v1/feed/featured/\(path)")

        case .summary(let title, let language):
            guard let escaped = Self.encodePathTitle(title) else { return nil }
            return URL(string: "https://\(language).wikipedia.org/api/rest_v1/page/summary/\(escaped)")

        case .mobileHTML(let title, let language):
            guard let escaped = Self.encodePathTitle(title) else { return nil }
            return URL(string: "https://\(language).wikipedia.org/api/rest_v1/page/mobile-html/\(escaped)")

        case .random(let language):
            return URL(string: "https://\(language).wikipedia.org/api/rest_v1/page/random/summary")

        case .prefixSearch(let query, let language, let limit):
            // generator=prefixsearch + prop=pageimages|description gives us titles,
            // short descriptions, and row-sized thumbnails in one round trip.
            var components = URLComponents(string: "https://\(language).wikipedia.org/w/api.php")
            components?.queryItems = [
                URLQueryItem(name: "action", value: "query"),
                URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "formatversion", value: "2"),
                URLQueryItem(name: "generator", value: "prefixsearch"),
                URLQueryItem(name: "gpssearch", value: query),
                URLQueryItem(name: "gpslimit", value: String(limit)),
                URLQueryItem(name: "gpsnamespace", value: "0"),
                URLQueryItem(name: "prop", value: "pageimages|description"),
                URLQueryItem(name: "piprop", value: "thumbnail"),
                URLQueryItem(name: "pithumbsize", value: String(ThumbnailWidth.row))
            ]
            return components?.url

        case .langlinks(let title, let language):
            var components = URLComponents(string: "https://\(language).wikipedia.org/w/api.php")
            components?.queryItems = [
                URLQueryItem(name: "action", value: "query"),
                URLQueryItem(name: "prop", value: "langlinks"),
                URLQueryItem(name: "titles", value: title),
                URLQueryItem(name: "lllimit", value: "50"),
                URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "formatversion", value: "2"),
                URLQueryItem(name: "redirects", value: "1")
            ]
            return components?.url

        case .related(let title, let language):
            guard let escaped = Self.encodePathTitle(title) else { return nil }
            return URL(string: "https://\(language).wikipedia.org/api/rest_v1/page/related/\(escaped)")

        case .mediaList(let title, let language):
            guard let escaped = Self.encodePathTitle(title) else { return nil }
            return URL(string: "https://\(language).wikipedia.org/api/rest_v1/page/media-list/\(escaped)")

        case .nearby(let language, let lat, let lon, let radius, let limit):
            var components = URLComponents(string: "https://\(language).wikipedia.org/w/api.php")
            components?.queryItems = [
                URLQueryItem(name: "action", value: "query"),
                URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "formatversion", value: "2"),
                URLQueryItem(name: "prop", value: "pageimages|description|coordinates"),
                URLQueryItem(name: "piprop", value: "thumbnail"),
                URLQueryItem(name: "pithumbsize", value: String(ThumbnailWidth.row)),
                URLQueryItem(name: "coprop", value: "type|name|dim|country|region"),
                URLQueryItem(name: "colimit", value: String(limit)),
                URLQueryItem(name: "generator", value: "geosearch"),
                URLQueryItem(name: "ggscoord", value: "\(lat)|\(lon)"),
                URLQueryItem(name: "ggsradius", value: String(radius)),
                URLQueryItem(name: "ggslimit", value: String(limit))
            ]
            return components?.url
        }
    }

    private static func encodePathTitle(_ title: String) -> String? {
        let underscored = title.replacingOccurrences(of: " ", with: "_")
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#")
        return underscored.addingPercentEncoding(withAllowedCharacters: allowed)
    }
}
