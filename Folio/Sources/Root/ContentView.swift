import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]

    @State private var searchText = ""
    @State private var selectedTab: Tab = .today
    @State private var navPath = NavigationPath()
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

            NavigationStack(path: $navPath) {
                Group {
                    if isSearching {
                        SearchResultsList(query: searchText, language: language)
                    } else {
                        tabContent
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
                .articleDestination(language: language)
            }
        }
        .preferredColorScheme(currentTheme.colorScheme)
        .task { ensureSettingsRow() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onChange(of: selectedTab) { _, _ in
            navPath = NavigationPath()
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .today: TodayView()
        case .history: HistoryView()
        case .bookmarks: BookmarksView()
        case .nearby: NearbyView()
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
                navPath.append(ArticleDestination(title: article.title, language: language))
            } catch {
                // Best-effort: silently no-op if the network request fails.
            }
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
