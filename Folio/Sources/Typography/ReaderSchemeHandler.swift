import Foundation
@preconcurrency import WebKit

/// Serves the reader's own origin, `folio://reader`. The article document loads
/// from here, not from the Wikipedia URL, because WebKit refuses a custom-scheme
/// subresource from an https origin and the fonts would never load.
final class ReaderSchemeHandler: NSObject, WKURLSchemeHandler {

    nonisolated static let scheme = "folio"
    nonisolated static let host = "reader"
    nonisolated static let origin = "\(scheme)://\(host)"
    nonisolated static let documentURL = URL(string: "\(origin)/article.html")!
    nonisolated static let fontsDirectory = "fonts"
    nonisolated static let fontsPath = "\(origin)/\(fontsDirectory)"

    /// Derived from the one face table, so the CSS can never name a face the
    /// handler won't serve. Without it, any `folio://reader/fonts/…` URL in
    /// article CSS we don't control could read any font we bundle.
    private static let allowedFonts: Set<String> = Set(BundledFonts.faces.map(\.file))

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        let fileName = url.lastPathComponent
        let baseName = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension.lowercased()
        let directory = url.deletingLastPathComponent().lastPathComponent

        guard
            url.host?.lowercased() == Self.host,
            directory == Self.fontsDirectory,
            Self.allowedFonts.contains(baseName),
            ["otf", "ttf"].contains(ext),
            let fontURL = Bundle.main.url(forResource: baseName, withExtension: ext),
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
                "Content-Type": ext == "ttf" ? "font/ttf" : "font/otf",
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
