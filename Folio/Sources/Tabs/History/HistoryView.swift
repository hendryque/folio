import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \HistoryEntry.readAt, order: .reverse) private var history: [HistoryEntry]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if history.isEmpty {
                EmptyStateView(
                    icon: "clock",
                    title: "No history yet",
                    message: "Articles you read will appear here."
                )
            } else {
                List {
                    ForEach(history) { entry in
                        NavigationLink(value: ArticleDestination(title: entry.title, language: entry.language)) {
                            SavedArticleRow(
                                title: entry.title,
                                summary: entry.summary,
                                thumbnailURL: entry.thumbnailURL
                            )
                        }
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(history[index])
        }
        try? modelContext.save()
    }
}
