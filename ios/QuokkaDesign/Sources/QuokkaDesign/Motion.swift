import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Motion is transform and opacity only, and every duration here is short enough that the
/// interface never makes you wait to see your own library.
public enum Motion {

    /// A tile appearing in the grid. Fast, because saves arrive in bursts after an import.
    public static let arrive = Animation.spring(response: 0.34, dampingFraction: 0.82)

    /// Switching collections. A crossfade with a small scale, no slide -- sliding implies a
    /// spatial relationship between collections that does not exist.
    public static let collectionChange = Animation.easeOut(duration: 0.22)

    /// Press feedback on a card.
    public static let press = Animation.easeOut(duration: 0.12)

    public static let pressedScale: CGFloat = 0.97
    public static let enterScale: CGFloat = 0.98

    /// Reduce Motion is read synchronously here rather than through the SwiftUI environment
    /// so the very first frame is already correct. Reading it in a view means the launch
    /// animation has usually started before the preference is known.
    @MainActor
    public static var reduced: Bool {
        #if canImport(UIKit)
        UIAccessibility.isReduceMotionEnabled
        #else
        false
        #endif
    }

    /// Every animated call site goes through this, so honouring the preference is the default
    /// rather than something each view has to remember.
    @MainActor
    public static func respecting(_ animation: Animation) -> Animation? {
        reduced ? nil : animation
    }
}
