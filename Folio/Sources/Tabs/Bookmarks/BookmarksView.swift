import SwiftUI
import SwiftData

struct BookmarksView: View {
    @Query(sort: \Bookmark.addedAt, order: .reverse) private var bookmarks: [Bookmark]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if bookmarks.isEmpty {
                EmptyStateView(
                    icon: "bookmark",
                    title: "No bookmarks yet",
                    message: "Tap the star in an article to save it here."
                )
            } else {
                List {
                    ForEach(bookmarks) { bookmark in
                        NavigationLink(value: ArticleDestination(title: bookmark.title, language: bookmark.language)) {
                            SavedArticleRow(
                                title: bookmark.title,
                                summary: bookmark.summary,
                                thumbnailURL: bookmark.thumbnailURL
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
            modelContext.delete(bookmarks[index])
        }
        try? modelContext.save()
    }
}
