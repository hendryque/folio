import SwiftUI

struct MostReadGrid: View {
    let articles: [ArticleSummary]
    let language: String

    @Environment(\.horizontalSizeClass) private var hSizeClass

    private var columns: [GridItem] {
        let count = hSizeClass == .regular ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(label: "Most Read")

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(articles.prefix(8)) { article in
                    NavigationLink(value: ArticleDestination(title: article.title, language: language)) {
                        MostReadTile(article: article)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct MostReadTile: View {
    let article: ArticleSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: article.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure, .empty:
                    Color(.tertiarySystemFill)
                @unknown default:
                    Color(.tertiarySystemFill)
                }
            }
            .frame(height: 100)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(article.title.replacingOccurrences(of: "_", with: " "))
                    .font(.custom("EBGaramond-Regular", size: 16, relativeTo: .body))
                    .lineLimit(2)
                if let description = article.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 1)
    }
}
