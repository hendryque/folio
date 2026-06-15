import SwiftUI

struct OnThisDaySection: View {
    let items: [OnThisDayItem]
    let language: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(label: "On This Day")

            VStack(spacing: 0) {
                ForEach(Array(items.prefix(5).enumerated()), id: \.element.id) { index, item in
                    OnThisDayRow(item: item, language: language)
                    if index < min(items.count, 5) - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 1)
        }
    }
}

private struct OnThisDayRow: View {
    let item: OnThisDayItem
    let language: String

    var body: some View {
        Group {
            if let primary = item.pages?.first {
                NavigationLink(value: ArticleDestination(title: primary.title, language: language)) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            if let year = item.year {
                Text(verbatim: String(year))
                    .font(.custom("EBGaramond-Regular", size: 18, relativeTo: .body))
                    .foregroundStyle(.tint)
                    .frame(width: 56, alignment: .leading)
            }
            Text(item.text)
                .font(.callout)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
