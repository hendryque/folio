import Foundation
import SwiftData

func makeFolioModelContainer() -> ModelContainer {
    let schema = Schema([Bookmark.self, HistoryEntry.self, SearchHistoryEntry.self, AppSettings.self, CachedArticle.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    do {
        return try ModelContainer(for: schema, configurations: [config])
    } catch {
        fatalError("Failed to create Folio ModelContainer: \(error)")
    }
}
