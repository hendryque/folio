import SwiftUI

enum Theme: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case sepia
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "Auto"
        case .light: "Light"
        case .sepia: "Sepia"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light, .sepia: .light
        case .dark: .dark
        }
    }

    /// The `data-theme` attribute value the article CSS branches on.
    var cssDataTheme: String {
        switch self {
        case .system, .light: "light"
        case .sepia: "sepia"
        case .dark: "dark"
        }
    }
}
