import Foundation

/// Wikimedia's UA policy wants a way to contact whoever is making the
/// requests. It accepts a project URL, which keeps a personal address out of
/// a public binary.
enum UserAgent {
    static let value: String = "Folio/\(version) (\(contact))"

    private static let contact = "https://github.com/hendryque/folio"

    private static let version: String = {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
    }()
}
