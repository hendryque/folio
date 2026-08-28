import SwiftUI

struct Tile: View {
    let article: ArticleSummary
    let tintIndex: Int

    private static let tintColors: [Color] = [
        Color(red: 0.78, green: 0.42, blue: 0.20),  // burnt orange
        Color(red: 0.35, green: 0.55, blue: 0.35),  // forest green
        Color(red: 0.50, green: 0.25, blue: 0.45),  // plum
        Color(red: 0.65, green: 0.55, blue: 0.25),  // mustard
        Color(red: 0.25, green: 0.45, blue: 0.55),  // teal
        Color(red: 0.60, green: 0.28, blue: 0.30),  // brick
        Color(red: 0.38, green: 0.45, blue: 0.55),  // slate
        Color(red: 0.52, green: 0.50, blue: 0.28)   // olive
    ]

    private var tint: Color { Self.tintColors[tintIndex % Self.tintColors.count] }

    private var imageURL: URL? {
        article.imageURL(width: ThumbnailWidth.tile)
    }

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.width * 4.0 / 3.0
            ZStack(alignment: .bottomLeading) {
                tint
                RemoteImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Color.clear
                    }
                }
                // Today is a scanning surface: keep the first crop stable rather
                // than visibly repositioning a tile after Vision finishes.
                .frame(width: geo.size.width, height: height, alignment: .top)
                .clipped()

                // A flat tint darkens the whole tile uniformly, which leaves
                // white text unreadable over pale images. Put the darkness
                // where the text actually sits instead.
                tint.opacity(0.15)
                    .frame(width: geo.size.width, height: height)

                // A 3-line title reaches 53% of the tile, so the scrim has to
                // stay substantial that high: over a bright poster the old
                // ramp left the title at 1.5:1 contrast.
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.88), location: 0.0),
                        .init(color: .black.opacity(0.72), location: 0.32),
                        .init(color: .black.opacity(0.40), location: 0.60),
                        .init(color: .clear, location: 0.88)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(width: geo.size.width, height: height)
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 6) {
                    Text(article.title.replacingOccurrences(of: "_", with: " "))
                        .font(.custom("EBGaramond-MediumItalic", size: 22, relativeTo: .title3))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if let desc = article.description, !desc.isEmpty {
                        // Sentence case keeps the word shape readable at a
                        // glance; tracked caps forced letter-by-letter reading
                        // and ran to three lines on German descriptions.
                        Text(desc)
                            .font(.custom("EBGaramond-Medium", size: 13, relativeTo: .caption))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .shadow(color: .black.opacity(0.5), radius: 5, y: 1)
                .padding(14)
                .frame(width: geo.size.width, alignment: .leading)
            }
            .frame(width: geo.size.width, height: height)
            .clipped()
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
    }
}
