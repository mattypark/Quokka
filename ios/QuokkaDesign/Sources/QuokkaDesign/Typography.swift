import SwiftUI

/// SF Pro for now, with one seam for the custom face Matthew is choosing.
///
/// `Face.display` is the only place that face will go: screen titles, the hero numbers on the
/// sky, the onboarding headline. Everything a person reads for information -- a transcript, a
/// check's evidence, a caption -- stays SF Pro whatever lands there, because a display face
/// set at 15pt over a paragraph is decoration getting in the way.
///
/// Titles are bold and large, the way Nudgy sets them; everything under a title stays at
/// regular and medium so the hierarchy is carried by size and weight, not by colour.
public enum Face {
    /// PostScript name of the display face, or nil for SF Pro. Set it and the titles change.
    public static let display: String? = nil
}

public enum Type {

    private static func display(_ size: CGFloat, weight: Font.Weight) -> Font {
        if let face = Face.display {
            return .custom(face, size: size, relativeTo: .largeTitle).weight(weight)
        }
        return .system(size: size, weight: weight)
    }

    // MARK: Display

    /// Screen titles -- "Library", "Studio" -- and a video's title on its breakdown.
    public static func screen(_ size: CGFloat = 32) -> Font { display(size, weight: .bold) }

    /// Big numbers: the counts on the sky, a pace, a score.
    public static func numeral(_ size: CGFloat) -> Font {
        display(size, weight: .semibold).monospacedDigit()
    }

    /// The onboarding headline. Large and tight, never more than two lines.
    public static let headline = display(36, weight: .bold)
    public static let headlineTracking: CGFloat = -0.8

    /// Section titles and card titles.
    public static func title(_ size: CGFloat = 20) -> Font { display(size, weight: .bold) }

    // MARK: Navigation and controls

    public static let nav = Font.system(size: 15, weight: .medium)
    public static let navTracking: CGFloat = -0.2
    public static let control = Font.system(size: 16, weight: .semibold)
    public static let field = Font.system(size: 16, weight: .regular)

    // MARK: Reading

    public static let body = Font.system(size: 16, weight: .regular)
    public static let bodyEmphasis = Font.system(size: 16, weight: .semibold)
    public static let caption = Font.system(size: 13, weight: .regular)
    public static let captionEmphasis = Font.system(size: 13, weight: .semibold)

    /// Uppercase tracked labels over a group of cards: "READY TO BREAK DOWN".
    public static let section = Font.system(size: 12, weight: .semibold)
    public static let sectionTracking: CGFloat = 1.1

    /// Count badges -- the outlined "2.1K" beside a tab title.
    public static let badge = Font.system(size: 11, weight: .semibold).monospacedDigit()

    /// A person's name, a playlist's name.
    public static let name = Font.system(size: 20, weight: .semibold)

    /// The centered title over a playlist or a creator.
    public static let screenTitle = display(24, weight: .bold)

    /// The typographic tile, for the platforms that never yield a thumbnail.
    public static func tileTitle(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold)
    }

    /// Timestamps, counts, hosts. Tabular figures so a column of them does not shimmer.
    public static func meta(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium).monospacedDigit()
    }
}
