import SwiftUI
import UIKit

/// Restores UIKit's interactive pop (swipe-from-leading-edge → back) for a
/// NavigationStack whose root applies `.toolbar(.hidden, for: .navigationBar)`.
///
/// SwiftUI's NavigationStack wraps a UINavigationController, and hiding the nav
/// bar causes UIKit to set `setNavigationBarHidden(true)`, which clears the
/// recognizer's delegate and disables the gesture for the whole stack.
/// Embedding this view at the root of a NavigationStack walks up to the host
/// UINavigationController and installs a delegate that allows the gesture
/// whenever there's anything to pop.
///
/// Scoped: only our NavigationStacks get the fix. Earlier we extended
/// `UINavigationController` to override `viewDidLoad` globally, which works
/// only thanks to ObjC dispatch and isn't a sanctioned Swift pattern — it also
/// touched every framework-internal nav controller in the process. This
/// version touches exactly the nav stacks we mount.
struct PopGestureEnabler: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {
        DispatchQueue.main.async {
            guard let nav = vc.navigationController else { return }
            if nav.interactivePopGestureRecognizer?.delegate !== context.coordinator {
                context.coordinator.nav = nav
                nav.interactivePopGestureRecognizer?.delegate = context.coordinator
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
