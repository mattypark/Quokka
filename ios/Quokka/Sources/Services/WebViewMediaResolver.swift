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

    func mediaURL(for page: URL, rule: ResolverRule) async throws -> URL {
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
        while Date() < deadline {
            try? await Task.sleep(for: pollInterval)
            if Task.isCancelled { throw TranscriptFailure.transport(nil) }

            let value = try? await webView.evaluateJavaScript(script)
            if let string = value as? String,
               let url = URL(string: string),
               url.scheme?.hasPrefix("http") == true {
                logger.info("resolved media for \(rule.platform.rawValue, privacy: .public) via webView")
                return url
            }
        }

        // The honest failure. The page rendered and still produced no media element, which for
        // a private account or a region-locked post is the correct and permanent answer -- and
        // the one the UI turns into "open it in the app, tap Download, share the file here".
        throw TranscriptFailure.mediaUnreachable("page produced no media")
    }
}
