import Foundation
import os
import QuokkaEngine
@preconcurrency import WebKit

/// Renders a public post in an offscreen `WKWebView` and reads the media URL the page itself
/// produced.
///
/// **This exists because fetching stopped working, and that was measured rather than assumed.**
/// Instagram's embed endpoint returns a byte-identical ~623 KB application shell for a real
/// shortcode and for an invented one -- no media, no metadata. TikTok's video page returns its
/// rehydration blob with `statusMsg: "item doesn't exist"` to an unauthenticated client. There
/// is nothing in either document for a regex to find.
///
/// A real engine is a different client. The page runs its own JavaScript, from the user's own
/// device and address, and builds the same `<video>` element it would build in Safari. Reading
/// that element is not a second gate being picked -- it is the page working normally.
///
/// Nothing is shown to the user and nothing is stored: the view is offscreen, lives for one
/// resolution, and its data store is non-persistent, so no cookie or cache survives it.
/// What a rendered page produced: the media URL, and what a request for it has to carry to be
/// answered the way the page's own request was.
struct ResolvedMedia: Sendable {
    let url: URL
    /// The page, sent as the Referer -- TikTok's video CDN refuses a request without it.
    let referer: URL
    /// The cookies the page set while it loaded, for the media host only. TikTok's CDN answers
    /// 403 to a request missing the `tt_chain_token` its own page just set.
    let cookieHeader: String?
}

@MainActor
final class WebViewMediaResolver {
    private let logger = Logger(subsystem: "com.matthewpark.quokka", category: "webview")

    /// How long to let a page settle before giving up.
    ///
    /// Generous, because this runs off a user tap and the alternative to waiting is telling
    /// them it failed. Bounded, because a page that never resolves would otherwise hold a web
    /// process open for the life of the app.
    private let timeout: TimeInterval = 25
    /// The script is re-run on an interval rather than once on load. These pages finish
    /// loading long before they finish building the player, so a single evaluation at
    /// `didFinish` reliably returns null on a page that works.
    private let pollInterval: Duration = .milliseconds(400)

    func resolve(_ page: URL, rule: ResolverRule) async throws -> ResolvedMedia {
        guard let script = rule.script, !script.isEmpty else {
            throw TranscriptFailure.noResolverRule
        }

        let configuration = WKWebViewConfiguration()
        // Non-persistent: nothing this view touches outlives it. The user is not signed in
        // here and nothing it collects is kept.
        configuration.websiteDataStore = .nonPersistent()
        configuration.allowsInlineMediaPlayback = true
        // Never start playback. The point is to learn the URL, not to watch anything -- and an
        // autoplaying video would burn battery and data for no reason.
        configuration.mediaTypesRequiringUserActionForPlayback = .all

        let webView = WKWebView(frame: .init(x: 0, y: 0, width: 390, height: 844),
                                configuration: configuration)
        for (field, value) in rule.headers where field.lowercased() == "user-agent" {
            webView.customUserAgent = value
        }
        defer {
            // A WKWebView keeps a content process alive until it is torn down. Left behind,
            // one per resolution, this becomes the app's largest memory consumer.
            webView.stopLoading()
            webView.loadHTMLString("", baseURL: nil)
        }

        var request = URLRequest(url: page)
        for (field, value) in rule.headers where field.lowercased() != "user-agent" {
            request.setValue(value, forHTTPHeaderField: field)
        }
        webView.load(request)

        let deadline = Date().addingTimeInterval(timeout)
        // Kept rather than discarded: a rule whose script throws on every poll looks exactly
        // like a page with no video, and the difference is a config fix versus a closed door.
        var scriptError: String?
        while Date() < deadline {
            try? await Task.sleep(for: pollInterval)
            if Task.isCancelled { throw TranscriptFailure.transport(nil) }

            let value: Any?
            do {
                value = try await webView.evaluateJavaScript(script)
            } catch {
                value = nil
                if scriptError == nil { scriptError = error.localizedDescription }
            }
            if let string = value as? String,
               let url = URL(string: string),
               url.scheme?.hasPrefix("http") == true {
                logger.info("resolved media for \(rule.platform.rawValue, privacy: .public) via webView")
                // Read before the defer tears the view down: the store is non-persistent, so
                // these cookies exist nowhere else and vanish with it.
                let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
                return ResolvedMedia(url: url, referer: page, cookieHeader: Self.cookieHeader(cookies, for: url))
            }
        }

        // The honest failure. The page rendered and still produced no media element, which for
        // a private account or a region-locked post is the correct and permanent answer -- and
        // the one the UI turns into "open it in the app, tap Download, share the file here".
        // The detail says which kind of "no media" it was; the user's sentence does not change.
        let diagnosis = await diagnose(webView)
        logger.info("no media for \(rule.platform.rawValue, privacy: .public): \(diagnosis, privacy: .public)\(scriptError.map { "; rule script threw: \($0)" } ?? "", privacy: .public)")
        throw TranscriptFailure.mediaUnreachable("page produced no media: \(diagnosis)")
    }

    /// Asks the page where it ended up and what player it built. See `RenderedPageProbe`.
    private func diagnose(_ webView: WKWebView) async -> String {
        let value = try? await webView.evaluateJavaScript(RenderedPageProbe.script)
        guard let probe = RenderedPageProbe.parse(value) else {
            return RenderedPageProbe.pageDidNotAnswer
        }
        return "\(probe.diagnosis) (at \(probe.landedOn), \(probe.videos) video)"
    }

    /// The `Cookie` header a browser would send to the media host: only cookies whose domain
    /// covers that host, so nothing the page set for another domain travels with the request.
    static func cookieHeader(_ cookies: [HTTPCookie], for url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        let matching = cookies.filter { cookie in
            let domain = cookie.domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            return host == domain || host.hasSuffix("." + domain)
        }
        guard !matching.isEmpty else { return nil }
        return HTTPCookie.requestHeaderFields(with: matching)["Cookie"]
    }
}
