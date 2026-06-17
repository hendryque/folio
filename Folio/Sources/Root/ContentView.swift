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
    @State private var nearbyRecenterToken = UUID()
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
                onLogoTap: tapLogo,
                onLanguageToggle: toggleLanguage,
                onRandomTap: tapRandom,
                onSettingsTap: { showSettings = true },
                onReselectTab: handleTabReselect
            )

            // Active-tab NavigationStack is *always* mounted so its path
            // and in-flight article reader survive typing in the search bar.
            // Search results rise above it as an opaque overlay when
            // `isSearching` — clearing the query drops the overlay and the
            // tab is exactly where the user left it.
            ZStack {
                activeTabStack
                if isSearching {
                    NavigationStack(path: $searchPath) {
                        SearchResultsList(query: searchText, language: language)
                            .toolbar(.hidden, for: .navigationBar)
                            .articleDestination(language: language)
                            .background(PopGestureEnabler())
                    }
                    .background(Color(.systemBackground))
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: isSearching)
        }
        .preferredColorScheme(currentTheme.colorScheme)
        .task { ensureSettingsRow() }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    @ViewBuilder
    private var activeTabStack: some View {
        switch selectedTab {
        case .today:
            NavigationStack(path: $todayPath) {
                TodayView()
                    .toolbar(.hidden, for: .navigationBar)
                    .articleDestination(language: language)
            }
        case .history:
            NavigationStack(path: $historyPath) {
                HistoryView(onRerunSearch: rerunSearch)
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
                NearbyView(recenterToken: nearbyRecenterToken)
                    .toolbar(.hidden, for: .navigationBar)
                    .articleDestination(language: language)
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

    private func tapLogo() {
        searchFocused = false
        searchText = ""
        selectedTab = .today
        todayPath = NavigationPath()
    }

    private func rerunSearch(_ query: String) {
        searchText = query
        searchFocused = true
    }

    /// Re-tap on the already-selected tab. Standard iOS pattern: pop to root.
    /// Nearby is special — there's nothing to pop visually (it's a map), so
    /// re-tap bumps a recenter token NearbyView observes to jump the camera
    /// back to the user's current location.
    private func handleTabReselect(_ tab: ContentView.Tab) {
        switch tab {
        case .today: todayPath = NavigationPath()
        case .history: historyPath = NavigationPath()
        case .bookmarks: bookmarksPath = NavigationPath()
        case .nearby:
            if !nearbyPath.isEmpty {
                nearbyPath = NavigationPath()
            } else {
                nearbyRecenterToken = UUID()
            }
        }
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

    @Environment(\.modelContext) private var modelContext
    @State private var results: [SearchResult] = []
    @State private var fetchTask: Task<Void, Never>?

    var body: some View {
        List {
            ForEach(results) { result in
                NavigationLink(value: ArticleDestination(title: result.title, language: language)) {
                    SearchResultRow(result: result)
                }
                // Save the query to search history at the moment the user
                // commits to a result. simultaneousGesture fires alongside
                // the NavigationLink without preempting it.
                .simultaneousGesture(TapGesture().onEnded {
                    persistSearchQuery()
                })
            }
        }
        .listStyle(.plain)
        .background(Color(.systemBackground))
        .task(id: query) { scheduleSearch(query) }
    }

    /// Insert a SearchHistoryEntry for the current query, deduping against any
    /// identical query+language entry saved in the last 60s so a tap-back-tap
    /// flurry doesn't fill history with the same word repeated.
    private func persistSearchQuery() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let lang = language
        let cutoff = Date.now.addingTimeInterval(-60)
        let descriptor = FetchDescriptor<SearchHistoryEntry>(
            predicate: #Predicate { entry in
                entry.query == trimmed && entry.language == lang && entry.searchedAt > cutoff
            }
        )
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty { return }
        modelContext.insert(SearchHistoryEntry(query: trimmed, language: lang))
        try? modelContext.save()
    }

    private func scheduleSearch(_ raw: String) {
        fetchTask?.cancel()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        fetchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            do {
                let fetched = try await WikipediaClient.shared.search(query: trimmed, language: language)
                guard !Task.isCancelled else { return }
                results = fetched
            } catch {
                guard !Task.isCancelled else { return }
                results = []
            }
        }
    }
}

private struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: result.thumbnailURL) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                case .failure, .empty: Color(.tertiarySystemFill)
                @unknown default: Color(.tertiarySystemFill)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title.replacingOccurrences(of: "_", with: " "))
                    .font(.custom("EBGaramond-Regular", size: 17, relativeTo: .body))
                    .foregroundStyle(.primary)
                if !result.summary.isEmpty {
                    Text(result.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

extension View {
    func articleDestination(language: String) -> some View {
        navigationDestination(for: ArticleDestination.self) { destination in
            ArticleReaderView(title: destination.title, language: destination.language ?? language)
                .background(PopGestureEnabler())
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Bookmark.self, HistoryEntry.self, AppSettings.self], inMemory: true)
}
