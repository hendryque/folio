import SwiftUI

struct TopHeader: View {
    @Binding var searchText: String
    @Binding var selectedTab: ContentView.Tab
    @FocusState.Binding var searchFocused: Bool

    let language: String
    let onLogoTap: () -> Void
    let onLanguageToggle: () -> Void
    let onRandomTap: () -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button(action: onLogoTap) {
                    FolioLogo()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Home")

                SearchBar(text: $searchText, focused: $searchFocused)

                Button(action: onRandomTap) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
                .accessibilityLabel("Random article")

                Button(action: onLanguageToggle) {
                    Text(language.uppercased())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(minWidth: 28)
                        .padding(.vertical, 6)
                }
                .accessibilityLabel("Language: \(language.uppercased()). Tap to toggle.")

                Button(action: onSettingsTap) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Settings")
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)

            TabIconRow(selectedTab: $selectedTab)
        }
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
        }
    }
}

private struct FolioLogo: View {
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text("F")
                .font(.custom("EBGaramond-BoldItalic", size: 22, relativeTo: .title3))
                .foregroundStyle(Color.accentColor)
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 14, height: 1.5)
        }
    }
}

private struct SearchBar: View {
    @Binding var text: String
    @FocusState.Binding var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            TextField("Search Wikipedia", text: $text)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .focused($focused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !text.isEmpty {
                Button {
                    text = ""
                    focused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }
}

private struct TabIconRow: View {
    @Binding var selectedTab: ContentView.Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ContentView.Tab.allCases, id: \.self) { tab in
                TabIconButton(tab: tab, isSelected: selectedTab == tab) {
                    if selectedTab != tab {
                        selectedTab = tab
                    }
                }
            }
        }
    }
}

private struct TabIconButton: View {
    let tab: ContentView.Tab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(height: 2)
                    .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
