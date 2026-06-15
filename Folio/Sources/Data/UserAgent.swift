import Foundation

enum UserAgent {
    static let value: String = "Folio/\(version) (\(contact))"

    private static let contact = "gpt@geizhals.at"

    private static let version: String = {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
    }()
}
