import SwiftUI

/// Allim has no accent colour. The only colour on screen belongs to the saved work itself.
///
/// The ramp is nine steps of even OKLab lightness (L = 0, 0.125 ... 1.0) converted to sRGB,
/// which is why the dark end bunches: lightness is cubed on the way to linear RGB, so equal
/// perceptual steps are tiny numeric ones near black. That bunching is useful here -- `ink1`
/// is a hairline lift off the canvas rather than a visible grey, which is exactly what a
/// black-ground interface needs and what an evenly-spaced-in-sRGB ramp cannot give you.
public enum Ink {
    public static let ink0 = Color(hex: 0x000000) // canvas
    public static let ink1 = Color(hex: 0x060606) // barely-lifted surface
    public static let ink2 = Color(hex: 0x222222) // hairline, raised surface
    public static let ink3 = Color(hex: 0x414141) // borders          2.1:1 -- never text
    public static let ink4 = Color(hex: 0x636363) // dimmed metadata  3.5:1 -- large only
    public static let ink5 = Color(hex: 0x878787)
    public static let ink6 = Color(hex: 0xAEAEAE) // secondary text   9.5:1
    public static let ink7 = Color(hex: 0xD6D6D6)
    public static let ink8 = Color(hex: 0xFFFFFF) // primary text    21.0:1

    public static let all: [Color] = [ink0, ink1, ink2, ink3, ink4, ink5, ink6, ink7, ink8]
}

/// Semantic names, so a view never reaches for a ramp step directly and the contrast
/// guarantees above stay attached to a role rather than to a number.
public enum Surface {
    public static let canvas = Ink.ink0
    public static let raised = Ink.ink1
    public static let elevated = Ink.ink2
    public static let hairline = Ink.ink2
    public static let border = Ink.ink3
}

public enum Label {
    public static let primary = Ink.ink8
    public static let secondary = Ink.ink6
    /// Only for text at 17pt+ or semibold 14pt+. Below that it fails WCAG AA on the canvas.
    public static let tertiary = Ink.ink4
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
