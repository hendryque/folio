import SwiftUI

struct TableOfContentsDrawer: View {
    let sections: [ArticleSection]
    let onTap: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if sections.isEmpty {
                    ContentUnavailableView(
                        "No sections",
                        systemImage: "list.bullet",
                        description: Text("This article doesn't have section headings.")
                    )
                } else {
                    List(sections) { section in
                        Button {
                            onTap(section.anchor)
                            dismiss()
                        } label: {
                            HStack {
                                Text(section.title)
                                    .font(.custom("EBGaramond-Regular", size: fontSize(for: section.level), relativeTo: .body))
                                    .foregroundStyle(.primary)
                                    .padding(.leading, indent(for: section.level))
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Contents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func fontSize(for level: Int) -> CGFloat {
        switch level {
        case 2: 17
        case 3: 15
        default: 14
        }
    }

    private func indent(for level: Int) -> CGFloat {
        max(0, CGFloat(level - 2) * 12)
    }
}
