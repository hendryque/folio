import SwiftUI

struct SearchSuggestionsView: View {
    let query: String
    let language: String

    @State private var results: [SearchResult] = []
    @State private var inFlightTask: Task<Void, Never>?

    var body: some View {
        Group {
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyView()
            } else {
                ForEach(results) { result in
                    NavigationLink(value: ArticleDestination(title: result.title, language: language)) {
                        SearchResultRow(result: result)
                    }
                }
            }
        }
        .onChange(of: query) { _, newValue in
            scheduleSearch(newValue)
        }
        .onAppear {
            scheduleSearch(query)
        }
    }

    private func scheduleSearch(_ raw: String) {
        inFlightTask?.cancel()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        inFlightTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            do {
                let fetched = try await WikipediaClient.shared.search(query: trimmed, language: language)
                guard !Task.isCancelled else { return }
                results = fetched
            } catch {
                guard !Task.isCancelled else { return }
                results = []
            }
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(result.title)
                .font(.custom("EBGaramond-Regular", size: 17, relativeTo: .body))
                .foregroundStyle(.primary)
            if !result.summary.isEmpty {
                Text(result.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}
