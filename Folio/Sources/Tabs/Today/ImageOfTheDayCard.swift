import SwiftUI

struct ImageOfTheDayCard: View {
    let picture: PictureOfTheDay

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let url = picture.image?.source ?? picture.thumbnail?.source {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure, .empty:
                        Color(.tertiarySystemFill)
                            .frame(height: 240)
                    @unknown default:
                        Color(.tertiarySystemFill)
                            .frame(height: 240)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Picture of the Day")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                    .textCase(.uppercase)
                    .tracking(0.8)
                if let caption = picture.description?.text {
                    Text(caption)
                        .font(.callout)
                        .foregroundStyle(.primary)
                }
                if let credit = picture.credit?.text {
                    Text(credit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }
}
