import SwiftUI
import SwiftData

struct TodayView: View {
    @Query private var settingsList: [AppSettings]
    @Environment(\.scenePhase) private var scenePhase

    @State private var feed: FeaturedFeed?
    @State private var loadingError: String?
    @State private var lastFetched: Date?
    @State private var isLoading = false

    private var language: String { settingsList.first?.defaultLanguage ?? "en" }

    private let columns = [
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0)
    ]

    var body: some View {
        Group {
            if let feed {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 0) {
                        ForEach(Array(tiles(from: feed).enumerated()), id: \.element.id) { index, article in
                            NavigationLink(value: ArticleDestination(title: article.title, language: language)) {
                                Tile(article: article, tintIndex: index)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            } else if let message = loadingError {
                TodayErrorView(message: message) { Task { await refresh() } }
            } else {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemGroupedBackground))
        .refreshable { await refresh() }
        .task(id: language) { await refresh() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, isStale else { return }
            Task { await refresh() }
        }
    }

    private func tiles(from feed: FeaturedFeed) -> [ArticleSummary] {
        var seen = Set<String>()
        var result: [ArticleSummary] = []

        @MainActor func add(_ article: ArticleSummary) {
            guard !seen.contains(article.title) else { return }
            seen.insert(article.title)
            result.append(article)
        }

        if let tfa = feed.tfa { add(tfa) }
        if let mostRead = feed.mostRead {
            mostRead.articles.prefix(12).forEach(add)
        }
        if let onThisDay = feed.onThisDay {
            for item in onThisDay.prefix(6) {
                if let first = item.pages?.first { add(first) }
            }
        }
        if let news = feed.news {
            for item in news.prefix(4) {
                if let first = item.links.first { add(first) }
            }
        }
        return result
    }

    private func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        loadingError = nil
        do {
            feed = try await WikipediaClient.shared.featured(language: language)
            lastFetched = .now
        } catch {
            loadingError = error.localizedDescription
        }
    }

    private var isStale: Bool {
        guard let lastFetched else { return true }
        return Date.now.timeIntervalSince(lastFetched) > 6 * 3600
    }
}

struct TodayErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
