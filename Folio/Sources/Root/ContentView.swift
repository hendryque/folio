import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]

    @State private var searchText = ""
    @State private var selectedTab: Tab = .today
    @State private var todayPath: [ArticleDestination] = []
    @State private var historyPath: [ArticleDestination] = []
    @State private var bookmarksPath: [ArticleDestination] = []
    @State private var nearbyPath: [ArticleDestination] = []
    @State private var todayForward: [ArticleDestination] = []
    @State private var historyForward: [ArticleDestination] = []
    @State private var bookmarksForward: [ArticleDestination] = []
    @State private var nearbyForward: [ArticleDestination] = []
    // Set true just before goForward mutates a path, consumed by the
    // path's onChange so the new push doesn't get treated as a fresh
    // user navigation (which would clear the forward stack).
    @State private var forwardInProgress = false
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
            // `isSearching`. The overlay is results-only: picking a result
            // clears the query and pushes onto the active tab's stack, so
            // clearing the search box can never close an open article.
            ZStack {
                activeTabStack
                if isSearching {
                    SearchResultsList(query: searchText, language: language) { result in
                        searchFocused = false
                        searchText = ""
                        appendToActivePath(ArticleDestination(title: result.title, language: language))
                    }
                    .background(Color(.systemBackground))
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: isSearching)
        }
        .preferredColorScheme(currentTheme.colorScheme)
        .task {
            ensureSettingsRow()
            applyScreenshotOverrides()
        }
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
                    .background(ForwardGestureEnabler(
                        onForward: { goForward(.today) },
                        isEnabled: !todayForward.isEmpty
                    ))
            }
            .onChange(of: todayPath) { old, new in observePathChange(.today, old: old, new: new) }
        case .history:
            NavigationStack(path: $historyPath) {
                HistoryView(onRerunSearch: rerunSearch)
                    .toolbar(.hidden, for: .navigationBar)
                    .articleDestination(language: language)
                    .background(ForwardGestureEnabler(
                        onForward: { goForward(.history) },
                        isEnabled: !historyForward.isEmpty
                    ))
            }
            .onChange(of: historyPath) { old, new in observePathChange(.history, old: old, new: new) }
        case .bookmarks:
            NavigationStack(path: $bookmarksPath) {
                BookmarksView()
                    .toolbar(.hidden, for: .navigationBar)
                    .articleDestination(language: language)
                    .background(ForwardGestureEnabler(
                        onForward: { goForward(.bookmarks) },
                        isEnabled: !bookmarksForward.isEmpty
                    ))
            }
            .onChange(of: bookmarksPath) { old, new in observePathChange(.bookmarks, old: old, new: new) }
        case .nearby:
            NavigationStack(path: $nearbyPath) {
                NearbyView(recenterToken: nearbyRecenterToken)
                    .toolbar(.hidden, for: .navigationBar)
                    .articleDestination(language: language)
                    .background(ForwardGestureEnabler(
                        onForward: { goForward(.nearby) },
                        isEnabled: !nearbyForward.isEmpty
                    ))
            }
            .onChange(of: nearbyPath) { old, new in observePathChange(.nearby, old: old, new: new) }
        }
    }

    /// Pop → push popped destinations onto the forward stack (newest last).
    /// Push by the user → clear the forward stack (browser semantic: any new
    /// navigation invalidates the forward trail). A push from `goForward`
    /// itself is signalled via `forwardInProgress` and skips the clear.
    private func observePathChange(_ tab: Tab, old: [ArticleDestination], new: [ArticleDestination]) {
        if new.count < old.count {
            // Multiple items can be popped at once (e.g. logo-tap reset).
            // Capture them in pop order so forward = reverse of pops.
            let popped = old[new.count..<old.count].reversed()
            switch tab {
            case .today: todayForward.append(contentsOf: popped)
            case .history: historyForward.append(contentsOf: popped)
            case .bookmarks: bookmarksForward.append(contentsOf: popped)
            case .nearby: nearbyForward.append(contentsOf: popped)
            }
        } else if new.count > old.count {
            if forwardInProgress {
                forwardInProgress = false
            } else {
                switch tab {
                case .today: todayForward = []
                case .history: historyForward = []
                case .bookmarks: bookmarksForward = []
                case .nearby: nearbyForward = []
                }
            }
        }
    }

    private func goForward(_ tab: Tab) {
        switch tab {
        case .today:
            guard let next = todayForward.popLast() else { return }
            forwardInProgress = true
            todayPath.append(next)
        case .history:
            guard let next = historyForward.popLast() else { return }
            forwardInProgress = true
            historyPath.append(next)
        case .bookmarks:
            guard let next = bookmarksForward.popLast() else { return }
            forwardInProgress = true
            bookmarksPath.append(next)
        case .nearby:
            guard let next = nearbyForward.popLast() else { return }
            forwardInProgress = true
            nearbyPath.append(next)
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
        todayPath = []
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
        case .today: todayPath = []
        case .history: historyPath = []
        case .bookmarks: bookmarksPath = []
        case .nearby:
            if !nearbyPath.isEmpty {
                nearbyPath = []
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
    let onSelect: (SearchResult) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var results: [SearchResult] = []
    @State private var fetchTask: Task<Void, Never>?

    var body: some View {
        List {
            ForEach(results) { result in
                // A plain Button, not a NavigationLink — the row must be
                // tappable across its full width. (The previous NavigationLink
                // + simultaneousGesture combo swallowed taps on the label,
                // leaving only the chevron area active.)
                Button {
                    persistSearchQuery()
                    onSelect(result)
                } label: {
                    SearchResultRow(result: result)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .background(Color(.systemBackground))
        // Results depend on query AND language: the EN/DE toggle must refetch,
        // and stale other-language rows must not linger while it does.
        .task(id: "\(language)|\(query)") { scheduleSearch(query) }
        .onChange(of: language) { _, _ in results = [] }
    }

    /// Record the query, one row per query+language: repeating a search bumps
    /// the existing row instead of filling history with the same word.
    private func persistSearchQuery() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let lang = language
        let descriptor = FetchDescriptor<SearchHistoryEntry>(
            predicate: #Predicate { entry in
                entry.query == trimmed && entry.language == lang
            },
            sortBy: [SortDescriptor(\.searchedAt, order: .reverse)]
        )
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        if let newest = existing.first {
            newest.searchedAt = .now
            for stale in existing.dropFirst() { modelContext.delete(stale) }
        } else {
            modelContext.insert(SearchHistoryEntry(query: trimmed, language: lang))
        }
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
            RemoteImage(url: result.thumbnailURL) { phase in
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

extension ContentView {
    /// Click-free navigation for automated simulator screenshots, e.g.
    /// `simctl launch <sim> me.scott.folio -screenshotTab nearby`,
    /// `-screenshotArticle "Albert Einstein"`, `-screenshotSettings 1`.
    /// simctl passes `-key value` pairs straight into UserDefaults.
    fileprivate func applyScreenshotOverrides() {
        #if DEBUG
        let defaults = UserDefaults.standard
        switch defaults.string(forKey: "screenshotTab") {
        case "history": selectedTab = .history
        case "bookmarks": selectedTab = .bookmarks
        case "nearby": selectedTab = .nearby
        default: break
        }
        if let article = defaults.string(forKey: "screenshotArticle") {
            todayPath = [ArticleDestination(title: article, language: language)]
        }
        if defaults.bool(forKey: "screenshotSettings") {
            showSettings = true
        }
        #endif
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
