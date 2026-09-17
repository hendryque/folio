import Foundation
import Testing
@testable import Folio

/// The face list was once copied into the CSS, the handler allowlist and the
/// per-theme preload queries by hand. These assert the copies stay derived.
struct BundledFontsTests {

    @Test("Every declared face is present in the generated CSS")
    func everyFaceReachesTheStylesheet() {
        let css = BundledFonts.articleCSS
        for face in BundledFonts.faces {
            #expect(css.contains("\(face.file).\(face.ext)"), "\(face.file) missing from the CSS")
            #expect(css.contains("font-family: \"\(face.family)\""))
        }
    }

    @Test("Every declared face is actually bundled")
    func everyFaceIsBundled() {
        for face in BundledFonts.faces {
            let url = Bundle.main.url(forResource: face.file, withExtension: face.ext)
            #expect(url != nil, "\(face.file).\(face.ext) is declared but not in the bundle")
        }
    }

    @Test("Faces are served from the reader origin, never a bare path")
    func facesAreServedFromTheReaderOrigin() {
        #expect(BundledFonts.articleCSS.contains(ReaderSchemeHandler.fontsPath))
    }

    @Test("Every theme names only families the table declares")
    func themeFamiliesAreDeclared() {
        let declared = Set(BundledFonts.faces.map(\.family))
        for theme in Theme.allCases {
            for family in theme.webFontFamilies {
                #expect(declared.contains(family), "\(family) is not a declared family")
            }
            #expect(!theme.webFontQueries.isEmpty)
        }
    }

    @Test("Each theme's body face is one the table declares and bundles")
    func themeBodyFacesAreBundled() {
        let files = Set(BundledFonts.faces.map(\.file))
        for theme in Theme.allCases {
            #expect(files.contains(theme.bodyFontName), "\(theme.bodyFontName) is not a declared face")
            #expect(files.contains(theme.bodyBoldFontName))
            #expect(files.contains(theme.titleFontName))
        }
    }

    @Test("A theme only waits for faces it can actually paint with")
    func themeQueriesCoverItsBodyFace() {
        for theme in Theme.allCases {
            let family = BundledFonts.faces.first { $0.file == theme.bodyFontName }?.family
            #expect(family != nil)
            #expect(theme.webFontFamilies.contains(family!),
                    "\(theme.displayName) paints in \(family!) but never waits for it")
        }
    }

    @Test("Load queries carry weight and style so the right face is awaited")
    func loadQueriesAreWellFormed() {
        let italic = BundledFonts.faces.first { $0.isItalic }
        #expect(italic?.loadQuery.hasPrefix("italic ") == true)
        let upright = BundledFonts.faces.first { !$0.isItalic && $0.weight == 700 }
        #expect(upright?.loadQuery.hasPrefix("700 ") == true)
    }
}
