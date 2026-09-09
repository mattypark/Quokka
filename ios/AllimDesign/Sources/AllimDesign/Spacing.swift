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
    /// Cards. Deliberately small: a heavy corner radius reads as friendly-app, and the grid
    /// is meant to read as a contact sheet.
    public static let card: CGFloat = 6
    public static let control: CGFloat = 8
    public static let pill: CGFloat = 999
}

public enum Grid {
    /// The gutter between masonry tiles. Narrow on purpose -- tiles are the only colour on a
    /// black field, so they need to sit close enough to read as one surface.
    public static let gutter: CGFloat = 3
    public static let columns = 2
    public static let columnsWide = 3
}

public enum Stroke {
    public static let hairline: CGFloat = 1.0 / 3.0
    public static let thin: CGFloat = 0.5
    public static let regular: CGFloat = 1
}
