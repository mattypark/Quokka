import SwiftUI

/// Allim has no accent colour. The only colour on screen belongs to the saved work itself.
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
    public static let ink0 = Color(hex: 0x000000) // text
    public static let ink1 = Color(hex: 0x060606)
    public static let ink2 = Color(hex: 0x222222)
    public static let ink3 = Color(hex: 0x414141) // secondary text   10.1:1 on white
    public static let ink4 = Color(hex: 0x636363) // tertiary text     5.9:1 on white
    public static let ink5 = Color(hex: 0x878787) // dimmed            3.5:1 -- large only
    public static let ink6 = Color(hex: 0xAEAEAE) // borders
    public static let ink7 = Color(hex: 0xE8E8E8) // hairlines, fills
    public static let ink8 = Color(hex: 0xFFFFFF) // canvas

    public static let all: [Color] = [ink0, ink1, ink2, ink3, ink4, ink5, ink6, ink7, ink8]
}

/// Semantic names, so a view never reaches for a ramp step directly and the contrast
/// guarantees stay attached to a role rather than to a number.
public enum Surface {
    public static let canvas = Ink.ink8
    /// Cards and grouped rows. Barely off-white: on paper the separation comes from the
    /// hairline, not from a grey wash.
    public static let raised = Color(hex: 0xFAFAFA)
    public static let elevated = Ink.ink7
    public static let hairline = Ink.ink7
    public static let border = Ink.ink6
    /// Filled buttons and the wordmark -- black on white.
    public static let inverse = Ink.ink0
}

public enum Label {
    public static let primary = Ink.ink0    // 21.0:1
    public static let secondary = Ink.ink3  // 10.1:1
    public static let tertiary = Ink.ink4   //  5.9:1 -- passes AA at any size
    /// Only for text at 17pt+ or semibold 14pt+.
    public static let dim = Ink.ink5        //  3.5:1
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
