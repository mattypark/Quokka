import SwiftUI

/// Two faces (Matthew, 2026-09-30: "we're using Schoolbell and SF Pro").
///
/// - **Schoolbell**, hand-drawn, for the lines with a voice: screen titles, the onboarding
///   headline, the date on the sky, what the mark says on an empty screen, the verdict at the top
///   of a breakdown. The way Nudgy uses its hand for everything Mushy says.
/// - **SF Pro** for everything read for information -- transcripts, a check's evidence, counts,
///   captions, controls -- and for every number, where even-width digits matter and a hand-drawn
///   "7" next to a "1" reads as sloppy rather than warm.
///
/// Titles are big; everything under them stays at regular and semibold so the hierarchy is
/// carried by size and face, not by colour.
public enum Face {
    /// Schoolbell (Font Diner, Apache 2.0), bundled in the app.
    public static let hand = "Schoolbell-Regular"
}

public enum Type {

    private static func display(_ size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size, weight: weight)
    }

    // MARK: Hand

    /// Schoolbell. Its x-height runs small beside SF Pro, so it is set a notch up to sit at the
    /// same optical size as the SF it replaces. Scales with Dynamic Type like a title.
    public static func hand(_ size: CGFloat) -> Font {
        .custom(Face.hand, size: size * 1.12, relativeTo: .title)
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
