import SwiftUI

/// Quokka has no accent colour. The only colour on screen belongs to the saved work itself.
///
/// The ramp is nine steps of even OKLab lightness (L = 0, 0.125 ... 1.0) converted to sRGB.
/// The dark end bunches because lightness is cubed on the way to linear RGB, so equal
/// perceptual steps are tiny numeric ones near black.
///
/// **The interface is white.** Paper, not screen. A saved library is something you look
/// through rather than at, and a white ground reads as a contact sheet or a scrapbook page,
/// where a black one reads as a player. It also means the app is legible outdoors, which is
/// where scrolling actually happens.
public enum Ink {
    public static let ink0 = Color(hex: 0x000000)
    public static let ink1 = Color(hex: 0x060606)
    public static let ink2 = Color(hex: 0x222222)
    public static let ink3 = Color(hex: 0x414141)
    public static let ink4 = Color(hex: 0x636363)
    public static let ink5 = Color(hex: 0x878787)
    public static let ink6 = Color(hex: 0xAEAEAE)
    public static let ink7 = Color(hex: 0xE8E8E8)
    public static let ink8 = Color(hex: 0xFFFFFF)

    public static let all: [Color] = [ink0, ink1, ink2, ink3, ink4, ink5, ink6, ink7, ink8]
}

/// Semantic names, so a view never reaches for a ramp step directly and the contrast
/// guarantees stay attached to a role rather than to a number.
///
/// Values follow Cosmos, measured from its computed styles -- see `docs/DESIGN-REFS.md`.
public enum Surface {
    public static let canvas = Ink.ink8
    /// Typographic tiles and grouped rows. Barely off-white: on paper the separation comes
    /// from the edge of the thing, not from a grey wash.
    public static let raised = Color(hex: 0xFAFAFA)
    /// The search pill and other text fields. Warm rather than neutral, which is the whole
    /// difference between a field that looks designed and one that looks disabled.
    public static let field = Color(hex: 0xFBFAF8)
    /// Grey-filled circle controls -- back, search, more.
    public static let control = Color(hex: 0xF2F2F2)
    public static let elevated = Ink.ink7
    /// Hairlines are black at low opacity rather than a solid grey, so they sit correctly on
    /// the field fill and on photographs as well as on white.
    public static let hairline = Color.black.opacity(0.10)
    /// The search pill's outline, a shade firmer than a button's.
    public static let hairlineStrong = Color.black.opacity(0.12)
    public static let border = Ink.ink6
    /// Filled buttons -- black on white.
    public static let inverse = Color(hex: 0x0A0A0A)
}

public enum Label {
    /// Not pure black: Cosmos sets its text at #0A0A0A, and the difference is what keeps a
    /// white screen of type from buzzing.
    public static let primary = Color(hex: 0x0A0A0A)  // 19.8:1
    /// Inactive tabs, handles, counts.
    public static let secondary = Color(hex: 0x6B6B6B) //  5.3:1
    public static let tertiary = Color(hex: 0x767676)  //  4.5:1 -- the AA floor, at any size
    /// Only for text at 17pt+ or semibold 14pt+, and for glyphs.
    public static let dim = Ink.ink5                    //  3.5:1
    /// Text on a filled black control.
    public static let onInverse = Ink.ink8
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
