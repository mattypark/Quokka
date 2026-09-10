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
    /// Tiles.
    ///
    /// Generous on purpose. A small radius reads as a contact sheet -- documents pinned to a
    /// board -- and a large one reads as objects you can pick up. Pinterest and Cosmos both
    /// sit here, and it is most of why their grids feel handled rather than filed.
    public static let card: CGFloat = 16
    public static let control: CGFloat = 12
    public static let sheet: CGFloat = 24
    public static let pill: CGFloat = 999
}

public enum Grid {
    /// The gap between tiles, and the inset from the screen edge.
    ///
    /// Equal on both, which is what makes a masonry grid read as one field of objects rather
    /// than as a boxed-in table. The grid runs to the edges of the screen and scrolls under
    /// the floating chrome.
    public static let gutter: CGFloat = 8
    public static let margin: CGFloat = 8
    public static let columns = 2
    public static let columnsWide = 3
    /// Room left at the bottom of a scroll so the last row clears the tab bar.
    public static let bottomInset: CGFloat = 96
}

public enum Stroke {
    public static let hairline: CGFloat = 1.0 / 3.0
    public static let thin: CGFloat = 0.5
    public static let regular: CGFloat = 1
}
