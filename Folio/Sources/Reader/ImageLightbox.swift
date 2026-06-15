import SwiftUI

struct IdentifiedURL: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
}

struct ImageLightbox: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            GeometryReader { geometry in
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(combinedGesture)
                            .gesture(swipeDownToDismissGesture)
                    case .failure:
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.white.opacity(0.6))
                            Text("Couldn't load image")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    case .empty:
                        ProgressView()
                            .tint(.white)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .background(Color.black.opacity(0.4), in: Circle())
                    .accessibilityLabel("Close")
            }
            .padding(16)
        }
    }

    private var combinedGesture: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = max(1.0, min(5.0, lastScale * value))
                }
                .onEnded { _ in
                    lastScale = scale
                    if scale < 1.05 {
                        withAnimation(.spring(duration: 0.3)) {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                        }
                    }
                },
            DragGesture()
                .onChanged { value in
                    guard scale > 1.0 else { return }
                    offset = CGSize(
                        width: dragStart.width + value.translation.width,
                        height: dragStart.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    dragStart = offset
                }
        )
    }

    private var swipeDownToDismissGesture: some Gesture {
        DragGesture()
            .onEnded { value in
                guard scale <= 1.05 else { return }
                if value.translation.height > 100 {
                    dismiss()
                }
            }
    }
}
