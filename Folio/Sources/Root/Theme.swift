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
    var bodyFontName: String { "EBGaramond-Regular" }
    var bodyBoldFontName: String { "EBGaramond-Bold" }
    var titleFontName: String {
        self == .debug ? "BarlowSemiCondensed-Bold" : "EBGaramond-Italic"
    }
    /// De:Bug sets its headings in the grotesque; every theme sets prose in
    /// the garalde.
    var webFontFamilies: [String] {
        self == .debug ? [BundledFonts.garamond, BundledFonts.barlow] : [BundledFonts.garamond]
    }

    /// Faces the reader waits for before revealing. Gating on these rather than
    /// on `document.fonts.ready` keeps the reveal off the load event, which
    /// waits for every image too.
    var webFontQueries: [String] { BundledFonts.queries(forFamilies: webFontFamilies) }

    /// 18px, not the 17 that was set by eye while New York was really
    /// rendering: EB Garamond's x-height is 0.409em against New York's 0.487,
    /// so the same nominal size reads 18% smaller.
    var bodySize: Double { 18 }

    /// Keeps the interlinear channel a little over one x-height, the principle
    /// in docs/typography.md: channel is line-height minus real ink, 1.085em
    /// for this face, so 1.52 gives 1.06 x-heights.
    var bodyLineHeight: Double { 1.52 }

    /// A cap in rem holds a fixed character count per face, 62.8 here, at any
    /// reader size. Only binds on iPad.
    var measureRem: Double { 26 }
    var heroTitleSize: Double { self == .debug ? 42 : 44.2 }
    var textOnlyTitleSize: Double { self == .debug ? 38 : 40.8 }
}
