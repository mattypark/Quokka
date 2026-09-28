import SwiftUI

/// One face: SF Pro.
///
/// Cosmos sets everything in a single neutral grotesk (ABC Oracle, a paid Dinamo licence)
/// and lets the saved images be the only expressive thing on screen. SF Pro is the closest
/// neutral grotesk that ships with the OS, so it costs no licence, no bundle bytes and no
/// fallback path -- and a library that is all pictures does not need a second voice.
///
/// Weights stay at regular and medium. Cosmos never goes bolder than 500, which is most of
/// why its chrome recedes behind the grid.
public enum Type {

    // MARK: Navigation and controls

    /// Top-bar tabs and the profile tab row. 15 medium with Cosmos's tightened tracking.
    public static let nav = Font.system(size: 15, weight: .medium)
    public static let navTracking: CGFloat = -0.28

    /// Buttons and pills.
    public static let control = Font.system(size: 15, weight: .medium)

    /// Placeholder and typed text in the search pill.
    public static let field = Font.system(size: 15, weight: .regular)

    // MARK: Reading

    public static let body = Font.system(size: 16, weight: .regular)
    public static let bodyEmphasis = Font.system(size: 16, weight: .medium)
    public static let caption = Font.system(size: 13, weight: .regular)

    /// Count badges -- the outlined "2.1K" beside a tab title.
    public static let badge = Font.system(size: 11, weight: .medium).monospacedDigit()

    // MARK: Titles

    /// The onboarding headline. Large and tight, never more than two lines.
    public static let headline = Font.system(size: 34, weight: .medium)
    public static let headlineTracking: CGFloat = -0.8

    /// A person's name on their profile.
    public static let name = Font.system(size: 20, weight: .medium)

    /// The centered title over a playlist or an item.
    public static let screenTitle = Font.system(size: 22, weight: .medium)

    /// Section titles and sheet titles. Sized per call site, always medium.
    public static func title(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .medium)
    }

    /// The typographic tile, for the platforms that never yield a thumbnail. With no image,
    /// the author's name at size is the tile.
    public static func tileTitle(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .medium)
    }

    /// Counts, dates, hosts. Tabular figures so a column of counts does not shimmer as it
    /// changes, which was the only thing the monospace face was ever doing.
    public static func meta(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular).monospacedDigit()
    }
}
