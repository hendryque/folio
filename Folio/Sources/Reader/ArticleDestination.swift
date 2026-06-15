import Foundation

struct ArticleDestination: Hashable, Sendable {
    let title: String
    let language: String?

    init(title: String, language: String? = nil) {
        self.title = title
        self.language = language
    }
}
