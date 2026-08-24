import Foundation

actor WikipediaClient {
    static let shared = WikipediaClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.httpAdditionalHeaders = [
                "User-Agent": UserAgent.value,
                "Accept-Language": "en, de;q=0.8"
            ]
            config.requestCachePolicy = .useProtocolCachePolicy
            config.timeoutIntervalForRequest = 20
            self.session = URLSession(configuration: config)
        }
        self.decoder = JSONDecoder()
    }

    func featured(language: String, date: Date = .now) async throws -> FeaturedFeed {
        try await get(.featured(language: language, date: date))
    }

    func summary(title: String, language: String) async throws -> ArticleSummary {
        try await get(.summary(title: title, language: language))
    }

    func random(language: String) async throws -> ArticleSummary {
        try await get(.random(language: language))
    }

    func mobileHTML(title: String, language: String) async throws -> String {
        let request = try buildRequest(.mobileHTML(title: title, language: language), accept: "text/html")
        let (data, response) = try await dataAsync(for: request)
        try validate(response: response)
        guard let html = String(data: data, encoding: .utf8) else {
            throw WikipediaError.empty
        }
        return html
    }

    func search(query: String, language: String, limit: Int = 12) async throws -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let response: PrefixSearchResponse = try await get(
            .prefixSearch(query: trimmed, language: language, limit: limit)
        )
        return response.results
    }

    func langlinks(title: String, language: String) async throws -> [LangLink] {
        struct Response: Decodable {
            struct Query: Decodable {
                struct Page: Decodable { let langlinks: [LangLink]? }
                let pages: [Page]?
            }
            let query: Query?
        }
        let response: Response = try await get(.langlinks(title: title, language: language))
        return response.query?.pages?.first?.langlinks ?? []
    }

    func related(title: String, language: String) async throws -> [ArticleSummary] {
        struct Wrapper: Decodable { let pages: [ArticleSummary] }
        let wrapper: Wrapper = try await get(.related(title: title, language: language))
        return wrapper.pages
    }

    func mediaList(title: String, language: String) async throws -> [MediaItem] {
        let response: MediaListResponse = try await get(.mediaList(title: title, language: language))
        return response.galleryImages
    }

    func nearby(
        latitude: Double,
        longitude: Double,
        language: String,
        radiusMeters: Int = 10_000,
        limit: Int = 150
    ) async throws -> [NearbyArticle] {
        let response: NearbyResponse = try await get(
            .nearby(language: language, latitude: latitude, longitude: longitude, radiusMeters: radiusMeters, limit: limit)
        )
        return response.articles
    }

    private func get<T: Decodable>(_ endpoint: WikipediaEndpoint) async throws -> T {
        let request = try buildRequest(endpoint, accept: "application/json")
        let (data, response) = try await dataAsync(for: request)
        try validate(response: response)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw WikipediaError.decoding(String(describing: error))
        }
    }

    private func buildRequest(_ endpoint: WikipediaEndpoint, accept: String) throws -> URLRequest {
        guard let url = endpoint.url() else { throw WikipediaError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue(accept, forHTTPHeaderField: "Accept")
        return request
    }

    private func dataAsync(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw WikipediaError.transport(error.localizedDescription)
        }
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard 200..<300 ~= http.statusCode else {
            throw WikipediaError.httpStatus(http.statusCode)
        }
    }
}
