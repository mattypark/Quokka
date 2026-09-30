import Testing
import Foundation
@testable import QuokkaEngine

/// Rung 2's failure detail is how a single Simulator run answers "is this platform closed, or is
/// the rule wrong". These pin which answer each page shape gets.
struct RenderedPageTests {

    @Test("A redirect to Instagram's sign-in page is a login wall")
    func instagramLoginRedirect() {
        let probe = RenderedPageProbe(
            href: "https://www.instagram.com/accounts/login/?next=%2Freel%2FDAbC123%2F",
            videos: 0, blob: false)
        #expect(probe.isLoginWall)
        #expect(probe.diagnosis == RenderedPageProbe.loginWall)
    }

    @Test("Challenge and TikTok login paths count too")
    func otherSignInPaths() {
        #expect(RenderedPageProbe(href: "https://www.instagram.com/challenge/?next=/p/x/", videos: 0, blob: false).isLoginWall)
        #expect(RenderedPageProbe(href: "https://www.tiktok.com/login?redirect_url=x", videos: 0, blob: false).isLoginWall)
    }

    @Test("A login wall wins over a background video on the same page")
    func loginWallBeatsVideo() {
        let probe = RenderedPageProbe(href: "https://www.instagram.com/accounts/login/", videos: 1, blob: true)
        #expect(probe.diagnosis == RenderedPageProbe.loginWall)
    }

    @Test("A post whose path only mentions login is not a wall")
    func loginInQueryIsNotAWall() {
        let probe = RenderedPageProbe(href: "https://www.instagram.com/p/DAbC123/?utm=login", videos: 1, blob: true)
        #expect(!probe.isLoginWall)
        #expect(probe.diagnosis == RenderedPageProbe.blobOnlyPlayer)
    }

    @Test("A page with no video, and one with a video but no source, read differently")
    func emptyPages() {
        #expect(RenderedPageProbe(href: "https://www.instagram.com/p/x/", videos: 0, blob: false).diagnosis
                == RenderedPageProbe.noVideoElement)
        #expect(RenderedPageProbe(href: "https://www.instagram.com/p/x/", videos: 2, blob: false).diagnosis
                == RenderedPageProbe.videoWithoutSource)
    }

    @Test("Where it landed is the host and first segment, never the post's own address")
    func landedOnKeepsThePostOutOfTheLog() {
        #expect(RenderedPageProbe(href: "https://www.instagram.com/accounts/login/?next=%2Fp%2FDAbC123%2F", videos: 0, blob: false).landedOn
                == "www.instagram.com/accounts")
        #expect(RenderedPageProbe(href: "https://www.instagram.com/p/DAbC123/", videos: 1, blob: true).landedOn
                == "www.instagram.com/p")
        #expect(RenderedPageProbe(href: "https://www.tiktok.com/", videos: 0, blob: false).landedOn == "www.tiktok.com")
        #expect(RenderedPageProbe(href: nil, videos: 0, blob: false).landedOn == "unknown")
    }

    @Test("Parses the JSON text the probe script returns, and nothing else")
    func parsesOnlyTheScriptsOutput() {
        let parsed = RenderedPageProbe.parse(#"{"href":"https://www.tiktok.com/@a/video/1","videos":1,"blob":false}"#)
        #expect(parsed == RenderedPageProbe(href: "https://www.tiktok.com/@a/video/1", videos: 1, blob: false))
        #expect(RenderedPageProbe.parse(nil) == nil)
        #expect(RenderedPageProbe.parse(NSNull()) == nil)
        #expect(RenderedPageProbe.parse("not json") == nil)
    }
}
