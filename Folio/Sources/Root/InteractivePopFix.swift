import SwiftUI
import UIKit

/// Restores UIKit's interactive pop (swipe-from-leading-edge → back) for a
/// NavigationStack whose views apply `.toolbar(.hidden, for: .navigationBar)`.
///
/// SwiftUI's NavigationStack wraps a UINavigationController. Hiding the nav bar
/// causes UIKit to set `setNavigationBarHidden(true)`, which clears the
/// recognizer's delegate and disables the gesture. Worse, this happens *every*
/// time a hidden-bar view appears — so installing the delegate once at the
/// NavigationStack root isn't enough: a push to a destination view that also
/// hides the bar clobbers it again.
///
/// Mount this view via `.background(PopGestureEnabler())` on every view in a
/// nav stack that hides the toolbar — root *and* destinations. The embedded
/// UIViewController re-installs the delegate on `viewWillAppear`, so each
/// appearance restores the gesture after UIKit's reset.
///
/// Scoped: only views we mount it on are affected. Earlier we extended
/// `UINavigationController.viewDidLoad` globally, which worked thanks to ObjC
/// dispatch but isn't a sanctioned Swift pattern and touched every framework-
/// internal nav controller in the process.
struct PopGestureEnabler: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = HostVC()
        vc.coordinator = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {}

    final class HostVC: UIViewController {
        weak var coordinator: Coordinator?

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            installDelegate()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            // Belt-and-suspenders: setNavigationBarHidden can fire after
            // viewWillAppear, between viewWillAppear and viewDidAppear. Re-set
            // once we're definitely visible.
            installDelegate()
        }

        private func installDelegate() {
            guard let coordinator else { return }
            guard let nav = navigationController else { return }
            coordinator.nav = nav
            if nav.interactivePopGestureRecognizer?.delegate !== coordinator {
                nav.interactivePopGestureRecognizer?.delegate = coordinator
            }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var nav: UINavigationController?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (nav?.viewControllers.count ?? 0) > 1
        }
    }
}
