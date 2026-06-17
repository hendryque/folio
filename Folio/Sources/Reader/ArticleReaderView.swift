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
    @State private var showGallery = false
    @State private var galleryItems: [MediaItem] = []
    @State private var lightbox: IdentifiedURL?
    @State private var pendingScrollAnchor: String?
    @State private var alternateLink: LangLink?
    @State private var pushedArticle: ArticleDestination?
    @State private var heroFocalPoint: CGPoint?
    @State private var visionComplete: Bool = false
    @State private var webViewReady: Bool = false
    @State private var reloadToken = UUID()
    @State private var initialScrollY: Double = 0
    @State private var toolbarVisible: Bool = true
    @State private var toolbarRevealTask: Task<Void, Never>?
    @State private var refreshTask: Task<Void, Never>?
    @State private var activeSectionAnchor: String?

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
                    hasGallery: !galleryItems.isEmpty,
                    alternateLink: alternateLink,
                    fallbackLanguage: language,
                    onToggleBookmark: toggleBookmark,
                    onCycleTheme: cycleTheme,
                    onShowGallery: { showGallery = true },
                    onShowTOC: { showTOC = true }
                )
                .opacity(toolbarVisible ? 1 : 0)
                .offset(y: toolbarVisible ? 0 : 90)
                .allowsHitTesting(toolbarVisible)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: contentPhase)
        .overlay(alignment: .topLeading) {
            FloatingBackButton {
                dismiss()
            }
        }
        // Keep the nav bar present-but-invisible so UIKit's interactive pop
        // (swipe-from-leading-edge) still works. `.toolbar(.hidden)` removes the bar
        // entirely and disables the gesture.
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: identityKey) { await loadAll() }
        .sheet(isPresented: $showTOC) {
            TableOfContentsDrawer(
                articleTitle: displayTitle,
                thumbnailURL: summary?.thumbnailURL,
                sections: sections,
                activeAnchor: activeSectionAnchor,
                theme: theme
            ) { anchor in
                pendingScrollAnchor = anchor
            }
        }
        .sheet(isPresented: $showGallery) {
            ArticleImageGallery(items: galleryItems, theme: theme)
        }
        .fullScreenCover(item: $lightbox) { wrapped in
            ImageLightbox(url: wrapped.url)
        }
        .navigationDestination(item: $pushedArticle) { dest in
            ArticleReaderView(title: dest.title, language: dest.language ?? language)
        }
        // Header EN/DE toggle changes AppSettings.defaultLanguage. When the user is
        // in an article and that global language differs from the current article's,
        // jump to the alternate-language version (if a langlink exists for it).
        .onChange(of: settings?.defaultLanguage) { oldLang, newLang in
            // `oldLang == nil` means the @Query just resolved from "no settings
            // row loaded yet" to "loaded" — that's not a user-driven toggle,
            // so don't auto-push. Otherwise an opening article whose language
            // differs from the persisted default would jump to the alt-lang
            // version immediately on first load.
            guard oldLang != nil else { return }
            guard let newLang, newLang != language else { return }
            if let alt = alternateLink, alt.lang == newLang {
                pushedArticle = ArticleDestination(title: alt.title, language: alt.lang)
            }
        }
        .onDisappear {
            refreshTask?.cancel()
            toolbarRevealTask?.cancel()
        }
    }

    private enum ContentPhase: Int { case loading, preview, web }

    private var contentPhase: ContentPhase {
        if webViewReady { return .web }
        if summary != nil { return .preview }
        return .loading
    }

    @ViewBuilder
    private var content: some View {
        // Mount the WebView the moment HTML + focal are both available, but keep
        // it invisible until WKWebView's didFinish fires (`webViewReady`). The
        // ArticleLoadingPreview overlays on top until that happens, so the
        // cross-fade goes preview → painted-article without a blank gap.
        ZStack {
            if let html, visionComplete {
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
                    onScroll: handleScroll,
                    onActiveSection: { activeSectionAnchor = $0 },
                    onReady: { webViewReady = true },
                    onReload: handleContentProcessTerminated
                )
                .ignoresSafeArea()
                .opacity(webViewReady ? 1 : 0)
                // Critical: SwiftUI's .opacity(0) does NOT disable hit testing
                // for a UIKit view nested in a UIViewRepresentable. Without this,
                // WKWebView's scroll-view gesture recognizers grab the
                // leading-edge swipe before SwiftUI's interactive-pop ever sees
                // it — so on a dead/stuck WebView, swipe-back stops working.
                .allowsHitTesting(webViewReady)
                // Roll the identity to remount the WebView after a content
                // process crash. loadHTMLString-loaded views can't be reloaded
                // via WKWebView.reload(); rebuilding the view is the only path
                // that re-runs the render pipeline.
                .id(reloadToken)
            }

            if !webViewReady {
                if let loadError {
                    ContentUnavailableView(
                        "Couldn't load article",
                        systemImage: "exclamationmark.triangle",
                        description: Text(loadError)
                    )
                    .transition(.opacity)
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
                        .transition(.opacity)
                }
            }
        }
    }

    private var identityKey: String { "\(language)/\(title)" }
    private var displayTitle: String { title.replacingOccurrences(of: "_", with: " ") }

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
        // .task(id:) cancels on disappear and restarts on re-appear — even
        // when identityKey is unchanged (e.g. navigating to a sub-article
        // and swiping back). Without this guard, every back-swipe would
        // blow away visionComplete/webViewReady, unmount the WebView, and
        // strand the user on the preview waiting for didFinish on a freshly-
        // remounted pane. If we're already painted, do nothing.
        if webViewReady { return }

        loadError = nil
        alternateLink = nil
        heroFocalPoint = nil
        visionComplete = false
        webViewReady = false
        galleryItems = []
        initialScrollY = 0
        // A refresh from a previous identity must not race the new render.
        refreshTask?.cancel()
        refreshTask = nil

        // Summary first — needed for the focal-point image URL.
        await loadSummary()

        async let htmlTask: () = loadHTML()
        async let langlinksTask: () = loadLanglinks()
        async let galleryTask: () = loadGallery()
        async let focalTask: () = resolveHeroFocalPoint()

        _ = await (htmlTask, langlinksTask, galleryTask, focalTask)

        visionComplete = true
        recordHistoryIfNeeded()
    }

    /// Resolves the hero focal point via cache → Vision → persist. Cached articles
    /// return instantly; new articles run face detection once and write the result
    /// back to CachedArticle so the next session is also flash-free.
    private func resolveHeroFocalPoint() async {
        if let cached = fetchCachedArticle(),
           let x = cached.focalPointX, let y = cached.focalPointY {
            heroFocalPoint = CGPoint(x: x, y: y)
            return
        }

        guard let url = summary?.originalImageURL ?? summary?.thumbnailURL else { return }
        let focal = await FocalPointDetector.shared.focalPoint(for: url)
        heroFocalPoint = focal
        if let focal {
            persistFocalPoint(focal)
        }
    }

    private func persistFocalPoint(_ focal: CGPoint) {
        guard let entry = fetchCachedArticle() else { return }
        entry.focalPointX = focal.x
        entry.focalPointY = focal.y
        try? modelContext.save()
    }

    private func loadGallery() async {
        galleryItems = (try? await WikipediaClient.shared.mediaList(title: title, language: language)) ?? []
    }

    private func handleScroll(_ y: Double) {
        updateToolbarVisibility(forNewY: y)
    }

    /// Called when WKWebView's content process is terminated by iOS. Dropping
    /// webViewReady re-overlays the preview; rolling reloadToken changes the
    /// WebView's SwiftUI identity, so the next render dismantles the dead pane
    /// and constructs a fresh one — which fires loadHTMLString cleanly.
    private func handleContentProcessTerminated() {
        webViewReady = false
        reloadToken = UUID()
    }

    /// Idle-reveal pattern: any scroll fades the toolbar out; after 0.8s of no scroll
    /// activity, fade it back in. Near the top of the article (under the hero) the
    /// toolbar stays visible regardless — users have just landed or are about to leave.
    private func updateToolbarVisibility(forNewY y: Double) {
        if y < 80 {
            toolbarRevealTask?.cancel()
            if !toolbarVisible {
                withAnimation(.easeOut(duration: 0.2)) { toolbarVisible = true }
            }
            return
        }

        if toolbarVisible {
            withAnimation(.easeOut(duration: 0.2)) { toolbarVisible = false }
        }

        toolbarRevealTask?.cancel()
        toolbarRevealTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { toolbarVisible = true }
        }
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
                scheduleRefresh()
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
            if Task.isCancelled { return }
            loadError = error.localizedDescription
        }
    }

    /// Tracked, cancellable background refresh — previously a detached
    /// `Task { @MainActor in ... }` that outlived view identity and could
    /// still write into a stale view's `html` after the user had navigated
    /// away and back. Now owned by view state and cancelled on disappear /
    /// at the start of every fresh `loadAll`.
    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            do {
                let fresh = try await WikipediaClient.shared.mobileHTML(title: title, language: language)
                if Task.isCancelled { return }
                html = fresh
                upsertCache(html: fresh)
            } catch {
                // Silent — stale cache stays in place.
            }
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

        // Cross-instance dedup: if the same article was recorded in the last
        // 30s (typical of an A → B → back-to-A swipe-and-tap), just bump its
        // readAt instead of inserting a duplicate row. The `historyRecorded`
        // guard above is per-view-instance; this catches the case where the
        // view itself was reborn.
        let snapshotTitle = title
        let snapshotLanguage = language
        let cutoff = Date.now.addingTimeInterval(-30)
        let recentDescriptor = FetchDescriptor<HistoryEntry>(
            predicate: #Predicate { entry in
                entry.title == snapshotTitle && entry.language == snapshotLanguage && entry.readAt > cutoff
            }
        )
        if let recent = try? modelContext.fetch(recentDescriptor).first {
            recent.readAt = .now
            // Backfill thumb/summary if the recent row was missing it.
            if recent.thumbnailURL == nil, let url = summary?.thumbnailURL {
                recent.thumbnailURL = url
            }
            if recent.summary == nil, let desc = summary?.description {
                recent.summary = desc
            }
            try? modelContext.save()
            return
        }

        // Backfill from any prior record when the live summary came back
        // without metadata (typical on flaky cellular) — otherwise the same
        // article shows up with a thumbnail one day and without it the next.
        let fallback = previousMetadata()
        modelContext.insert(
            HistoryEntry(
                title: title,
                language: language,
                summary: summary?.description ?? fallback.summary,
                thumbnailURL: summary?.thumbnailURL ?? fallback.thumbnailURL
            )
        )
        try? modelContext.save()
    }

    /// Find the most recent thumbnail / description we've previously stored
    /// for this (title, language). Checks history first (more frequently
    /// updated) then bookmarks.
    private func previousMetadata() -> (summary: String?, thumbnailURL: URL?) {
        let snapshotTitle = title
        let snapshotLanguage = language
        let historyDescriptor = FetchDescriptor<HistoryEntry>(
            predicate: #Predicate { entry in
                entry.title == snapshotTitle && entry.language == snapshotLanguage
            },
            sortBy: [SortDescriptor(\.readAt, order: .reverse)]
        )
        if let entry = try? modelContext.fetch(historyDescriptor).first(where: { $0.thumbnailURL != nil || $0.summary != nil }) {
            return (entry.summary, entry.thumbnailURL)
        }
        let bookmarkDescriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate { entry in
                entry.title == snapshotTitle && entry.language == snapshotLanguage
            }
        )
        if let entry = try? modelContext.fetch(bookmarkDescriptor).first {
            return (entry.summary, entry.thumbnailURL)
        }
        return (nil, nil)
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
    let hasGallery: Bool
    let alternateLink: LangLink?
    let fallbackLanguage: String
    let onToggleBookmark: () -> Void
    let onCycleTheme: () -> Void
    let onShowGallery: () -> Void
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

            Button(action: onShowGallery) {
                Image(systemName: "square.grid.2x2")
                    .accessibilityLabel("Images")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .disabled(!hasGallery)
            .opacity(hasGallery ? 1.0 : 0.4)

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
