import SwiftUI
import SwiftData

struct ArticleReaderView: View {
    let title: String
    let language: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var bookmarks: [Bookmark]
    @Query private var settingsList: [AppSettings]

    @State private var summary: ArticleSummary?
    @State private var html: String?
    @State private var loadError: String?
    @State private var historyRecorded = false

    @State private var sections: [ArticleSection] = []
    @State private var showTOC = false
    @State private var lightbox: IdentifiedURL?
    @State private var pendingScrollAnchor: String?
    @State private var alternateLink: LangLink?
    @State private var pushedArticle: ArticleDestination?
    @State private var heroFocalPoint: CGPoint?
    @State private var initialScrollY: Double = 0
    @State private var currentScrollY: Double = 0
    @State private var lastScrollY: Double = 0
    @State private var toolbarVisible: Bool = true
    @State private var scrollSaveTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if html != nil {
                BottomReaderToolbar(
                    isBookmarked: isBookmarked,
                    shareURL: shareURL,
                    themeIcon: themeIcon,
                    themeLabel: theme.displayName,
                    hasSections: !sections.isEmpty,
                    alternateLink: alternateLink,
                    fallbackLanguage: language,
                    onToggleBookmark: toggleBookmark,
                    onCycleTheme: cycleTheme,
                    onShowTOC: { showTOC = true }
                )
                .opacity(toolbarVisible ? 1 : 0)
                .offset(y: toolbarVisible ? 0 : 90)
                .allowsHitTesting(toolbarVisible)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: html == nil)
        .overlay(alignment: .topLeading) {
            FloatingBackButton {
                dismiss()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: identityKey) { await loadAll() }
        .sheet(isPresented: $showTOC) {
            TableOfContentsDrawer(sections: sections) { anchor in
                pendingScrollAnchor = anchor
            }
        }
        .fullScreenCover(item: $lightbox) { wrapped in
            ImageLightbox(url: wrapped.url)
        }
        .navigationDestination(item: $pushedArticle) { dest in
            ArticleReaderView(title: dest.title, language: dest.language ?? language)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let html {
            ArticleWebView(
                html: html,
                baseURL: baseURL,
                language: language,
                currentTitle: title,
                heroImageURL: summary?.originalImageURL ?? summary?.thumbnailURL,
                heroFocalPoint: heroFocalPoint,
                theme: theme,
                fontScale: fontScale,
                initialScrollY: initialScrollY,
                pendingScrollAnchor: $pendingScrollAnchor,
                onSections: { sections = $0 },
                onImageTap: { lightbox = IdentifiedURL(url: $0) },
                onFontScale: persistFontScale,
                onInternalLink: { pushedArticle = $0 },
                onScroll: handleScroll
            )
            .ignoresSafeArea()
            .transition(.opacity)
        } else if let loadError {
            ContentUnavailableView(
                "Couldn't load article",
                systemImage: "exclamationmark.triangle",
                description: Text(loadError)
            )
        } else if let summary {
            ArticleLoadingPreview(
                summary: summary,
                theme: theme,
                fontScale: fontScale,
                heroFocalPoint: heroFocalPoint
            )
            .transition(.opacity)
        } else {
            ProgressView()
                .controlSize(.large)
        }
    }

    private var identityKey: String { "\(language)/\(title)" }

    private var settings: AppSettings? { settingsList.first }
    private var theme: Theme { settings.flatMap { Theme(rawValue: $0.theme) } ?? .system }
    private var fontScale: Double { settings?.fontScale ?? 1.0 }

    private var baseURL: URL {
        URL(string: "https://\(language).wikipedia.org/wiki/") ?? URL(string: "https://wikipedia.org")!
    }

    private var shareURL: URL {
        if let url = summary?.pageURL { return url }
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        return URL(string: "https://\(language).wikipedia.org/wiki/\(encoded)") ?? baseURL
    }

    private var isBookmarked: Bool {
        bookmarks.contains { $0.title == title && $0.language == language }
    }

    private var themeIcon: String {
        switch theme {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .sepia: "book"
        case .dark: "moon"
        }
    }

    private func cycleTheme() {
        guard let settings else { return }
        let cases = Theme.allCases
        let currentIndex = cases.firstIndex(where: { $0.rawValue == settings.theme }) ?? 0
        let next = cases[(currentIndex + 1) % cases.count]
        settings.theme = next.rawValue
        try? modelContext.save()
    }

    private func toggleBookmark() {
        if let existing = bookmarks.first(where: { $0.title == title && $0.language == language }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(
                Bookmark(
                    title: title,
                    language: language,
                    summary: summary?.description,
                    thumbnailURL: summary?.thumbnailURL
                )
            )
        }
        try? modelContext.save()
    }

    private func persistFontScale(_ scale: Double) {
        guard let settings, abs(settings.fontScale - scale) > 0.005 else { return }
        settings.fontScale = scale
        try? modelContext.save()
    }

    private func loadAll() async {
        loadError = nil
        alternateLink = nil
        heroFocalPoint = nil
        initialScrollY = await loadSavedScrollPosition()
        async let summaryTask: () = loadSummary()
        async let htmlTask: () = loadHTML()
        async let langlinksTask: () = loadLanglinks()
        _ = await (summaryTask, htmlTask, langlinksTask)
        recordHistoryIfNeeded()
        await detectHeroFocalPoint()
    }

    private func loadSavedScrollPosition() async -> Double {
        let descriptor = FetchDescriptor<HistoryEntry>(
            predicate: #Predicate { entry in
                entry.title == title && entry.language == language
            },
            sortBy: [SortDescriptor(\.readAt, order: .reverse)]
        )
        guard let existing = try? modelContext.fetch(descriptor).first else { return 0 }
        return existing.scrollY
    }

    private func handleScroll(_ y: Double) {
        currentScrollY = y
        updateToolbarVisibility(forNewY: y)
        lastScrollY = y
        scrollSaveTask?.cancel()
        scrollSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            persistScrollPosition()
        }
    }

    private func updateToolbarVisibility(forNewY y: Double) {
        let delta = y - lastScrollY
        // Always show at the top so users see the chrome when they land or scroll back to the hero.
        if y < 80 {
            if !toolbarVisible {
                withAnimation(.easeOut(duration: 0.2)) { toolbarVisible = true }
            }
            return
        }
        // Require a meaningful scroll delta so micro-jitter doesn't flip the toolbar.
        if delta > 10 && toolbarVisible {
            withAnimation(.easeOut(duration: 0.25)) { toolbarVisible = false }
        } else if delta < -10 && !toolbarVisible {
            withAnimation(.easeOut(duration: 0.2)) { toolbarVisible = true }
        }
    }

    private func persistScrollPosition() {
        let descriptor = FetchDescriptor<HistoryEntry>(
            predicate: #Predicate { entry in
                entry.title == title && entry.language == language
            },
            sortBy: [SortDescriptor(\.readAt, order: .reverse)]
        )
        guard let entry = try? modelContext.fetch(descriptor).first else { return }
        if abs(entry.scrollY - currentScrollY) > 24 {
            entry.scrollY = currentScrollY
            try? modelContext.save()
        }
    }

    private func detectHeroFocalPoint() async {
        guard let url = summary?.originalImageURL ?? summary?.thumbnailURL else { return }
        heroFocalPoint = await FocalPointDetector.shared.focalPoint(for: url)
    }

    private func loadLanglinks() async {
        let links = (try? await WikipediaClient.shared.langlinks(title: title, language: language)) ?? []
        alternateLink = links.first { $0.lang == alternateLanguage }
    }

    private var alternateLanguage: String {
        language == "de" ? "en" : "de"
    }

    private func loadSummary() async {
        summary = try? await WikipediaClient.shared.summary(title: title, language: language)
    }

    private func loadHTML() async {
        // Cache first — instant render if we have anything stored. Stale entries still
        // render immediately, then we silently refresh in the background.
        if let cached = fetchCachedArticle() {
            html = cached.html
            if Date.now.timeIntervalSince(cached.cachedAt) > Self.cacheTTL {
                refreshHTMLInBackground()
            }
            return
        }
        await fetchAndCacheHTML()
    }

    private func fetchAndCacheHTML() async {
        do {
            let fresh = try await WikipediaClient.shared.mobileHTML(title: title, language: language)
            html = fresh
            upsertCache(html: fresh)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func refreshHTMLInBackground() {
        let snapshotTitle = title
        let snapshotLanguage = language
        Task { @MainActor in
            guard
                let fresh = try? await WikipediaClient.shared.mobileHTML(
                    title: snapshotTitle,
                    language: snapshotLanguage
                )
            else { return }
            // If the user is still on this article, refresh the view.
            if snapshotTitle == title && snapshotLanguage == language {
                html = fresh
            }
            upsertCache(html: fresh)
        }
    }

    private func fetchCachedArticle() -> CachedArticle? {
        let snapshotTitle = title
        let snapshotLanguage = language
        let descriptor = FetchDescriptor<CachedArticle>(
            predicate: #Predicate { entry in
                entry.title == snapshotTitle && entry.language == snapshotLanguage
            }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func upsertCache(html: String) {
        if let existing = fetchCachedArticle() {
            existing.html = html
            existing.cachedAt = .now
        } else {
            modelContext.insert(
                CachedArticle(title: title, language: language, html: html)
            )
        }
        try? modelContext.save()
    }

    private static let cacheTTL: TimeInterval = 24 * 3600

    private func recordHistoryIfNeeded() {
        guard !historyRecorded else { return }
        historyRecorded = true
        modelContext.insert(
            HistoryEntry(
                title: title,
                language: language,
                summary: summary?.description,
                thumbnailURL: summary?.thumbnailURL
            )
        )
        try? modelContext.save()
    }
}

private struct FloatingBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(.thinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        }
        .accessibilityLabel("Back")
        .padding(.leading, 14)
        .padding(.top, 8)
    }
}

private struct BottomReaderToolbar: View {
    let isBookmarked: Bool
    let shareURL: URL
    let themeIcon: String
    let themeLabel: String
    let hasSections: Bool
    let alternateLink: LangLink?
    let fallbackLanguage: String
    let onToggleBookmark: () -> Void
    let onCycleTheme: () -> Void
    let onShowTOC: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ShareLink(item: shareURL) {
                Image(systemName: "square.and.arrow.up")
                    .accessibilityLabel("Share")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())

            if let alt = alternateLink {
                NavigationLink(value: ArticleDestination(title: alt.title, language: alt.lang)) {
                    Image(systemName: "character.bubble")
                        .accessibilityLabel("Read in \(displayLanguage(alt.lang))")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }

            Button(action: onToggleBookmark) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Add bookmark")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())

            Button(action: onCycleTheme) {
                Image(systemName: themeIcon)
                    .accessibilityLabel("Theme: \(themeLabel)")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())

            Button(action: onShowTOC) {
                Image(systemName: "list.bullet")
                    .accessibilityLabel("Contents")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .disabled(!hasSections)
            .opacity(hasSections ? 1.0 : 0.4)
        }
        .font(.system(size: 19, weight: .regular))
        .foregroundStyle(Color.primary)
        .buttonStyle(.plain)
        .frame(height: 56)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.black.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 12, y: 3)
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
    }

    private func displayLanguage(_ code: String) -> String {
        switch code {
        case "en": "English"
        case "de": "Deutsch"
        default: code.uppercased()
        }
    }
}
