import Foundation
import SwiftUI
import Testing
@testable import Folio

/// The palette used to live in four stylesheets and partly in Theme, and the
/// chrome read neither. These pin the single source and the Auto resolution.
struct PaletteTests {

    @Test("Auto resolves against the device; every other theme stands alone")
    func autoResolves() {
        #expect(Theme.system.resolved(for: .dark) == .dark)
        #expect(Theme.system.resolved(for: .light) == .light)
        for theme in Theme.allCases where theme != .system {
            #expect(theme.resolved(for: .dark) == theme)
            #expect(theme.resolved(for: .light) == theme)
        }
    }

    @Test("Every theme emits a complete palette into the document")
    func paletteReachesTheStylesheet() {
        let required = [
            "--folio-bg", "--folio-fg", "--folio-secondary", "--folio-link",
            "--folio-link-underline", "--folio-divider", "--folio-accent",
            "--folio-card-bg", "--folio-code-bg"
        ]
        for theme in Theme.allCases {
            let css = theme.palette.cssVariables
            for name in required {
                #expect(css.contains(name + ":"), "\(theme.displayName) is missing \(name)")
            }
        }
    }

    @Test("Bars sit on a different tone than the page, so a bar has an edge")
    func barToneDiffersFromPaper() {
        for theme in Theme.allCases {
            #expect(theme.palette.card != theme.palette.background,
                    "\(theme.displayName) paints bars exactly the page colour")
        }
    }

    @Test("Hex conversion round-trips the channels")
    func hexChannels() {
        #expect(Theme.debug.palette.background == 0xe8e5de)
        #expect(Theme.debug.palette.cssVariables.contains("--folio-bg: #e8e5de"))
        #expect(Theme.dark.palette.cssVariables.contains("--folio-card-bg: #2a2a2c"))
    }

    @Test("The reader document carries the palette, not just the metrics")
    func documentCarriesPalette() {
        for theme in Theme.allCases {
            let doc = ArticleHTML.render(
                rawHTML: "<html><body><p>Prose.</p></body></html>",
                theme: theme,
                fontScale: 1.0,
                language: "de",
                title: "Bauhaus",
                articleURL: URL(string: "https://de.wikipedia.org/wiki/Bauhaus")!,
                heroImageURL: nil,
                heroFocalPoint: nil
            )
            #expect(doc.html.contains("--folio-bg:"))
            #expect(doc.html.contains("--folio-card-bg:"))
        }
    }
}
