import Foundation
import Testing
@testable import Folio

/// These cover the invariants that broke silently once before: the reader
/// document's origin, and the face list that used to be copied by hand into
/// three places.
struct ReaderDocumentTests {

    private func render(theme: Theme = .light, language: String = "en") -> ArticleHTML.Document {
        ArticleHTML.render(
            rawHTML: "<html><body><p>Ordinary prose, 1919 and all that.</p></body></html>",
            theme: theme,
            fontScale: 1.0,
            language: language,
            title: "Bauhaus",
            articleURL: URL(string: "https://en.wikipedia.org/wiki/Bauhaus")!,
            heroImageURL: nil,
            heroFocalPoint: nil
        )
    }

    @Test("The document loads from the reader origin, not the article URL")
    func documentLoadsFromReaderOrigin() {
        #expect(render().baseURL == ReaderSchemeHandler.documentURL)
    }

    @Test("The base href points at Wikipedia so links and images still resolve")
    func baseHrefIsTheArticleURL() {
        let html = render().html
        #expect(html.contains(#"<base href="https://en.wikipedia.org/wiki/Bauhaus">"#))
        #expect(!html.contains("<base href=\"\(ReaderSchemeHandler.scheme)"))
    }

    @Test("Every theme ships the faces painted.js will wait for")
    func fontQueriesTravelWithTheDocument() throws {
        for theme in Theme.allCases {
            let html = render(theme: theme).html
            let marker = "data-font-queries=\""
            let start = try #require(html.range(of: marker))
            let end = try #require(html.range(of: "\"", range: start.upperBound..<html.endIndex))
            let escaped = String(html[start.upperBound..<end.lowerBound])
            let json = escaped.replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&amp;", with: "&")
            let queries = try #require(
                try JSONDecoder().decode([String].self, from: Data(json.utf8))
            )
            #expect(queries == theme.webFontQueries)
            #expect(!queries.isEmpty)
        }
    }

    @Test("Reader metrics reach the stylesheet from Theme")
    func metricsAreInjected() {
        for theme in Theme.allCases {
            let html = render(theme: theme).html
            #expect(html.contains("--folio-body-size: \(String(format: "%.1f", theme.bodySize))px"))
            #expect(html.contains("--folio-body-leading: \(String(format: "%.3f", theme.bodyLineHeight))"))
            #expect(html.contains("--folio-measure: \(String(format: "%.0f", theme.measureRem))rem"))
        }
    }

    /// The interlinear channel should sit a little over one x-height, which is
    /// the craft principle the reader's leading is derived from. Ink depth and
    /// x-height are measured from the shipping files, in em.
    @Test("Every theme's leading keeps the channel near one x-height")
    func leadingKeepsTheChannelOpen() {
        let face: [String: (ink: Double, xHeight: Double)] = [
            "EBGaramond-Regular": (1.085, 0.409)
        ]
        for theme in Theme.allCases {
            guard let m = face[theme.bodyFontName] else {
                Issue.record("no metrics recorded for \(theme.bodyFontName)")
                continue
            }
            let channel = (theme.bodyLineHeight - m.ink) / m.xHeight
            #expect(channel > 0.95 && channel < 1.30,
                    "\(theme.displayName) channel is \(channel) x-heights")
        }
    }

    @Test("The colophon escapes the URLs it embeds")
    func colophonIsEscaped() {
        let html = render(language: "de").html
        #expect(html.contains("folio-colophon"))
        #expect(html.contains("creativecommons.org/licenses/by-sa/4.0/deed.de"))
        #expect(!html.contains("action=history\"><script"))
    }
}
