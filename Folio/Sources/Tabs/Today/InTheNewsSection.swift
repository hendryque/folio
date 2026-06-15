import SwiftUI

struct InTheNewsSection: View {
    let items: [NewsItem]
    let language: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(label: "In the News")

            VStack(spacing: 0) {
                ForEach(Array(items.prefix(6).enumerated()), id: \.element.id) { index, item in
                    InTheNewsRow(item: item, language: language)
                    if index < min(items.count, 6) - 1 {
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

private struct InTheNewsRow: View {
    let item: NewsItem
    let language: String

    var body: some View {
        Group {
            if let primary = item.links.first {
                NavigationLink(value: ArticleDestination(title: primary.title, language: language)) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        Text(item.story.strippingHTMLTags)
            .font(.callout)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
    }
}

extension String {
    var strippingHTMLTags: String {
        let withoutTags = replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        return withoutTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}
