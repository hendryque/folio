import Foundation

/// The faces the reader WebView paints with, declared once. The `@font-face`
/// CSS, the scheme handler's allowlist and the per-theme preload queries are
/// all derived from this table, so a new face cannot be half-added.
enum BundledFonts {

    struct Face: Sendable {
        let family: String
        let file: String
        let ext: String
        let weight: Int
        let isItalic: Bool

        var cssFormat: String { ext == "otf" ? "opentype" : "truetype" }

        /// `document.fonts.load` shorthand. The size is arbitrary — matching is
        /// by family, weight and style — but the shorthand requires one.
        var loadQuery: String {
            "\(isItalic ? "italic " : "")\(weight) 16px \"\(family)\""
        }
    }

    static let garamond = "EB Garamond"
    static let barlow = "Barlow Semi Condensed"
    static let besley = "Besley"

    static let faces: [Face] = [
        Face(family: garamond, file: "EBGaramond-Regular", ext: "otf", weight: 400, isItalic: false),
        Face(family: garamond, file: "EBGaramond-Italic", ext: "otf", weight: 400, isItalic: true),
        Face(family: garamond, file: "EBGaramond-Bold", ext: "otf", weight: 700, isItalic: false),
        Face(family: garamond, file: "EBGaramond-BoldItalic", ext: "otf", weight: 700, isItalic: true),
        Face(family: barlow, file: "BarlowSemiCondensed-Regular", ext: "ttf", weight: 400, isItalic: false),
        Face(family: barlow, file: "BarlowSemiCondensed-Bold", ext: "ttf", weight: 700, isItalic: false),
        Face(family: besley, file: "Besley-Regular", ext: "ttf", weight: 400, isItalic: false),
        Face(family: besley, file: "Besley-Italic", ext: "ttf", weight: 400, isItalic: true),
        Face(family: besley, file: "Besley-Bold", ext: "ttf", weight: 700, isItalic: false),
        Face(family: besley, file: "Besley-BoldItalic", ext: "ttf", weight: 700, isItalic: true)
    ]

    static func queries(forFamilies families: [String]) -> [String] {
        faces.filter { families.contains($0.family) }.map(\.loadQuery)
    }

    static let articleCSS: String = faces.map { face in
        """
        @font-face {
            font-family: "\(face.family)";
            src: url("\(ReaderSchemeHandler.fontsPath)/\(face.file).\(face.ext)") format("\(face.cssFormat)");
            font-weight: \(face.weight);
            font-style: \(face.isItalic ? "italic" : "normal");
            font-display: block;
        }
        """
    }.joined(separator: "\n")
}
