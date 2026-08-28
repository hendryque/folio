import SwiftUI
import UIKit

/// Shown the moment `summary` is available — typically ~150ms after tapping a tile —
/// while `mobile-html` is still in flight. Visually approximates the WebView reader
/// (hero image + italic title + extract) so the cross-fade when full HTML arrives
/// is mostly invisible.
struct ArticleLoadingPreview: View {
    let summary: ArticleSummary
    let theme: Theme
    let fontScale: Double
    let heroFocalPoint: CGPoint?

    private var heroRef: ImageRef? {
        summary.originalImage ?? summary.thumbnail
    }

    /// Aspect ratio (w/h) of the hero source — read off Wikipedia's reported
    /// dimensions so our preview crop matches the WebView's `background-size: cover`
    /// at the same focal point. Falls back to the container aspect (no overflow)
    /// when dimensions aren't reported.
    private var heroImageAspect: CGFloat? {
        guard let w = heroRef?.width, let h = heroRef?.height, h > 0 else { return nil }
        return CGFloat(w) / CGFloat(h)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Same sized URL the WebView hero uses, so the preview and the
                    // article share one download and one cache entry.
                    if let url = summary.imageURL(width: ThumbnailWidth.hero) {
                        hero(url: url)
                    } else {
                        Text(displayTitle)
                            .font(.custom("EBGaramond-Italic", size: textOnlyTitleSize, relativeTo: .largeTitle))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 16)
                    }

                    if summary.extract != nil {
                        Text(styledExtract)
                            .font(.custom("EBGaramond-Regular", size: 17 * fontScale, relativeTo: .body))
                            .foregroundStyle(.primary)
                            .lineSpacing(extractLineSpacing)
                            .padding(.horizontal, 20)
                            // article.css: .folio-header's 28px bottom margin.
                            .padding(.top, 28)
                    }

                    // Only surfaces on a genuinely slow load. Showing it
                    // immediately made every fast open flicker as it vanished.
                    if showSlowIndicator {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Loading article…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 32)
                        .transition(.opacity)
                    }
                }
                // article.css caps the 26rem text measure, then adds 20px
                // padding on either side. Match that outer width on tablets.
                .frame(width: min(geometry.size.width, readerMaxOuterWidth), alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .scrollDisabled(true)
        }
        .background(backgroundColor)
        .task {
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(.easeIn(duration: 0.2)) { showSlowIndicator = true }
        }
    }

    @State private var showSlowIndicator = false

    private var readerMaxOuterWidth: CGFloat { CGFloat(26 * 17 * fontScale + 40) }

    private var displayTitle: String {
        summary.title.replacingOccurrences(of: "_", with: " ")
    }

    /// Keep preview title sizes identical to article.css. Display scaling
    /// follows the reader setting only to 120%, while body text keeps the
    /// full configured scale range.
    private var titleScale: Double { min(max(fontScale, 0.85), 1.2) }
    private var heroTitleSize: Double { 44.2 * titleScale }
    private var textOnlyTitleSize: Double { 40.8 * titleScale }

    /// article.css body: 17px at line-height 1.52. SwiftUI's lineSpacing is
    /// *extra* points on top of the font's natural leading — subtract it, or
    /// the preview text sits visibly tighter than the rendered article and
    /// the cross-fade reads as a jump.
    private var extractLineSpacing: Double {
        let size = 17 * fontScale
        let natural = UIFont(name: "EBGaramond-Regular", size: size)?.lineHeight ?? size * 1.2
        return max(0, size * 1.52 - natural)
    }

    /// The rendered article opens with the subject in bold. Take that span
    /// from the summary's own `extract_html` rather than guessing from the
    /// title, which misses every article whose lead differs from its name.
    private var styledExtract: AttributedString {
        var attributed = AttributedString(summary.extract ?? "")
        guard let lead = summary.leadBoldPhrase,
              let range = attributed.range(of: lead) else { return attributed }
        attributed[range].font = .custom("EBGaramond-Bold", size: 17 * fontScale, relativeTo: .body)
        return attributed
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
        GeometryReader { geo in
            let layout = heroLayout(containerWidth: geo.size.width)
            ZStack(alignment: .bottomLeading) {
                RemoteImage(url: url) { phase in
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
                .frame(width: layout.imageWidth, height: layout.imageHeight)
                .offset(x: layout.offsetX, y: layout.offsetY)
                .frame(width: layout.containerWidth, height: layout.containerHeight, alignment: .topLeading)
                .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.78), .black.opacity(0.40), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 220)
                .allowsHitTesting(false)

                Text(displayTitle)
                    .font(.custom("EBGaramond-Italic", size: heroTitleSize, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 12, y: 1)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .aspectRatio(4 / 3, contentMode: .fit)
    }

    /// Computes a `background-size: cover; background-position: X% Y%` equivalent
    /// for SwiftUI: the image is scaled to fully cover a 4:3 container, then
    /// translated so the focal point lands at the same relative spot the CSS
    /// would place it. Matches `.folio-header` in `article.css` so the WebView
    /// can replace this view without a visible crop jump.
    private func heroLayout(containerWidth: CGFloat) -> HeroLayout {
        let cw = containerWidth
        let ch = cw * 3 / 4
        let containerAspect = cw / ch  // 4/3
        let imageAspect = heroImageAspect ?? containerAspect
        let fx = heroFocalPoint?.x ?? 0.5
        let fy = heroFocalPoint?.y ?? 0.28  // matches CSS default background-position: 50% 28%

        if imageAspect >= containerAspect {
            // Wider than container → match heights, horizontal overflow.
            let h = ch
            let w = h * imageAspect
            let excess = w - cw
            return HeroLayout(
                containerWidth: cw, containerHeight: ch,
                imageWidth: w, imageHeight: h,
                offsetX: -excess * fx, offsetY: 0
            )
        } else {
            // Taller than container → match widths, vertical overflow.
            let w = cw
            let h = w / imageAspect
            let excess = h - ch
            return HeroLayout(
                containerWidth: cw, containerHeight: ch,
                imageWidth: w, imageHeight: h,
                offsetX: 0, offsetY: -excess * fy
            )
        }
    }
}

private struct HeroLayout {
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    let imageWidth: CGFloat
    let imageHeight: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat
}
