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
    public static let display = "Newsreader-Regular"
    public static let mono = "JetBrainsMono-Regular"

    /// Whether a face is actually registered. Resolved once: `UIFont(name:)` is not free, and
    /// this is consulted on every text style.
    static func isBundled(_ name: String) -> Bool {
        #if canImport(UIKit)
        bundledCache.value(for: name)
        #else
        false
        #endif
    }

    #if canImport(UIKit)
    private static let bundledCache = FaceCache()

    final class FaceCache: @unchecked Sendable {
        private var known: [String: Bool] = [:]
        private let lock = NSLock()

        func value(for name: String) -> Bool {
            lock.lock(); defer { lock.unlock() }
            if let cached = known[name] { return cached }
            let present = UIFont(name: name, size: 12) != nil
            known[name] = present
            return present
        }
    }
    #endif
}

public enum Type {

    /// Falls back to the system serif rather than to SF Pro when Newsreader is absent.
    ///
    /// `Font.custom` on a missing face silently substitutes the *default* system font, which
    /// turns a missing serif into an invisible bug -- the wordmark would just quietly stop
    /// being a serif and nobody would notice for weeks. Choosing `.serif` explicitly keeps
    /// the design intent legible even before the licensed files are in the bundle.
    private static func display(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        Face.isBundled(Face.display)
            ? .custom(Face.display, size: size).weight(weight)
            : .system(size: size, weight: weight, design: .serif)
    }

    private static func monospaced(_ size: CGFloat) -> Font {
        Face.isBundled(Face.mono)
            ? .custom(Face.mono, size: size)
            : .system(size: size, weight: .regular, design: .monospaced)
    }

    // MARK: Display -- Newsreader

    public static func wordmark(_ size: CGFloat = 44) -> Font { display(size, .medium) }
    public static func title(_ size: CGFloat = 22) -> Font { display(size, .regular) }

    /// The fallback tile leans on this: when no thumbnail exists, the title at size IS the
    /// artwork, so this is a load-bearing style rather than a decorative one.
    public static func tileTitle(_ size: CGFloat = 17) -> Font { display(size, .regular) }

    // MARK: Functional -- SF Pro

    public static let body = Font.system(size: 16, weight: .regular)
    public static let bodyEmphasis = Font.system(size: 16, weight: .semibold)
    public static let control = Font.system(size: 15, weight: .medium)
    public static let caption = Font.system(size: 13, weight: .regular)

    // MARK: Metadata -- JetBrains Mono

    public static func meta(_ size: CGFloat = 11) -> Font { monospaced(size) }
}

public enum FontRegistration {
    static let required = [Face.display, Face.mono]

    /// Reports which faces are missing. Deliberately not an assertion: the app is designed to
    /// run correctly on system fallbacks, so a missing font is a note for the console, not a
    /// crash that blocks work until someone downloads a file.
    @discardableResult
    public static func missingFaces() -> [String] {
        required.filter { !Face.isBundled($0) }
    }
}
