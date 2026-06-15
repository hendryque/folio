import Foundation

/// CSS `@font-face` declarations for EB Garamond. Bytes are streamed by
/// `FontURLSchemeHandler` over the `folio-font://` scheme — no base64.
enum BundledFonts {
    static let articleCSS: String = """
    @font-face {
        font-family: "EB Garamond";
        src: url("folio-font://fonts/EBGaramond-Regular.otf") format("opentype");
        font-weight: 400;
        font-style: normal;
        font-display: block;
    }
    @font-face {
        font-family: "EB Garamond";
        src: url("folio-font://fonts/EBGaramond-Italic.otf") format("opentype");
        font-weight: 400;
        font-style: italic;
        font-display: block;
    }
    @font-face {
        font-family: "EB Garamond";
        src: url("folio-font://fonts/EBGaramond-Bold.otf") format("opentype");
        font-weight: 700;
        font-style: normal;
        font-display: block;
    }
    @font-face {
        font-family: "EB Garamond";
        src: url("folio-font://fonts/EBGaramond-BoldItalic.otf") format("opentype");
        font-weight: 700;
        font-style: italic;
        font-display: block;
    }
    """
}
