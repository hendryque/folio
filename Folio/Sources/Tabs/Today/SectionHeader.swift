import SwiftUI

struct SectionHeader: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.8)
            .padding(.leading, 4)
    }
}
