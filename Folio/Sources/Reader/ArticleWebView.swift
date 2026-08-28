import SwiftUI
@preconcurrency import WebKit

struct ArticleSection: Identifiable, Hashable, Sendable {
    let id: String
    let level: Int
    let title: String
    let anchor: String
}

struct ArticleWebView: UIViewRepresentable {
    let html: String
    let baseURL: URL
    let language: String
    let currentTitle: String
    let heroImageURL: URL?
    let heroFocalPoint: CGPoint?
    let theme: Theme
    let fontScale: Double
    let initialScrollY: Double

    @Binding var pendingScrollAnchor: String?

    var onSections: ([ArticleSection]) -> Void = { _ in }
    var onImageTap: (URL) -> Void = { _ in }
    var onFontScale: (Double) -> Void = { _ in }
    var onInternalLink: (ArticleDestination) -> Void = { _ in }
    var onScroll: (Double) -> Void = { _ in }
    var onActiveSection: (String?) -> Void = { _ in }
    var onReady: () -> Void = {}
    var onReload: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            currentTitle: currentTitle,
            initialScrollY: initialScrollY,
            onSections: onSections,
            onImageTap: onImageTap,
            onFontScale: onFontScale,
            onInternalLink: onInternalLink,
            onScroll: onScroll,
            onActiveSection: onActiveSection,
            onReady: onReady,
            onReload: onReload
        )
    }

    /// Tear down the user-content controller's strong references to the
    /// Coordinator the instant SwiftUI dismantles the view. Without this, the
    /// Coordinator + UserContentController + WKWebView triangle stays alive
    /// after the SwiftUI view is gone — leaking on every push/pop.
    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        let controller = webView.configuration.userContentController
        controller.removeAllScriptMessageHandlers()
        controller.removeAllUserScripts()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        // Non-persistent: cookies, localStorage, IndexedDB live only for the
        // lifetime of this WebView and never persist to disk. We have no need
        // for cross-load state and this eliminates a fingerprinting / tracking
        // surface from malicious article content.
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(FontURLSchemeHandler(), forURLScheme: FontURLSchemeHandler.scheme)

        let controller = WKUserContentController()
        for source in Self.userScriptSources {
            controller.addUserScript(
                WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            )
        }
        controller.add(context.coordinator, name: "toc")
        controller.add(context.coordinator, name: "image")
        controller.add(context.coordinator, name: "fontScale")
        controller.add(context.coordinator, name: "scroll")
        controller.add(context.coordinator, name: "activeSection")
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.currentTitle = currentTitle
        context.coordinator.onSections = onSections
        context.coordinator.onImageTap = onImageTap
        context.coordinator.onFontScale = onFontScale
        context.coordinator.onInternalLink = onInternalLink
        context.coordinator.onScroll = onScroll
        context.coordinator.onActiveSection = onActiveSection
        context.coordinator.onReady = onReady
        context.coordinator.onReload = onReload
        context.coordinator.initialScrollY = initialScrollY

        // Stable hash deliberately excludes theme and fontScale so swapping themes
        // or pinching font size never reloads the document — both are applied via JS.
        var hasher = Hasher()
        hasher.combine(html)
        hasher.combine(language)
        hasher.combine(currentTitle)
        hasher.combine(heroImageURL?.absoluteString)
        if let focal = heroFocalPoint {
            hasher.combine(focal.x)
            hasher.combine(focal.y)
        }
        let stableHash = hasher.finalize()

        if context.coordinator.lastHash != stableHash {
            context.coordinator.lastHash = stableHash
            let composed = ArticleHTML.render(
                rawHTML: html,
                theme: theme,
                fontScale: fontScale,
                language: language,
                title: currentTitle,
                heroImageURL: heroImageURL,
                heroFocalPoint: heroFocalPoint
            )
            webView.loadHTMLString(composed, baseURL: baseURL)
        } else {
            // Same document — flip theme + scale via JS, no reload, no flash.
            let titleScale = min(max(fontScale, 0.85), 1.2)
            let js = """
            document.body && document.body.setAttribute('data-theme', '\(theme.cssDataTheme)');
            document.documentElement && document.documentElement.style.setProperty('--folio-font-scale', '\(fontScale)');
            document.documentElement && document.documentElement.style.setProperty('--folio-title-scale', '\(titleScale)');
            """
            webView.evaluateJavaScript(js)
        }

        if let anchor = pendingScrollAnchor {
            // JSON-encode the anchor so backslashes, newlines, quotes, and any
            // other special character are escaped to a valid JS string literal.
            // Anchors originate from article HTML and section IDs (untrusted) —
            // ad-hoc quote escaping is a JS-injection vector.
            let data = (try? JSONEncoder().encode(anchor)) ?? Data("\"\"".utf8)
            let json = String(data: data, encoding: .utf8) ?? "\"\""
            webView.evaluateJavaScript("window.folioScrollToAnchor && window.folioScrollToAnchor(\(json))")
            Task { @MainActor in pendingScrollAnchor = nil }
        }
    }

    private static let userScriptSources: [String] = {
        ["lazy", "toc", "footnotes", "images", "pinch", "scroll", "section"].compactMap { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "js") else { return nil }
            return try? String(contentsOf: url, encoding: .utf8)
        }
    }()

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var currentTitle: String
        var initialScrollY: Double
        var onSections: ([ArticleSection]) -> Void
        var onImageTap: (URL) -> Void
        var onFontScale: (Double) -> Void
        var onInternalLink: (ArticleDestination) -> Void
        var onScroll: (Double) -> Void
        var onActiveSection: (String?) -> Void
        var onReady: () -> Void
        var onReload: () -> Void

        var lastHash: Int = 0
        weak var webView: WKWebView?

        private static let nonArticleNamespaces: Set<String> = [
            "file", "image", "media", "special", "help", "wikipedia", "wp",
            "category", "template", "portal", "talk", "user", "user_talk",
            "template_talk", "category_talk", "file_talk", "wikipedia_talk",
            "help_talk", "portal_talk", "draft", "draft_talk", "mediawiki",
            "module", "module_talk", "timedtext", "book"
        ]

        init(
            currentTitle: String,
            initialScrollY: Double,
            onSections: @escaping ([ArticleSection]) -> Void,
            onImageTap: @escaping (URL) -> Void,
            onFontScale: @escaping (Double) -> Void,
            onInternalLink: @escaping (ArticleDestination) -> Void,
            onScroll: @escaping (Double) -> Void,
            onActiveSection: @escaping (String?) -> Void,
            onReady: @escaping () -> Void,
            onReload: @escaping () -> Void
        ) {
            self.currentTitle = currentTitle
            self.initialScrollY = initialScrollY
            self.onSections = onSections
            self.onImageTap = onImageTap
            self.onFontScale = onFontScale
            self.onInternalLink = onInternalLink
            self.onScroll = onScroll
            self.onActiveSection = onActiveSection
            self.onReady = onReady
            self.onReload = onReload
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            handle(name: message.name, body: message.body)
        }

        private func handle(name: String, body: Any) {
            switch name {
            case "toc":
                guard let array = body as? [[String: Any]] else { return }
                let sections = array.compactMap { dict -> ArticleSection? in
                    guard
                        let title = dict["title"] as? String,
                        let level = dict["level"] as? Int
                    else { return nil }
                    let anchor = dict["anchor"] as? String ?? ""
                    return ArticleSection(id: "\(level)-\(title)", level: level, title: title, anchor: anchor)
                }
                onSections(sections)

            case "image":
                guard
                    let dict = body as? [String: Any],
                    let urlString = dict["url"] as? String,
                    let url = URL(string: urlString),
                    url.scheme?.lowercased() == "https"
                else { return }
                onImageTap(url)

            case "fontScale":
                guard
                    let dict = body as? [String: Any],
                    let scale = dict["scale"] as? Double
                else { return }
                onFontScale(scale)

            case "scroll":
                guard
                    let dict = body as? [String: Any],
                    let y = dict["y"] as? Double
                else { return }
                onScroll(y)

            case "activeSection":
                guard let dict = body as? [String: Any] else { return }
                let raw = dict["id"] as? String ?? ""
                onActiveSection(raw.isEmpty ? nil : raw)

            default:
                break
            }
        }

        /// If iOS reaps our content process (memory pressure, jetsam, etc.)
        /// the WebView is left as a dead pane and `reload()` is a no-op for
        /// content loaded via `loadHTMLString` — there's no URL to reload.
        /// Bubble back to SwiftUI so it can re-roll the WebView identity and
        /// remount a fresh one through the regular render pipeline.
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            onReload()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onReady()
            guard initialScrollY > 0 else { return }
            let y = initialScrollY
            initialScrollY = 0  // restore only once per load
            // Tiny delay lets layout settle (especially the hero image) before we jump.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                webView.evaluateJavaScript("window.folioRestoreScroll && window.folioRestoreScroll(\(y))")
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }

            if navigationAction.navigationType == .linkActivated {
                return await classify(url: url)
            }

            // Non-link navigation (initial load, location.href = ..., form
            // submits, back/forward): only allow https, our font scheme, or
            // about:. Blocks javascript:, data:, file: redirects from
            // malicious article content.
            let scheme = url.scheme?.lowercased()
            if scheme == "https" || scheme == FontURLSchemeHandler.scheme || scheme == "about" {
                return .allow
            }
            return .cancel
        }

        private func classify(url: URL) async -> WKNavigationActionPolicy {
            guard
                let host = url.host?.lowercased(),
                let langMatch = host.firstMatch(of: /^([a-z]{2,3})(?:\.m)?\.wikipedia\.org$/),
                url.path.hasPrefix("/wiki/")
            else {
                await UIApplication.shared.open(url)
                return .cancel
            }

            let lang = String(langMatch.output.1)
            let rawPathTitle = String(url.path.dropFirst("/wiki/".count))
            let decoded = rawPathTitle.removingPercentEncoding ?? rawPathTitle

            // Same-article fragment → let WKWebView scroll natively
            if decoded == currentTitle, url.fragment != nil {
                return .allow
            }

            // Namespaced wiki pages (File:, Special:, etc.) are not articles.
            // Wikipedia treats namespace prefixes case-insensitively on the
            // first character (`/wiki/special:Export` is valid). Normalise.
            if let colonRange = decoded.range(of: ":") {
                let namespace = String(decoded[..<colonRange.lowerBound]).lowercased()
                if Self.nonArticleNamespaces.contains(namespace) {
                    await UIApplication.shared.open(url)
                    return .cancel
                }
            }

            onInternalLink(ArticleDestination(title: decoded, language: lang))
            return .cancel
        }
    }
}
