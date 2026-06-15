import SwiftUI

/// Shown the moment `summary` is available — typically ~150ms after tapping a tile —
/// while `mobile-html` is still in flight. Visually approximates the WebView reader
/// (hero image + italic title + extract) so the cross-fade when full HTML arrives
/// is mostly invisible.
struct ArticleLoadingPreview: View {
    let summary: ArticleSummary
    let theme: Theme
    let fontScale: Double
    let heroFocalPoint: CGPoint?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let url = summary.originalImageURL ?? summary.thumbnailURL {
                    hero(url: url)
                } else {
                    Text(displayTitle)
                        .font(.custom("EBGaramond-Italic", size: 34 * fontScale, relativeTo: .largeTitle))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                }

                if let extract = summary.extract {
                    Text(extract)
                        .font(.custom("EBGaramond-Regular", size: 17 * fontScale, relativeTo: .body))
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                }

                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading article…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDisabled(true)
        .background(backgroundColor)
    }

    private var displayTitle: String {
        summary.title.replacingOccurrences(of: "_", with: " ")
    }

    private var backgroundColor: Color {
        switch theme {
        case .sepia: Color(red: 0.957, green: 0.926, blue: 0.847)
        case .dark: Color(red: 0.102, green: 0.102, blue: 0.110)
        default: Color(.systemBackground)
        }
    }

    @ViewBuilder
    private func hero(url: URL) -> some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geo in
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        Color(.tertiarySystemFill)
                    @unknown default:
                        Color(.tertiarySystemFill)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width * 3 / 4, alignment: focalAlignment)
                .clipped()
            }
            .aspectRatio(4 / 3, contentMode: .fit)

            LinearGradient(
                colors: [.black.opacity(0.78), .black.opacity(0.40), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(maxHeight: .infinity, alignment: .bottom)
            .frame(height: 220)
            .allowsHitTesting(false)

            Text(displayTitle)
                .font(.custom("EBGaramond-Italic", size: 34 * fontScale, relativeTo: .largeTitle))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 12, y: 1)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
    }

    private var focalAlignment: Alignment {
        guard let f = heroFocalPoint else { return .top }
        let xq: Int = f.x < 0.34 ? -1 : (f.x > 0.66 ? 1 : 0)
        let yq: Int = f.y < 0.34 ? -1 : (f.y > 0.66 ? 1 : 0)
        switch (xq, yq) {
        case (-1, -1): return .topLeading
        case ( 0, -1): return .top
        case ( 1, -1): return .topTrailing
        case (-1,  0): return .leading
        case ( 0,  0): return .center
        case ( 1,  0): return .trailing
        case (-1,  1): return .bottomLeading
        case ( 0,  1): return .bottom
        case ( 1,  1): return .bottomTrailing
        default: return .top
        }
    }
}
