import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Three faces, each with one job.
///
/// Newsreader is display-only -- the wordmark and collection titles. SF Pro carries every
/// functional string. JetBrains Mono carries metadata: counts, dates, hosts. The mono against
/// the serif is what makes a wall of monochrome read as an archive rather than a dev tool,
/// and it is the whole reason three faces earn their place instead of one.
public enum Face {
    public static let display = "Newsreader"
    public static let mono = "JetBrainsMono-Regular"
}

public enum Type {

    // MARK: Display -- Newsreader

    public static func wordmark(_ size: CGFloat = 44) -> Font {
        .custom(Face.display, size: size).weight(.medium)
    }

    public static func title(_ size: CGFloat = 22) -> Font {
        .custom(Face.display, size: size).weight(.regular)
    }

    /// The fallback tile leans on this: when no thumbnail exists, the title in Newsreader at
    /// size IS the artwork.
    public static func tileTitle(_ size: CGFloat = 17) -> Font {
        .custom(Face.display, size: size).weight(.regular)
    }

    // MARK: Functional -- SF Pro

    public static let body = Font.system(size: 16, weight: .regular)
    public static let bodyEmphasis = Font.system(size: 16, weight: .semibold)
    public static let control = Font.system(size: 15, weight: .medium)
    public static let caption = Font.system(size: 13, weight: .regular)

    // MARK: Metadata -- JetBrains Mono

    public static func meta(_ size: CGFloat = 11) -> Font {
        .custom(Face.mono, size: size)
    }
}

public enum FontRegistration {
    /// The bundled faces, by the PostScript name `Font.custom` will ask for.
    static let required = [Face.display, Face.mono]

    /// A missing custom font does not fail loudly -- SwiftUI silently substitutes the system
    /// face and the app just looks subtly wrong forever. This turns that into a debug crash
    /// at launch, which is the only way it gets noticed.
    public static func assertBundled() {
        #if DEBUG && canImport(UIKit)
        for name in required where UIFont(name: name, size: 12) == nil {
            assertionFailure("Font '\(name)' is not in the bundle. Check Resources/Fonts and UIAppFonts.")
        }
        #endif
    }
}
