import UIKit

/// Restore UIKit's interactive pop (swipe-from-leading-edge → back) on every
/// NavigationStack push, regardless of whether the source view hid its nav bar.
///
/// SwiftUI's NavigationStack wraps a UINavigationController, but applying
/// `.toolbar(.hidden, for: .navigationBar)` to a root view causes UIKit to set
/// `setNavigationBarHidden(true)`, which clears the recognizer's delegate and
/// disables the gesture for the whole stack. Forcing the delegate back keeps
/// the gesture alive any time we have something to pop.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
