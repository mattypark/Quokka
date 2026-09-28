import SwiftUI

/// A 4pt base with a deliberate jump from 8 to 12: gaps below 12 read as "these belong to
/// the same object", gaps at or above 12 read as "these are separate objects". Interfaces
/// blur when that boundary is fuzzy, so there is no 10.
public enum Space {
    public static let hair: CGFloat = 2
    public static let tight: CGFloat = 4
    public static let snug: CGFloat = 8
    public static let base: CGFloat = 12
    public static let roomy: CGFloat = 16
    public static let loose: CGFloat = 24
    public static let section: CGFloat = 40
    public static let chapter: CGFloat = 64
}

public enum Radius {
    /// Grid tiles. Very nearly square.
    ///
    /// Cosmos's desktop grid is 0 and its phone grid is about 2pt. A generous radius reads as
    /// objects you can pick up, which is a Pinterest note; nearly square reads as a contact
    /// sheet, which is the one a creative-direction library wants -- the frame of the saved
    /// image is part of what was saved.
    public static let tile: CGFloat = 2
    /// Playlist covers, which are objects rather than frames. Cosmos's cluster cards sit here.
    public static let cover: CGFloat = 18
    public static let control: CGFloat = 12
    public static let sheet: CGFloat = 24
    public static let pill: CGFloat = 999
}

public enum Grid {
    /// The gap between tiles, and the inset from the screen edge.
    ///
    /// Equal on both, which is what makes a masonry grid read as one field of objects rather
    /// than as a boxed-in table. Measured off Cosmos's phone screenshots at 12pt, which lands
    /// on `Space.base` exactly.
    public static let gutter: CGFloat = Space.base
    public static let margin: CGFloat = Space.base
    /// Home and playlists.
    public static let columns = 2
    /// The profile's Saves tab, which is an overview rather than a feed.
    public static let columnsWide = 3
    /// Room left at the bottom of a scroll so the last row clears the tab bar.
    public static let bottomInset: CGFloat = 96
}

public enum Stroke {
    public static let hairline: CGFloat = 1.0 / 3.0
    public static let thin: CGFloat = 0.5
    public static let regular: CGFloat = 1
    /// The underline under the active profile tab.
    public static let underline: CGFloat = 2
}

public enum Control {
    /// Grey-filled circle buttons: back, search, more.
    public static let circle: CGFloat = 40
    /// Filled pills.
    public static let pillHeight: CGFloat = 44
    /// The search pill.
    public static let fieldHeight: CGFloat = 52
}
