import Foundation

/// What a rendered page looked like when rung 2 gave up on it.
///
/// "Page produced no media" is five different problems, and they have different answers. A
/// login wall means the platform will not serve a logged-out visitor and the Download button is
/// the only route. A `blob:` player means the page did work but streams through Media Source
/// Extensions, and a config change might still reach the file. No `<video>` at all usually means
/// the page never finished building. Telling them apart is the difference between giving up on a
/// platform and fixing a rule -- so the page is asked, once, before the resolver lets it go.
public struct RenderedPageProbe: Decodable, Sendable, Equatable {
    /// `location.href` at the end -- where the page actually ended up, after any redirect.
    public var href: String?
    /// How many `<video>` elements the page built.
    public var videos: Int
    /// Whether any of them is fed from a `blob:` URL rather than a fetchable one.
    public var blob: Bool

    public init(href: String?, videos: Int, blob: Bool) {
        self.href = href
        self.videos = videos
        self.blob = blob
    }

    /// Evaluated in the page when the rule's own script has come back empty until the deadline.
    ///
    /// Compiled in rather than fetched, unlike the rules: it only describes the page for the log
    /// and never decides what gets downloaded, so it has nothing a platform change could break
    /// that a release would be needed to fix. Returns JSON text because `evaluateJavaScript`
    /// bridges a plain object as a dictionary of loosely typed values, and a string decodes the
    /// same way on every OS version.
    public static let script = """
        (() => {
          const videos = [...document.querySelectorAll('video')];
          const sources = videos.flatMap(v =>
            [v.currentSrc, v.src, ...[...v.querySelectorAll('source')].map(s => s.src)]);
          return JSON.stringify({
            href: location.href,
            videos: videos.length,
            blob: sources.some(s => typeof s === 'string' && s.startsWith('blob:')),
          });
        })()
        """

    /// Parses what `script` returned. Nil for anything else, including a page that would not run it.
    public static func parse(_ value: Any?) -> RenderedPageProbe? {
        guard let text = value as? String else { return nil }
        return try? JSONDecoder().decode(RenderedPageProbe.self, from: Data(text.utf8))
    }

    /// The failure detail rung 2 records and logs, most specific first.
    ///
    /// A login wall wins over everything else: a page that bounced to a sign-in screen may still
    /// carry a muted background video, and that video is not the post.
    public var diagnosis: String {
        if isLoginWall { return Self.loginWall }
        if blob { return Self.blobOnlyPlayer }
        if videos == 0 { return Self.noVideoElement }
        return Self.videoWithoutSource
    }

    /// Whether the page ended up on a sign-in or challenge screen instead of the post.
    ///
    /// Instagram sends a logged-out visitor to `/accounts/login/` or a `/challenge/` page, and
    /// TikTok to `/login`. Read from the path so a post whose caption mentions logging in does
    /// not count.
    public var isLoginWall: Bool {
        guard let href, let path = URLComponents(string: href)?.path.lowercased() else { return false }
        return ["/accounts/login", "/challenge", "/login"].contains { path.hasPrefix($0) }
    }

    /// Where the page landed, cut to its host and first path segment -- `www.instagram.com/accounts`.
    ///
    /// Enough to tell a sign-in redirect from the post, without writing the post's own address
    /// (and so what this person saved) into the system log.
    public var landedOn: String {
        guard let href, let components = URLComponents(string: href), let host = components.host else {
            return "unknown"
        }
        let first = components.path.split(separator: "/").first.map { "/\($0)" } ?? ""
        return host + first
    }

    public static let loginWall = "login wall"
    public static let blobOnlyPlayer = "blob-only player"
    public static let noVideoElement = "no video element"
    public static let videoWithoutSource = "video without a source"
    /// The probe itself could not run -- the page was blank, crashed, or never loaded.
    public static let pageDidNotAnswer = "page did not answer"
}
