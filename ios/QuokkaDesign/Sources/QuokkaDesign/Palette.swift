import SwiftUI

/// Black, white and sky.
///
/// Matthew's call (2026-09-30): the black-square mark, white paper, and one sky blue -- about
/// a third Nudgy's, which puts a live sky behind its header, and the rest Quokka's own. Black
/// is the brand (the mark, the tab bar, primary type), white is the page, and blue means
/// "this is the part that analyses" -- the sky header, the breakdown checks, the one button
/// that does something to a video.
///
/// Every text pairing is measured, not assumed; the ratios are beside each value.
public enum Ink {
    public static let black = Color(hex: 0x0A0A0A)
    public static let white = Color(hex: 0xFFFFFF)
}

public enum Sky {
    /// The header gradient, top to bottom. White text is only ever set over the upper two
    /// stops, or over the bottom stop with `shade` laid on it.
    public static let top = Color(hex: 0x1560D4)    // white 5.6:1
    public static let mid = Color(hex: 0x2A7FE3)    // white 3.7:1 -- large text only
    public static let bottom = Color(hex: 0x4E9DEB)
    /// Laid over the lower half of the sky so white text clears 4.5:1 at any height.
    public static let shade = Color.black.opacity(0.18)

    /// Blue as an ink: links, the active tab dot, a passed check, the primary button.
    public static let accent = Color(hex: 0x1A66D1) // white 5.4:1, paper 5.0:1
    /// A wash behind blue text -- chips and the analysed state.
    public static let tint = Color(hex: 0xE7F1FD)   // accent on it 4.8:1
    /// Glass pills on the sky.
    public static let glass = Color.white.opacity(0.18)
    public static let glassStroke = Color.white.opacity(0.28)
}

/// Semantic surfaces, so a view never reaches for a hex value.
public enum Surface {
    /// The page. A cool paper -- white with the faintest blue in it, so white cards read as
    /// cards without needing a shadow.
    public static let canvas = Color(hex: 0xF3F5F8)
    /// Cards, sheets, the search field.
    public static let raised = Ink.white
    /// The search pill and text fields that sit on a card.
    public static let field = Color(hex: 0xEDF0F4)
    /// Circle controls on paper.
    public static let control = Ink.white
    public static let elevated = Color(hex: 0xE4E8EE)
    public static let hairline = Color.black.opacity(0.08)
    public static let hairlineStrong = Color.black.opacity(0.12)
    /// Filled black controls: the tab bar, secondary pills.
    public static let inverse = Ink.black
}

public enum Label {
    public static let primary = Color(hex: 0x0A0A0A)   // paper 18.4:1
    public static let secondary = Color(hex: 0x5E6573) // paper 5.4:1
    public static let tertiary = Color(hex: 0x646B78)  // paper 4.9:1 -- AA at any size
    /// Glyphs and 17pt+ text only.
    public static let dim = Color(hex: 0x8E95A2)       // paper 2.8:1
    /// Text on black or on the sky.
    public static let onInverse = Ink.white
    public static let onSky = Ink.white
    public static let onSkySecondary = Color.white.opacity(0.82)
}

extension Color {
    /// 0xRRGGBB. Kept internal to the design system so hex literals never leak into views.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
