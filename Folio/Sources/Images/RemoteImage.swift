import SwiftUI

/// Drop-in AsyncImage replacement backed by ImageLoader: shared decoded-bitmap
/// memory cache, real disk cache, request coalescing, and off-main decoding.
/// Same phase-based API as AsyncImage so call sites keep their switch
/// statements. A memory-cache hit renders on the very first frame — no
/// placeholder flash when scrolling back to previously seen images.
struct RemoteImage<Content: View>: View {
    private let url: URL?
    private let maxPixelSize: CGFloat?
    private let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase
    @State private var loadedURL: URL?

    init(
        url: URL?,
        maxPixelSize: CGFloat? = nil,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.content = content
        if let url, let hit = ImageLoader.cached(url, maxPixelSize: maxPixelSize) {
            _phase = State(initialValue: .success(Image(uiImage: hit)))
            _loadedURL = State(initialValue: url)
        } else {
            _phase = State(initialValue: .empty)
            _loadedURL = State(initialValue: nil)
        }
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                guard let url else {
                    phase = .empty
                    loadedURL = nil
                    return
                }
                if loadedURL == url, case .success = phase { return }
                if let hit = ImageLoader.cached(url, maxPixelSize: maxPixelSize) {
                    phase = .success(Image(uiImage: hit))
                    loadedURL = url
                    return
                }
                // Reset so a changed URL never keeps showing the old image.
                phase = .empty
                loadedURL = nil
                let image = await ImageLoader.shared.image(for: url, maxPixelSize: maxPixelSize)
                // A cancelled task belongs to a previous URL; its result,
                // success or failure, must not land on the current one.
                guard !Task.isCancelled else { return }
                if let image {
                    phase = .success(Image(uiImage: image))
                    loadedURL = url
                } else {
                    phase = .failure(URLError(.cannotLoadFromNetwork))
                }
            }
    }
}
