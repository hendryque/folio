import SwiftUI

struct SavedArticleRow: View {
    let title: String
    let summary: String?
    let thumbnailURL: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure, .empty:
                    Color(.tertiarySystemFill)
                @unknown default:
                    Color(.tertiarySystemFill)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title.replacingOccurrences(of: "_", with: " "))
                    .font(.custom("EBGaramond-Regular", size: 17, relativeTo: .body))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let summary, !summary.isEmpty {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
