import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Five faces, each with exactly one job.
///
/// Two of these are heavy display faces, which is more than a minimal interface would
/// normally carry. They work here because their scope is narrow: Bagel Fat One appears only
/// as the wordmark, Keep on Truckin only on collection titles. Everything a person actually
/// reads is SF Pro or mono. The display faces are the moments, not the material -- and set
/// large in white on true black, a fat face reads as a poster rather than as decoration.
///
/// Newsreader stands in for Copernicus, Anthropic's brand serif, which is a licensed foundry
/// face and not distributable. It carries the fallback tile, where a title set in a serif at
/// size IS the artwork for the three platforms that never yield a thumbnail.
public enum Face {
    /// Wordmark only.
    public static let wordmark = "BagelFatOne-Regular"
    /// Collection and section titles only.
    public static let feature = "KeeponTruckinFW"
    /// One statement per screen, at size, and nowhere else.
    ///
    /// A ransom-note face is all texture and no reading comfort -- every glyph is a different
    /// found object, which is exactly why it works for four words and falls apart for a
    /// sentence. Scoped this tightly it is a voice; used any wider it is noise.
    public static let punk = "Veryverypunkfont"
    /// Editorial serif -- tile titles, long text.
    public static let editorial = "Newsreader16pt-Regular"
    /// Metadata: counts, timestamps, hosts.
    public static let mono = "JetBrainsMono-Regular"

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

    /// Falls back to an explicit system *design* rather than letting `Font.custom` silently
    /// substitute the default face. A missing font would otherwise turn a serif into SF Pro
    /// with no error anywhere, and nobody notices for weeks.
    private static func custom(
        _ name: String,
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        fallback: Font.Design = .default
    ) -> Font {
        Face.isBundled(name)
            ? .custom(name, size: size).weight(weight)
            : .system(size: size, weight: weight, design: fallback)
    }

    // MARK: Display

    public static func wordmark(_ size: CGFloat = 46) -> Font {
        custom(Face.wordmark, size, weight: .regular, fallback: .rounded)
    }

    /// Collection names. The one place the groovy face is allowed.
    public static func feature(_ size: CGFloat = 26) -> Font {
        custom(Face.feature, size, weight: .regular, fallback: .rounded)
    }

    /// The statement face. One line, large, never a paragraph.
    public static func statement(_ size: CGFloat = 40) -> Font {
        custom(Face.punk, size, weight: .regular, fallback: .rounded)
    }

    public static func title(_ size: CGFloat = 22) -> Font {
        custom(Face.editorial, size, fallback: .serif)
    }

    /// The fallback tile leans on this: with no thumbnail, the title at size is the artwork.
    public static func tileTitle(_ size: CGFloat = 17) -> Font {
        custom(Face.editorial, size, fallback: .serif)
    }

    // MARK: Functional -- SF Pro

    public static let body = Font.system(size: 16, weight: .regular)
    public static let bodyEmphasis = Font.system(size: 16, weight: .semibold)
    public static let control = Font.system(size: 15, weight: .medium)
    public static let caption = Font.system(size: 13, weight: .regular)

    // MARK: Metadata

    public static func meta(_ size: CGFloat = 11) -> Font {
        custom(Face.mono, size, fallback: .monospaced)
    }
}

public enum FontRegistration {
    static let required = [Face.wordmark, Face.feature, Face.editorial, Face.mono, Face.punk]

    /// Reports rather than crashes. Every style above has a real system fallback, so a missing
    /// file degrades the design instead of blocking the build.
    @discardableResult
    public static func missingFaces() -> [String] {
        required.filter { !Face.isBundled($0) }
    }
}
