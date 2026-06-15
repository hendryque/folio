import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]
    @Query private var history: [HistoryEntry]

    var body: some View {
        NavigationStack {
            Form {
                Section("Wikipedia") {
                    Picker("Default language", selection: languageBinding) {
                        Text("English").tag("en")
                        Text("Deutsch").tag("de")
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        ThemePickerRow(selection: themeEnumBinding)
                        Text(themeDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                            .id(currentTheme)
                    }
                    .padding(.vertical, 4)

                    HStack {
                        Text("Font size")
                        Spacer()
                        Slider(
                            value: fontScaleBinding,
                            in: 0.85...1.6,
                            step: 0.05
                        ) {
                            Text("Font size")
                        } minimumValueLabel: {
                            Text("A").font(.caption)
                        } maximumValueLabel: {
                            Text("A").font(.title3)
                        }
                        .frame(width: 200)
                    }
                } header: {
                    Text("Appearance")
                }

                Section("Reading history") {
                    Button(role: .destructive) {
                        clearHistory()
                    } label: {
                        Text("Clear history (\(history.count))")
                    }
                    .disabled(history.isEmpty)
                }

                Section("About") {
                    NavigationLink("About Folio") {
                        AboutView()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var settings: AppSettings? { settingsList.first }
    private var currentTheme: Theme {
        Theme(rawValue: settings?.theme ?? Theme.system.rawValue) ?? .system
    }

    private var themeDescription: String {
        switch currentTheme {
        case .system: "Folio follows your iPhone's appearance setting — light during the day, dark at night."
        case .light: "Pure white background. Maximum contrast for daytime reading."
        case .sepia: "Warm parchment background. Easier on the eyes for long sessions."
        case .dark: "Dim background. Best for low-light and night reading."
        }
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { settings?.defaultLanguage ?? "en" },
            set: { newValue in
                settings?.defaultLanguage = newValue
                try? modelContext.save()
            }
        )
    }

    private var themeEnumBinding: Binding<Theme> {
        Binding(
            get: { currentTheme },
            set: { newValue in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    settings?.theme = newValue.rawValue
                }
                try? modelContext.save()
            }
        )
    }

    private var fontScaleBinding: Binding<Double> {
        Binding(
            get: { settings?.fontScale ?? 1.0 },
            set: { newValue in
                settings?.fontScale = newValue
                try? modelContext.save()
            }
        )
    }

    private func clearHistory() {
        for entry in history {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }
}

// MARK: - Theme picker

private struct ThemePickerRow: View {
    @Binding var selection: Theme

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Theme.allCases) { theme in
                ThemeCard(theme: theme, isSelected: selection == theme) {
                    if selection != theme {
                        selection = theme
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct ThemeCard: View {
    let theme: Theme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ThemePreview(theme: theme)
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                isSelected ? Color.accentColor : Color(.separator),
                                lineWidth: isSelected ? 2.5 : 0.5
                            )
                    }
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .padding(4)
                        }
                    }

                Text(theme.displayName)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Theme: \(theme.displayName)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ThemePreview: View {
    let theme: Theme

    var body: some View {
        Group {
            switch theme {
            case .system:
                HStack(spacing: 0) {
                    ThemeMockup(palette: .light)
                    ThemeMockup(palette: .dark)
                }
            case .light:
                ThemeMockup(palette: .light)
            case .sepia:
                ThemeMockup(palette: .sepia)
            case .dark:
                ThemeMockup(palette: .dark)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ThemeMockup: View {
    let palette: ThemePalette

    var body: some View {
        ZStack {
            palette.bg
            VStack(alignment: .leading, spacing: 3) {
                Capsule().fill(palette.fg)
                    .frame(width: 30, height: 4)
                Capsule().fill(palette.fg.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(height: 2)
                Capsule().fill(palette.fg.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(height: 2)
                Capsule().fill(palette.accent)
                    .frame(width: 22, height: 2)
                Capsule().fill(palette.fg.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(height: 2)
                Capsule().fill(palette.fg.opacity(0.55))
                    .frame(width: 36, height: 2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
    }
}

private struct ThemePalette {
    let bg: Color
    let fg: Color
    let accent: Color

    static let light = ThemePalette(
        bg: Color(red: 1.0, green: 1.0, blue: 1.0),
        fg: Color(red: 0.10, green: 0.10, blue: 0.10),
        accent: Color(red: 0.85, green: 0.32, blue: 0.13)
    )
    static let sepia = ThemePalette(
        bg: Color(red: 0.957, green: 0.926, blue: 0.847),
        fg: Color(red: 0.24, green: 0.18, blue: 0.11),
        accent: Color(red: 0.71, green: 0.22, blue: 0.11)
    )
    static let dark = ThemePalette(
        bg: Color(red: 0.102, green: 0.102, blue: 0.110),
        fg: Color(red: 0.91, green: 0.91, blue: 0.92),
        accent: Color(red: 1.0, green: 0.52, blue: 0.34)
    )
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        List {
            Section {
                LabeledContent("Name", value: "Folio")
                LabeledContent("Version", value: appVersion)
                LabeledContent("Built on", value: "Wikipedia REST API")
            }
            Section("Credits") {
                Text("Folio is a personal reader for Wikipedia, inspired by V for Wikipedia (Raureif, 2016) by Frank Rausch. Typographizer logic adapted from the Raureif/Typographizer project (MIT).")
                    .font(.callout)
                Text("Typography is set in EB Garamond by Georg Mayr-Duffner & Octavio Pardo (SIL Open Font License).")
                    .font(.callout)
            }
            Section("Source") {
                Text("Wikipedia content is licensed under CC BY-SA 4.0.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
    }
}

// MARK: - Reusable toolbar modifier (unused now that the gear lives in the top header)

struct SettingsToolbarModifier: ViewModifier {
    @State private var showSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .accessibilityLabel("Settings")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
    }
}

extension View {
    func withSettingsToolbar() -> some View {
        modifier(SettingsToolbarModifier())
    }
}
