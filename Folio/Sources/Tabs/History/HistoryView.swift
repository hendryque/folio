import SwiftUI
import SwiftData

struct HistoryView: View {
    let onRerunSearch: (String) -> Void

    @Query(sort: \HistoryEntry.readAt, order: .reverse) private var articleHistory: [HistoryEntry]
    @Query(sort: \SearchHistoryEntry.searchedAt, order: .reverse) private var searchHistory: [SearchHistoryEntry]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if articleHistory.isEmpty && searchHistory.isEmpty {
                EmptyStateView(
                    icon: "clock",
                    title: "No history yet",
                    message: "Articles you read and searches you make will appear here."
                )
            } else {
                List {
                    ForEach(merged) { item in
                        Row(item: item, onRerunSearch: onRerunSearch)
                            .listRowSeparator(.visible)
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)
            }
        }
        .task { collapseDuplicates() }
    }

    /// Earlier builds stored one row per visit. Collapse the leftovers so each
    /// article and query appears once, at its most recent time.
    private func collapseDuplicates() {
        var seenArticles = Set<String>()
        for entry in articleHistory where !seenArticles.insert("\(entry.language)|\(entry.title)").inserted {
            modelContext.delete(entry)
        }
        var seenSearches = Set<String>()
        for entry in searchHistory where !seenSearches.insert("\(entry.language)|\(entry.query)").inserted {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }

    /// Article visits and search queries interleaved by timestamp, newest first.
    private var merged: [HistoryItem] {
        let articles = articleHistory.map(HistoryItem.article)
        let searches = searchHistory.map(HistoryItem.search)
        return (articles + searches).sorted { $0.occurredAt > $1.occurredAt }
    }

    private func delete(at offsets: IndexSet) {
        let snapshot = merged
        for index in offsets {
            switch snapshot[index] {
            case .article(let entry): modelContext.delete(entry)
            case .search(let entry): modelContext.delete(entry)
            }
        }
        try? modelContext.save()
    }
}

private enum HistoryItem: Identifiable {
    case article(HistoryEntry)
    case search(SearchHistoryEntry)

    var id: PersistentIdentifier {
        switch self {
        case .article(let entry): entry.persistentModelID
        case .search(let entry): entry.persistentModelID
        }
    }

    var occurredAt: Date {
        switch self {
        case .article(let entry): entry.readAt
        case .search(let entry): entry.searchedAt
        }
    }
}

/// One row in the merged stream. Article visits are a NavigationLink (push the
/// article), search queries are a Button (refill the search bar so the live
/// results overlay appears).
private struct Row: View {
    let item: HistoryItem
    let onRerunSearch: (String) -> Void

    var body: some View {
        switch item {
        case .article(let entry):
            NavigationLink(value: ArticleDestination(title: entry.title, language: entry.language)) {
                ArticleRowLabel(entry: entry)
            }
        case .search(let entry):
            Button {
                onRerunSearch(entry.query)
            } label: {
                SearchRowLabel(entry: entry)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ArticleRowLabel: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.title.replacingOccurrences(of: "_", with: " "))
                .font(.custom("EBGaramond-Bold", size: 19, relativeTo: .body))
                .foregroundStyle(Color.accentColor)
                .lineLimit(2)
            Spacer(minLength: 8)
            LanguageBadge(language: entry.language)
        }
        .padding(.vertical, 4)
    }
}

private struct SearchRowLabel: View {
    let entry: SearchHistoryEntry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.accentColor)
            Text(entry.query)
                .font(.custom("EBGaramond-Regular", size: 18, relativeTo: .body))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
            Spacer(minLength: 8)
            LanguageBadge(language: entry.language)
        }
        .padding(.vertical, 4)
    }
}

private struct LanguageBadge: View {
    let language: String

    var body: some View {
        Text(language.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}
