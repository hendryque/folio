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

    @State private var focalPoint: CGPoint?

    private var imageURL: URL? {
        article.imageURL(width: ThumbnailWidth.tile)
    }

    /// Maps the normalized focal point (top-left origin) to one of SwiftUI's nine
    /// fixed Alignment values. Vision delivers a true CGPoint; SwiftUI's frame
    /// alignment is discrete, so we bucket. Articles without detected faces use
    /// `.top` (faces almost always live above the equator).
    private var imageAlignment: Alignment {
        guard let f = focalPoint else { return .top }
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
                .frame(width: geo.size.width, height: height, alignment: imageAlignment)
                .clipped()

                tint.opacity(0.42)
                    .frame(width: geo.size.width, height: height)

                VStack(alignment: .leading, spacing: 8) {
                    Text(article.title.replacingOccurrences(of: "_", with: " "))
                        .font(.custom("EBGaramond-Italic", size: 22, relativeTo: .title3))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if let desc = article.description, !desc.isEmpty {
                        Text(desc.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.3)
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(width: geo.size.width, alignment: .leading)
            }
            .frame(width: geo.size.width, height: height)
            .clipped()
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .task(id: imageURL) {
            guard let url = imageURL else { return }
            focalPoint = await FocalPointDetector.shared.focalPoint(for: url)
        }
    }
}
