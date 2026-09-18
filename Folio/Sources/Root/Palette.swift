import SwiftUI

/// A theme's colours, declared once. SwiftUI reads them as `Color`, the reader
/// gets the same values injected as CSS custom properties, so the chrome and
/// the article ground cannot disagree.
struct Palette: Sendable {
    /// The article ground, and the app's ground behind everything.
    let background: UInt32
    let foreground: UInt32
    let secondary: UInt32
    let link: UInt32
    let accent: UInt32
    /// Bars, cards and infoboxes: a tone off the ground so a surface sitting on
    /// the page still reads as its own.
    let card: UInt32

    /// Alpha-carrying tones stay as literals because they sit over whatever is
    /// beneath them rather than being a colour in their own right.
    let linkUnderline: String
    let divider: String
    let codeBackground: String

    var backgroundColor: Color { Color(rgb: background) }
    var foregroundColor: Color { Color(rgb: foreground) }
    var secondaryColor: Color { Color(rgb: secondary) }
    var accentColor: Color { Color(rgb: accent) }
    var cardColor: Color { Color(rgb: card) }

    /// The `:root` block the theme stylesheets used to carry.
    var cssVariables: String {
        [
            "--folio-bg: \(Self.hex(background))",
            "--folio-fg: \(Self.hex(foreground))",
            "--folio-secondary: \(Self.hex(secondary))",
            "--folio-link: \(Self.hex(link))",
            "--folio-link-underline: \(linkUnderline)",
            "--folio-divider: \(divider)",
            "--folio-accent: \(Self.hex(accent))",
            "--folio-card-bg: \(Self.hex(card))",
            "--folio-code-bg: \(codeBackground)"
        ].joined(separator: "; ") + ";"
    }

    private static func hex(_ value: UInt32) -> String {
        String(format: "#%06x", value)
    }
}

extension Color {
    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

extension Palette {
    static let light = Palette(
        background: 0xffffff,
        foreground: 0x181818,
        secondary: 0x6b6b6b,
        link: 0xd85220,
        accent: 0xe55530,
        card: 0xfaf5ee,
        linkUnderline: "rgba(216, 82, 32, 0.4)",
        divider: "rgba(0, 0, 0, 0.08)",
        codeBackground: "rgba(0, 0, 0, 0.045)"
    )

    static let sepia = Palette(
        background: 0xf4ecd8,
        foreground: 0x3d2f1d,
        secondary: 0x76614a,
        link: 0xb5391d,
        accent: 0xc4421e,
        card: 0xefe5cb,
        linkUnderline: "rgba(181, 57, 29, 0.45)",
        divider: "rgba(61, 47, 29, 0.16)",
        codeBackground: "rgba(61, 47, 29, 0.075)"
    )

    static let dark = Palette(
        background: 0x1a1a1c,
        foreground: 0xe8e8ea,
        secondary: 0x9a9a9c,
        link: 0xff8556,
        accent: 0xff8556,
        card: 0x2a2a2c,
        linkUnderline: "rgba(255, 133, 86, 0.45)",
        divider: "rgba(255, 255, 255, 0.1)",
        codeBackground: "rgba(255, 255, 255, 0.07)"
    )

    /// De:Bug: newsprint ground, one spot colour carrying links and accent.
    static let debug = Palette(
        background: 0xe8e5de,
        foreground: 0x1c1b19,
        secondary: 0x6b6862,
        link: 0xc9006b,
        accent: 0xc9006b,
        card: 0xefede6,
        linkUnderline: "rgba(201, 0, 107, 0.4)",
        divider: "rgba(28, 27, 25, 0.16)",
        codeBackground: "rgba(28, 27, 25, 0.06)"
    )
}
