import SwiftUI

enum Theme: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case sepia
    case dark
    case debug

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "Auto"
        case .light: "Light"
        case .sepia: "Sepia"
        case .dark: "Dark"
        case .debug: "De:Bug"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light, .sepia, .debug: .light
        case .dark: .dark
        }
    }

    /// The `data-theme` attribute value the article CSS branches on.
    var cssDataTheme: String {
        switch self {
        case .system, .light: "light"
        case .sepia: "sepia"
        case .dark: "dark"
        case .debug: "debug"
        }
    }

    /// SF Symbol for the reader's theme-cycle button.
    var iconName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .sepia: "book"
        case .dark: "moon"
        case .debug: "ant"
        }
    }

    /// The page ground, single-sourced: preview, TOC drawer and gallery all
    /// mirror the reader and every theme used to be pasted into each.
    var paper: Color {
        switch self {
        case .system, .light: Color(.systemBackground)
        case .sepia: Color(red: 0.957, green: 0.926, blue: 0.847)
        case .dark: Color(red: 0.102, green: 0.102, blue: 0.110)
        case .debug: Color(red: 0.910, green: 0.898, blue: 0.871)
        }
    }

    /// Reader faces and metrics, mirrored by ArticleLoadingPreview. A theme
    /// may swap the display face, so the numbers travel with it.
    var bodyFontName: String { self == .debug ? "Besley-Regular" : "EBGaramond-Regular" }
    var bodyBoldFontName: String { self == .debug ? "Besley-Bold" : "EBGaramond-Bold" }
    var titleFontName: String {
        self == .debug ? "BarlowSemiCondensed-Bold" : "EBGaramond-Italic"
    }
    /// De:Bug is a costume: Besley for prose standing in for Sentinel, Barlow
    /// for display standing in for Fakt. Every other theme sets the garalde.
    var webFontFamilies: [String] {
        self == .debug ? [BundledFonts.besley, BundledFonts.barlow] : [BundledFonts.garamond]
    }

    /// Faces the reader waits for before revealing. Gating on these rather than
    /// on `document.fonts.ready` keeps the reveal off the load event, which
    /// waits for every image too.
    var webFontQueries: [String] { BundledFonts.queries(forFamilies: webFontFamilies) }

    /// Sized by x-height, not by nominal px, so themes read the same size:
    /// Garamond's is 0.409em against Besley's 0.520, so 14px of the slab
    /// matches 18px of the garalde.
    var bodySize: Double { self == .debug ? 14 : 18 }

    /// Set so the interlinear channel lands a little over one x-height, the
    /// principle in docs/typography.md. Besley needs more because its ink is
    /// 1.204em deep against Garamond's 1.085em.
    var bodyLineHeight: Double { self == .debug ? 1.75 : 1.52 }

    /// The cap in rem holds a fixed character count per face, so the wider
    /// slab needs a wider one to reach the same measure. Only binds on iPad.
    var measureRem: Double { self == .debug ? 34 : 26 }
    var heroTitleSize: Double { self == .debug ? 42 : 44.2 }
    var textOnlyTitleSize: Double { self == .debug ? 38 : 40.8 }
}
