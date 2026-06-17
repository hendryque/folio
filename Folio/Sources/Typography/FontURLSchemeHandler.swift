import Foundation
@preconcurrency import WebKit

/// Streams bundled OTF files to the WKWebView on demand via the `folio-font://` scheme.
/// CSS references each face as `folio-font://fonts/EBGaramond-Italic.otf` and WebKit asks
/// us for the bytes. Saves ~2 MB of base64 per article render and lets the OS cache the
/// fonts across loads.
final class FontURLSchemeHandler: NSObject, WKURLSchemeHandler {

    static let scheme = "folio-font"

    /// Explicit allowlist of font baseNames we'll serve. Without this, any
    /// `folio-font://anything/AnyOtfInBundle.otf` URL inside article CSS we
    /// don't control could read any `.otf` we bundle. Adding the wildcard
    /// CORS header on top would have made every bundled OTF cross-origin
    /// readable from any iframe / SVG too.
    private static let allowedFonts: Set<String> = [
        "EBGaramond-Regular",
        "EBGaramond-Italic",
        "EBGaramond-Bold",
        "EBGaramond-BoldItalic"
    ]

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        let fileName = url.lastPathComponent
        let baseName = (fileName as NSString).deletingPathExtension

        guard
            Self.allowedFonts.contains(baseName),
            let fontURL = Bundle.main.url(forResource: baseName, withExtension: "otf"),
            let data = try? Data(contentsOf: fontURL)
        else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "font/otf",
                "Content-Length": "\(data.count)",
                "Cache-Control": "public, max-age=31536000, immutable"
            ]
        )!
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        // Bundle reads complete synchronously; nothing to cancel.
    }
}
