import Testing
import Foundation
@testable import QuokkaEngine

/// The rules arrive over the wire, which means a malformed one is a *runtime* problem rather
/// than a compile-time one. These pin the two things that would otherwise fail silently: a
/// template that cannot be filled, and a pattern that matches nothing because the payload
/// escapes its slashes.
struct ResolverConfigTests {

    private let instagram = ResolverRule(
        platform: .instagram,
        requestTemplate: "https://www.instagram.com/reel/{id}/embed/captioned/",
        mediaPatterns: [#""video_url":"([^"]+)""#]
    )

    @Test("Escaped slashes in an embedded JSON payload still match")
    func unescapesBeforeMatching() {
        // These pages are JSON embedded in HTML, so every slash in a URL arrives as \/. A
        // pattern written against the readable form matches nothing, silently, forever -- and
        // it looks exactly like the platform having removed the field.
        let body = #"{"video_url":"https:\/\/scontent.cdninstagram.com\/v\/t66\/clip.mp4"}"#
        #expect(instagram.extractMediaURL(from: body)
                == "https://scontent.cdninstagram.com/v/t66/clip.mp4")
    }

    @Test("Patterns are tried in order and the first hit wins")
    func firstMatchingPatternWins() {
        let rule = ResolverRule(
            platform: .tiktok,
            requestTemplate: "https://www.tiktok.com/@x/video/{id}",
            mediaPatterns: [#""playAddr":"([^"]+)""#, #""downloadAddr":"([^"]+)""#]
        )
        let body = #"{"downloadAddr":"https://b.example/dl.mp4","playAddr":"https://a.example/play.mp4"}"#
        #expect(rule.extractMediaURL(from: body) == "https://a.example/play.mp4")
    }

    @Test("A capture that is not a URL is rejected rather than fetched")
    func nonURLCapturesAreDropped() {
        // A platform that changes a field from a URL to an opaque id must read as "no media
        // found", not as a request to GET the string "1234567890".
        #expect(instagram.extractMediaURL(from: #"{"video_url":"1234567890"}"#) == nil)
        #expect(instagram.extractMediaURL(from: "no payload here at all") == nil)
    }

    @Test("A template needing an id it was not given produces no request")
    func templateWithoutItsIDIsNil() {
        // Better than building `.../reel//embed/` and fetching a 404 -- the request never
        // happens, and the rung reports notApplicable instead of a transport failure.
        #expect(instagram.requestURL(contentID: nil, postURL: "https://instagram.com/reel/abc/") == nil)
        #expect(instagram.requestURL(contentID: "", postURL: nil) == nil)
        #expect(instagram.requestURL(contentID: "DAbC123", postURL: nil)
                == "https://www.instagram.com/reel/DAbC123/embed/captioned/")
    }

    @Test("A config round-trips through JSON the way the worker will send it")
    func decodesFromTheWire() throws {
        let json = #"""
        {
          "version": 7,
          "enabledRungs": ["sharedFile", "resolveOnDevice"],
          "rules": [{
            "platform": "instagram",
            "requestTemplate": "https://www.instagram.com/reel/{id}/embed/captioned/",
            "headers": {"User-Agent": "Mozilla/5.0"},
            "mediaPatterns": ["\"video_url\":\"([^\"]+)\""],
            "maxBytes": 60000000
          }]
        }
        """#
        let config = try JSONDecoder().decode(ResolverConfig.self, from: Data(json.utf8))

        #expect(config.version == 7)
        #expect(config.isEnabled(.resolveOnDevice))
        // Absent means off. A worker that stops sending a rung switches it off everywhere
        // without having to send an explicit false.
        #expect(config.isEnabled(.hosted) == false)
        #expect(config.rule(for: .instagram)?.maxBytes == 60_000_000)
        #expect(config.rule(for: .tiktok) == nil)
    }

    @Test("A malformed config is not a config")
    func garbageDoesNotDecodeIntoSomethingPermissive() {
        // The caller falls back to failClosed on a throw. What must never happen is a partial
        // decode that leaves a rung enabled by accident.
        let broken = Data(#"{"version": 1}"#.utf8)
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(ResolverConfig.self, from: broken)
        }
    }
}

/// The `webView` strategy exists because fetching stopped working. These pin the decoding
/// defaults that keep an already-deployed config valid when a field is added to the rule.
struct ResolverStrategyTests {

    @Test("A rule written before strategy existed still decodes, as htmlPattern")
    func strategyDefaultsForOlderConfigs() throws {
        // Without this, adding a field silently invalidates every config already on a device,
        // and those devices fall back to rung 0 with nothing to say why.
        let json = #"""
        {"platform":"reddit","requestTemplate":"https://x/{id}","mediaPatterns":["a(b)"]}
        """#
        let rule = try JSONDecoder().decode(ResolverRule.self, from: Data(json.utf8))
        #expect(rule.strategy == .htmlPattern)
        #expect(rule.maxBytes == 120_000_000)
        #expect(rule.script == nil)
    }

    @Test("A webView rule loads the post itself, verbatim")
    func rawURLTokenIsNotEncoded() {
        // The page a webView rule needs to render *is* the post, so percent-encoding it the
        // way a query parameter needs would produce a URL that loads nothing.
        let rule = ResolverRule(
            platform: .tiktok,
            strategy: .webView,
            requestTemplate: "{rawurl}",
            script: "document.querySelector('video')?.src ?? null")
        #expect(rule.requestURL(contentID: nil, postURL: "https://www.tiktok.com/@a/video/12")
                == "https://www.tiktok.com/@a/video/12")
        #expect(rule.requestURL(contentID: "12", postURL: nil) == nil)
    }

    @Test("A webView rule decodes its script")
    func scriptSurvivesTheWire() throws {
        let json = #"""
        {"platform":"instagram","strategy":"webView","requestTemplate":"{rawurl}",
         "script":"document.querySelector('video')?.src ?? null","maxBytes":80000000}
        """#
        let rule = try JSONDecoder().decode(ResolverRule.self, from: Data(json.utf8))
        #expect(rule.strategy == .webView)
        #expect(rule.script?.contains("querySelector") == true)
        #expect(rule.mediaPatterns.isEmpty)
    }
}
