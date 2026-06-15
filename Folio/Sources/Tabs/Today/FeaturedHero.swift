import SwiftUI

struct FeaturedHero: View {
    let article: ArticleSummary
    let language: String

    var body: some View {
        NavigationLink(value: ArticleDestination(title: article.title, language: language)) {
            VStack(alignment: .leading, spacing: 0) {
                if let url = article.originalImageURL ?? article.thumbnailURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure, .empty:
                            Color(.tertiarySystemFill)
                        @unknown default:
                            Color(.tertiarySystemFill)
                        }
                    }
                    .frame(height: 260)
                    .clipped()
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Featured Article")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Text(article.title.replacingOccurrences(of: "_", with: " "))
                        .font(.custom("EBGaramond-Regular", size: 28, relativeTo: .body))
                        .foregroundStyle(.primary)
                    if let extract = article.extract {
                        Text(extract)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}
