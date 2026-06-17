import SwiftUI
import UIKit

/// Adds a trailing-edge swipe gesture to the host UINavigationController's
/// view, mirror-image of the leading-edge interactive pop. When recognized
/// past a small translation threshold, fires `onForward`.
///
/// Mount via `.background(ForwardGestureEnabler(...))` on each NavigationStack
/// root and on the articleDestination (so the gesture is available both at
/// root and inside an article reader, the same way PopGestureEnabler works).
/// Multiple mountings on the same UINavigationController de-dup themselves —
/// only one screen-edge recognizer is installed per nav controller's view.
struct ForwardGestureEnabler: UIViewControllerRepresentable {
    let onForward: () -> Void
    let isEnabled: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onForward: onForward, isEnabled: isEnabled)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = HostVC()
        vc.coordinator = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {
        context.coordinator.onForward = onForward
        context.coordinator.isEnabled = isEnabled
        context.coordinator.gestureRecognizer?.isEnabled = isEnabled
    }

    final class HostVC: UIViewController {
        weak var coordinator: Coordinator?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            installGesture()
        }

        private func installGesture() {
            guard let coordinator else { return }
            guard let nav = navigationController else { return }
            let existing = nav.view.gestureRecognizers?.first { recognizer in
                guard let edge = recognizer as? UIScreenEdgePanGestureRecognizer else { return false }
                return edge.edges == .right
            } as? UIScreenEdgePanGestureRecognizer
            if let existing {
                // Already installed by a previous mount. Re-point it at this
                // coordinator so the latest onForward closure (per-tab) wins.
                existing.removeTarget(nil, action: nil)
                existing.addTarget(coordinator, action: #selector(Coordinator.handle(_:)))
                coordinator.gestureRecognizer = existing
                existing.isEnabled = coordinator.isEnabled
                return
            }
            let gr = UIScreenEdgePanGestureRecognizer(
                target: coordinator,
                action: #selector(Coordinator.handle(_:))
            )
            gr.edges = .right
            gr.isEnabled = coordinator.isEnabled
            nav.view.addGestureRecognizer(gr)
            coordinator.gestureRecognizer = gr
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var onForward: () -> Void
        var isEnabled: Bool
        weak var gestureRecognizer: UIScreenEdgePanGestureRecognizer?

        init(onForward: @escaping () -> Void, isEnabled: Bool) {
            self.onForward = onForward
            self.isEnabled = isEnabled
        }

        @objc func handle(_ gr: UIScreenEdgePanGestureRecognizer) {
            guard isEnabled else { return }
            guard gr.state == .ended else { return }
            // Require a deliberate swipe past the edge zone — light edge taps
            // shouldn't fire forward.
            let translation = gr.translation(in: gr.view)
            if translation.x < -40 {
                onForward()
            }
        }
    }
}
