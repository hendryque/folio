import SwiftUI

struct NearbyCarousel: View {
    let articles: [NearbyArticle]
    @Binding var selectedID: Int?
    let language: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(articles) { article in
                        NearbyCard(article: article, language: language)
                            .id(article.id)
                            .frame(width: 280)
                            .onTapGesture {
                                selectedID = article.id
                            }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
            }
            .scrollTargetBehavior(.viewAligned)
            .onChange(of: selectedID) { _, newID in
                guard let newID else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
            .onChange(of: articles.first?.id) { _, newFirstID in
                guard let newFirstID else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    proxy.scrollTo(newFirstID, anchor: .leading)
                }
            }
        }
    }
}

private struct NearbyCard: View {
    let article: NearbyArticle
    let language: String

    // The batch geosearch only carries thumbnails for its first 50 pages —
    // cards beyond that fetch their own lazily (LazyHStack: visible ones only).
    @State private var fetchedThumbnail: URL?

    var body: some View {
        NavigationLink(value: ArticleDestination(title: article.title, language: language)) {
            HStack(spacing: 12) {
                RemoteImage(url: article.thumbnailURL ?? fetchedThumbnail) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure, .empty: Color(.tertiarySystemFill)
                    @unknown default: Color(.tertiarySystemFill)
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title.replacingOccurrences(of: "_", with: " "))
                        .font(.custom("EBGaramond-Regular", size: 16, relativeTo: .body))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let desc = article.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .task(id: article.id) {
            guard article.thumbnailURL == nil, fetchedThumbnail == nil else { return }
            fetchedThumbnail = (try? await WikipediaClient.shared.summary(title: article.title, language: language))?
                .thumbnailURL?
                .wikimediaResized(to: ThumbnailWidth.row)
        }
    }
}
