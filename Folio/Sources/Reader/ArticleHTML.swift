import Foundation

enum ArticleHTML {

    /// An article and the URL it must be loaded with. The two travel together
    /// because the document has to load from the reader's own origin while its
    /// `<base href>` points at Wikipedia; loading it with the article URL would
    /// silently stop every bundled font from resolving.
    struct Document {
        let html: String
        let baseURL: URL
    }

    /// Wraps Wikipedia's `mobile-html` body with Folio's own `<head>` (themed CSS, viewport meta),
    /// strips conflicting Wikipedia stylesheet links and the document chrome, and marks the lead
    /// paragraph for the drop-cap rule. Optionally runs the body text through Typographizer for
    /// locale-aware smart quotes and en-dashes.
    static func render(
        rawHTML: String,
        theme: Theme,
        fontScale: Double,
        language: String,
        title: String,
        articleURL: URL,
        heroImageURL: URL?,
        heroFocalPoint: CGPoint?
    ) -> Document {
        var html = rawHTML

        // Drop Wikipedia's stylesheets so they don't fight our CSS
        html = stripPattern("<link[^>]*rel=[\"']stylesheet[\"'][^>]*>", in: html)
        html = stripPattern("<style[^>]*>[\\s\\S]*?</style>", in: html)

        // Pull the body content out; if we can't, fall back to the whole document
        let body = extractBody(from: html) ?? html
        let deduplicatedBody = removeDuplicateHeroFigure(from: body, heroImageURL: heroImageURL)

        let css = loadCSS()
        let themeName = theme.cssDataTheme
        let scale = String(format: "%.3f", fontScale)
        // Display titles should respond to the reader setting without growing
        // so far that long titles overflow the fixed 4:3 hero.
        let titleScale = String(format: "%.3f", min(max(fontScale, 0.85), 1.2))

        // First <p> still gets folio-lead in case we want to style it later;
        // drop cap is no longer applied (matches V for Wikipedia).
        let leadedBody = injectLeadClass(deduplicatedBody)

        // Run text nodes through Typographizer for curly quotes + en-dashes
        let typographedBody = leadedBody.typographized(language: language, isHTML: true)

        let header = renderHeader(title: title, heroImageURL: heroImageURL, focalPoint: heroFocalPoint)

        // painted.js waits on exactly these before signalling first paint.
        let fontQueriesJSON = (try? JSONEncoder().encode(theme.webFontQueries))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        // The stylesheet reads both the palette and the metrics from here, so
        // the chrome and the article ground cannot drift apart and the preview
        // cannot drift from what it fades into.
        let metrics = String(
            format: "--folio-body-size: %.1fpx; --folio-body-leading: %.3f; --folio-measure: %.0frem;",
            theme.bodySize, theme.bodyLineHeight, theme.measureRem
        ) + " " + theme.palette.cssVariables

        let rendered = """
        <!DOCTYPE html>
        <html lang="\(htmlEscape(language))" data-font-queries="\(htmlEscape(fontQueriesJSON))" style="\(metrics) --folio-font-scale: \(scale); --folio-title-scale: \(titleScale);">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <base href="\(htmlEscape(articleURL.absoluteString))">
        <style>\(css)</style>
        </head>
        <body data-theme="\(themeName)">
        \(header)
        \(typographedBody)
        \(renderColophon(title: title, language: language, articleURL: articleURL))
        </body>
        </html>
        """
        return Document(html: rendered, baseURL: ReaderSchemeHandler.documentURL)
    }

    /// CC BY-SA wants attribution at the point of use, not only in About:
    /// name the source and license and link the article and its authors.
    private static func renderColophon(title: String, language: String, articleURL: URL) -> String {
        let historyURL = WikipediaEndpoint.historyURL(title: title, language: language)?.absoluteString
            ?? articleURL.absoluteString
        let licenseURL = language == "de"
            ? "https://creativecommons.org/licenses/by-sa/4.0/deed.de"
            : "https://creativecommons.org/licenses/by-sa/4.0/"
        let text = language == "de"
            ? "Text: <a href=\"\(htmlEscape(articleURL.absoluteString))\">Wikipedia</a>, Lizenz <a href=\"\(licenseURL)\">CC BY-SA 4.0</a> · <a href=\"\(htmlEscape(historyURL))\">Autorinnen und Autoren</a>"
            : "Text: <a href=\"\(htmlEscape(articleURL.absoluteString))\">Wikipedia</a>, licensed <a href=\"\(licenseURL)\">CC BY-SA 4.0</a> · <a href=\"\(htmlEscape(historyURL))\">article contributors</a>"
        return "<footer class=\"folio-colophon\">\(text)</footer>"
    }

    private static func renderHeader(title: String, heroImageURL: URL?, focalPoint: CGPoint?) -> String {
        let display = htmlEscape(title.replacingOccurrences(of: "_", with: " "))
        guard let url = heroImageURL else {
            return #"""
            <header class="folio-header folio-header-textonly">
              <h1 class="folio-title">\#(display)</h1>
            </header>
            """#
        }
        // CSS escape: the URL goes inside a single-quoted CSS `url('…')`
        // declaration inside a `style=` attribute. Backslashes start CSS
        // escape sequences and survive URL encoding round-trips; newlines
        // would terminate the property declaration. Encode them along with
        // the quote characters.
        let safeURL = url.absoluteString
            .replacingOccurrences(of: "\\", with: "%5C")
            .replacingOccurrences(of: "\"", with: "%22")
            .replacingOccurrences(of: "'", with: "%27")
            .replacingOccurrences(of: "\n", with: "%0A")
            .replacingOccurrences(of: "\r", with: "%0D")
        let position: String
        if let focal = focalPoint {
            let px = max(0, min(100, focal.x * 100))
            let py = max(0, min(100, focal.y * 100))
            position = String(format: "%.1f%% %.1f%%", px, py)
        } else {
            position = "50% 28%"
        }
        return #"""
        <header class="folio-header" data-hero-src="\#(safeURL)" style="background-image: url('\#(safeURL)'); background-position: \#(position);">
          <h1 class="folio-title">\#(display)</h1>
        </header>
        """#
    }

    private static func htmlEscape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func loadCSS() -> String {
        let names = ["article", "theme-debug"]
        let bundled = names.compactMap { resource(name: $0, ext: "css") }.joined(separator: "\n\n")
        return BundledFonts.articleCSS + "\n\n" + bundled
    }

    private static func resource(name: String, ext: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private static func stripPattern(_ pattern: String, in input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return input }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: "")
    }

    private static func extractBody(from html: String) -> String? {
        guard
            let openRange = html.range(of: "<body[^>]*>", options: [.caseInsensitive, .regularExpression]),
            let closeRange = html.range(of: "</body>", options: .caseInsensitive)
        else { return nil }
        return String(html[openRange.upperBound..<closeRange.lowerBound])
    }

    /// Folio promotes the summary image into its own hero. Wikipedia often
    /// repeats that same file as a lead figure after the opening paragraph;
    /// leaving it in place renders one editorial image twice in succession.
    /// Compare file identities rather than full URLs because the feed and
    /// mobile HTML request different thumbnail widths and CDN hosts.
    private static func removeDuplicateHeroFigure(from body: String, heroImageURL: URL?) -> String {
        guard
            let heroImageURL,
            let heroFileName = wikimediaFileName(in: heroImageURL.absoluteString),
            let figureRegex = try? NSRegularExpression(
                pattern: "<figure\\b[^>]*>[\\s\\S]*?</figure>",
                options: .caseInsensitive
            ),
            let attributeRegex = try? NSRegularExpression(
                pattern: #"(?:href|(?:data-)*src|(?:data-)*resource)\s*=\s*["']([^"']+)["']"#,
                options: .caseInsensitive
            )
        else { return body }

        let nsBody = body as NSString
        let bodyRange = NSRange(location: 0, length: nsBody.length)
        for figureMatch in figureRegex.matches(in: body, options: [], range: bodyRange) {
            let figure = nsBody.substring(with: figureMatch.range)
            let nsFigure = figure as NSString
            let figureRange = NSRange(location: 0, length: nsFigure.length)
            let containsHero = attributeRegex.matches(in: figure, options: [], range: figureRange).contains { match in
                guard match.numberOfRanges > 1 else { return false }
                let reference = nsFigure.substring(with: match.range(at: 1))
                return wikimediaFileName(in: reference) == heroFileName
            }
            guard containsHero else { continue }
            return nsBody.replacingCharacters(in: figureMatch.range, with: "")
        }
        return body
    }

    /// Returns the original Wikimedia filename from originals, resized thumb
    /// URLs, and Parsoid references such as `./Datei:Example.jpg`.
    private static func wikimediaFileName(in reference: String) -> String? {
        let unescaped = reference
            .replacingOccurrences(of: "&amp;", with: "&", options: .caseInsensitive)
            .replacingOccurrences(of: "&quot;", with: "\"", options: .caseInsensitive)
            .replacingOccurrences(of: "&#39;", with: "'", options: .caseInsensitive)
            .replacingOccurrences(of: "&#x27;", with: "'", options: .caseInsensitive)
        // Remove URL structure before percent-decoding so a legitimate `%3F`
        // or `%23` inside a filename is not mistaken for query/fragment syntax.
        let withoutFragment = unescaped.split(separator: "#", maxSplits: 1).first.map(String.init) ?? unescaped
        let withoutQuery = withoutFragment.split(separator: "?", maxSplits: 1).first.map(String.init) ?? withoutFragment
        let decoded = withoutQuery.removingPercentEncoding ?? withoutQuery

        if let namespaceRange = decoded.range(
            of: #"(?:^|/)(?:File|Datei):"#,
            options: [.caseInsensitive, .regularExpression]
        ) {
            return normalizedFileName(String(decoded[namespaceRange.upperBound...]))
        }

        let components = decoded.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        if let thumbIndex = components.firstIndex(where: { $0.caseInsensitiveCompare("thumb") == .orderedSame }),
           components.indices.contains(thumbIndex + 3) {
            return normalizedFileName(components[thumbIndex + 3])
        }
        guard let last = components.last else { return nil }
        return normalizedFileName(last)
    }

    private static func normalizedFileName(_ fileName: String) -> String {
        fileName
            .replacingOccurrences(of: " ", with: "_")
            .precomposedStringWithCanonicalMapping
    }

    /// mobile-html starts the body with a description `<p>` and an empty `<p class="mw-empty-elt">`,
    /// so "first <p>" isn't the same as "lead paragraph." The real lead is the first non-skipped
    /// `<p>` whose plain-text content is substantive — typically `<p><b>Article Subject</b>…`.
    private static func injectLeadClass(_ body: String) -> String {
        let pattern = "<p\\b([^>]*)>([\\s\\S]*?)</p>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return body
        }
        let mutable = NSMutableString(string: body)
        var inserted = false
        regex.enumerateMatches(in: body, options: [], range: NSRange(location: 0, length: mutable.length)) { match, _, stop in
            guard !inserted, let match else { return }
            let nsBody = body as NSString
            let attrs = nsBody.substring(with: match.range(at: 1))
            let inner = nsBody.substring(with: match.range(at: 2))

            if attrs.contains("pcs-edit-section-title-description") { return }
            if attrs.contains("mw-empty-elt") { return }
            if attrs.contains("shortdescription") { return }

            let plain = inner
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard plain.count >= 30 else { return }

            inserted = true
            // Prepend `folio-lead` to the <p>'s class list, preserving everything else.
            let newAttrs: String
            if attrs.range(of: "class=", options: .caseInsensitive) != nil {
                newAttrs = attrs.replacingOccurrences(
                    of: #"class\s*=\s*"([^"]*)""#,
                    with: #"class="folio-lead $1""#,
                    options: .regularExpression
                )
            } else {
                newAttrs = " class=\"folio-lead\"" + attrs
            }
            let newTag = "<p" + newAttrs + ">"
            mutable.replaceCharacters(in: match.range(at: 0), with: newTag + inner + "</p>")
            stop.pointee = true
        }
        return mutable as String
    }
}
