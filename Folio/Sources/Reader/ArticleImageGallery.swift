import SwiftUI

struct ArticleImageGallery: View {
    let items: [MediaItem]
    let theme: Theme

    @State private var lightbox: IdentifiedURL?
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

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
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(items) { item in
                                Button {
                                    lightbox = IdentifiedURL(url: item.originalURL)
                                } label: {
                                    AsyncImage(url: item.thumbnailURL) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        case .failure, .empty:
                                            Color(.tertiarySystemFill)
                                        @unknown default:
                                            Color(.tertiarySystemFill)
                                        }
                                    }
                                    .aspectRatio(1, contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(item.caption ?? item.id)
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

    private var themeBackground: Color {
        switch theme {
        case .sepia: Color(red: 0.957, green: 0.926, blue: 0.847)
        case .dark: Color(red: 0.102, green: 0.102, blue: 0.110)
        default: Color(.systemBackground)
        }
    }
}
