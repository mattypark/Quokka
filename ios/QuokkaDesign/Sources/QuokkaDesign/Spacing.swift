import SwiftUI

/// A 4pt base with a deliberate jump from 8 to 12: gaps below 12 read as "these belong to
/// the same object", gaps at or above 12 read as "these are separate objects".
public enum Space {
    public static let hair: CGFloat = 2
    public static let tight: CGFloat = 4
    public static let snug: CGFloat = 8
    public static let base: CGFloat = 12
    public static let roomy: CGFloat = 16
    /// The side gutter of every screen.
    public static let gutter: CGFloat = 20
    public static let loose: CGFloat = 24
    public static let section: CGFloat = 40
    public static let chapter: CGFloat = 64
}

public enum Radius {
    /// Grid tiles. Rounded enough to read as objects, small enough that a grid of them is
    /// still a grid of pictures rather than a stack of buttons.
    public static let tile: CGFloat = 10
    /// Playlist covers and thumbnails inside cards.
    public static let cover: CGFloat = 16
    public static let control: CGFloat = 14
    /// White cards on the paper.
    public static let card: CGFloat = 22
    public static let sheet: CGFloat = 28
    /// The sky header's bottom corners -- Nudgy's 40, a touch tighter.
    public static let header: CGFloat = 36
    public static let pill: CGFloat = 999
}

public enum Grid {
    public static let gutter: CGFloat = 8
    public static let margin: CGFloat = 12
    public static let columns = 2
    public static let columnsWide = 3
    /// Room left at the bottom of a scroll so the last row clears the tab bar.
    public static let bottomInset: CGFloat = 110
}

public enum Stroke {
    public static let hairline: CGFloat = 1.0 / 3.0
    public static let thin: CGFloat = 0.5
    public static let regular: CGFloat = 1
    public static let underline: CGFloat = 2
}

public enum Control {
    public static let circle: CGFloat = 40
    public static let pillHeight: CGFloat = 52
    public static let fieldHeight: CGFloat = 48
}
