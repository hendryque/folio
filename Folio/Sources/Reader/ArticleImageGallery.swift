import SwiftUI

/// Two-column Pinterest masonry. Each thumbnail renders at its natural aspect via
/// `scaledToFit`, so portrait + landscape photos both look right. SVG icons are
/// filtered upstream (see `MediaListResponse.galleryImages`).
struct ArticleImageGallery: View {
    let items: [MediaItem]
    let theme: Theme

    @State private var lightbox: IdentifiedURL?
    @Environment(\.dismiss) private var dismiss

    private var leftItems: [MediaItem] {
        stride(from: 0, to: items.count, by: 2).map { items[$0] }
    }
    private var rightItems: [MediaItem] {
        stride(from: 1, to: items.count, by: 2).map { items[$0] }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No images",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("This article doesn't have gallery-worthy images.")
                    )
                } else {
                    ScrollView {
                        HStack(alignment: .top, spacing: 8) {
                            LazyVStack(spacing: 8) {
                                ForEach(leftItems) { thumbnail($0) }
                            }
                            LazyVStack(spacing: 8) {
                                ForEach(rightItems) { thumbnail($0) }
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .background(themeBackground)
            .navigationTitle("Images")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .fullScreenCover(item: $lightbox) { wrapped in
            ImageLightbox(url: wrapped.url)
        }
    }

    @ViewBuilder
    private func thumbnail(_ item: MediaItem) -> some View {
        Button {
            lightbox = IdentifiedURL(url: item.originalURL)
        } label: {
            AsyncImage(url: item.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure, .empty:
                    Color(.tertiarySystemFill).aspectRatio(4 / 3, contentMode: .fit)
                @unknown default:
                    Color(.tertiarySystemFill).aspectRatio(4 / 3, contentMode: .fit)
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.caption ?? item.id)
    }

    private var themeBackground: Color {
        switch theme {
        case .sepia: Color(red: 0.957, green: 0.926, blue: 0.847)
        case .dark: Color(red: 0.102, green: 0.102, blue: 0.110)
        default: Color(.systemBackground)
        }
    }
}
