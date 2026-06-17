import Foundation

enum ArticleHTML {
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
        heroImageURL: URL?,
        heroFocalPoint: CGPoint?
    ) -> String {
        var html = rawHTML

        // Drop Wikipedia's stylesheets so they don't fight our CSS
        html = stripPattern("<link[^>]*rel=[\"']stylesheet[\"'][^>]*>", in: html)
        html = stripPattern("<style[^>]*>[\\s\\S]*?</style>", in: html)

        // Pull the body content out; if we can't, fall back to the whole document
        let body = extractBody(from: html) ?? html

        let css = loadCSS()
        let themeName = theme.cssDataTheme
        let scale = String(format: "%.3f", fontScale)

        // First <p> still gets folio-lead in case we want to style it later;
        // drop cap is no longer applied (matches V for Wikipedia).
        let leadedBody = injectLeadClass(body)

        // Run text nodes through Typographizer for curly quotes + en-dashes
        let typographedBody = leadedBody.typographized(language: language, isHTML: true)

        let header = renderHeader(title: title, heroImageURL: heroImageURL, focalPoint: heroFocalPoint)

        return """
        <!DOCTYPE html>
        <html style="--folio-font-scale: \(scale);">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>\(css)</style>
        </head>
        <body data-theme="\(themeName)">
        \(header)
        \(typographedBody)
        </body>
        </html>
        """
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
        <header class="folio-header" style="background-image: url('\#(safeURL)'); background-position: \#(position);">
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
        let names = ["article", "theme-light", "theme-sepia", "theme-dark"]
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
