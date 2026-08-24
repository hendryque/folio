import SwiftUI

struct TableOfContentsDrawer: View {
    let articleTitle: String
    let thumbnailURL: URL?
    let sections: [ArticleSection]
    let activeAnchor: String?
    let theme: Theme
    let onTap: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if sections.isEmpty {
                ContentUnavailableView(
                    "No sections",
                    systemImage: "list.bullet",
                    description: Text("This article doesn't have section headings.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // First row: the article title itself — tap to scroll to top
                        TOCRow(
                            title: articleTitle,
                            level: 1,
                            isActive: activeAnchor == nil,
                            isTitleRow: true,
                            onTap: {
                                onTap("_top")
                                dismiss()
                            }
                        )
                        Divider()
                            .padding(.leading, 20)

                        ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                            TOCRow(
                                title: section.title,
                                level: section.level,
                                isActive: section.anchor == activeAnchor,
                                isTitleRow: false,
                                onTap: {
                                    onTap(section.anchor)
                                    dismiss()
                                }
                            )
                            if index < sections.count - 1 {
                                Divider()
                                    .padding(.leading, 20)
                            }
                        }
                    }
                }
            }
        }
        .background(themeBackground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack(spacing: 12) {
            RemoteImage(url: thumbnailURL?.wikimediaResized(to: ThumbnailWidth.row)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure, .empty:
                    Color(.tertiarySystemFill)
                @unknown default:
                    Color(.tertiarySystemFill)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(.separator).opacity(0.4), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(articleTitle)
                    .font(.custom("EBGaramond-Italic", size: 22, relativeTo: .title2))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text("TABLE OF CONTENTS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    private var themeBackground: Color {
        switch theme {
        case .sepia: Color(red: 0.957, green: 0.926, blue: 0.847)
        case .dark: Color(red: 0.102, green: 0.102, blue: 0.110)
        default: Color(.systemBackground)
        }
    }
}

private struct TOCRow: View {
    let title: String
    let level: Int
    let isActive: Bool
    let isTitleRow: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Text(title)
                    .font(.custom("EBGaramond-Regular", size: fontSize, relativeTo: .body))
                    .fontWeight(isActive ? .bold : .regular)
                    .foregroundStyle(textColor)
                    .padding(.leading, leadingIndent)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
            }
            .padding(.vertical, 14)
            .padding(.trailing, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var fontSize: CGFloat {
        switch level {
        case 1: 18     // article title row
        case 2: 17
        case 3: 16
        default: 15
        }
    }

    private var leadingIndent: CGFloat {
        if isTitleRow { return 20 }
        // H2: 20pt baseline; H3+: progressively indented
        return 20 + CGFloat(max(0, level - 2)) * 16
    }

    private var textColor: Color {
        if isTitleRow { return Color.accentColor }
        return .primary
    }
}
