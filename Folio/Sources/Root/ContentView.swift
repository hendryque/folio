import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]

    @State private var searchText = ""
    @State private var selectedTab: Tab = .today
    @State private var todayPath = NavigationPath()
    @State private var historyPath = NavigationPath()
    @State private var bookmarksPath = NavigationPath()
    @State private var nearbyPath = NavigationPath()
    @State private var searchPath = NavigationPath()
    @State private var showSettings = false
    @FocusState private var searchFocused: Bool

    enum Tab: Hashable, CaseIterable {
        case today, history, bookmarks, nearby

        var iconName: String {
            switch self {
            case .today: "square.grid.2x2"
            case .history: "clock"
            case .bookmarks: "bookmark"
            case .nearby: "paperplane"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .today: "Today"
            case .history: "History"
            case .bookmarks: "Bookmarks"
            case .nearby: "Nearby"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TopHeader(
                searchText: $searchText,
                selectedTab: $selectedTab,
                searchFocused: $searchFocused,
                language: language,
                onLanguageToggle: toggleLanguage,
                onRandomTap: tapRandom,
                onSettingsTap: { showSettings = true }
            )

            navigationStack
        }
        .preferredColorScheme(currentTheme.colorScheme)
        .task { ensureSettingsRow() }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    @ViewBuilder
    private var navigationStack: some View {
        if isSearching {
            NavigationStack(path: $searchPath) {
                SearchResultsList(query: searchText, language: language)
                    .toolbar(.hidden, for: .navigationBar)
                    .articleDestination(language: language)
            }
        } else {
            switch selectedTab {
            case .today:
                NavigationStack(path: $todayPath) {
                    TodayView()
                        .toolbar(.hidden, for: .navigationBar)
                        .articleDestination(language: language)
                }
            case .history:
                NavigationStack(path: $historyPath) {
                    HistoryView()
                        .toolbar(.hidden, for: .navigationBar)
                        .articleDestination(language: language)
                }
            case .bookmarks:
                NavigationStack(path: $bookmarksPath) {
                    BookmarksView()
                        .toolbar(.hidden, for: .navigationBar)
                        .articleDestination(language: language)
                }
            case .nearby:
                NavigationStack(path: $nearbyPath) {
                    NearbyView()
                        .toolbar(.hidden, for: .navigationBar)
                        .articleDestination(language: language)
                }
            }
        }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var settings: AppSettings? { settingsList.first }
    private var language: String { settings?.defaultLanguage ?? "en" }
    private var currentTheme: Theme {
        settings.flatMap { Theme(rawValue: $0.theme) } ?? .system
    }

    private func toggleLanguage() {
        guard let settings else { return }
        settings.defaultLanguage = settings.defaultLanguage == "en" ? "de" : "en"
        try? modelContext.save()
    }

    private func tapRandom() {
        Task { @MainActor in
            do {
                let article = try await WikipediaClient.shared.random(language: language)
                searchText = ""
                appendToActivePath(ArticleDestination(title: article.title, language: language))
            } catch {
                // Best-effort: silently no-op if the network request fails.
            }
        }
    }

    private func appendToActivePath(_ destination: ArticleDestination) {
        switch selectedTab {
        case .today: todayPath.append(destination)
        case .history: historyPath.append(destination)
        case .bookmarks: bookmarksPath.append(destination)
        case .nearby: nearbyPath.append(destination)
        }
    }

    private func ensureSettingsRow() {
        guard settingsList.isEmpty else { return }
        modelContext.insert(AppSettings.default)
        try? modelContext.save()
    }
}

private struct SearchResultsList: View {
    let query: String
    let language: String

    var body: some View {
        List {
            SearchSuggestionsView(query: query, language: language)
        }
        .listStyle(.plain)
        .background(Color(.systemBackground))
    }
}

extension View {
    func articleDestination(language: String) -> some View {
        navigationDestination(for: ArticleDestination.self) { destination in
            ArticleReaderView(title: destination.title, language: destination.language ?? language)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Bookmark.self, HistoryEntry.self, AppSettings.self], inMemory: true)
}
