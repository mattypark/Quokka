import Testing
import Foundation
@testable import QuokkaEngine

/// The canonicaliser is the only thing standing between a clean library and three copies of
/// every Instagram post -- one from the DM thread, one from Saved, one from Liked. These pin
/// the collapses that matter and the ones that must NOT happen.
struct CanonicalLinkTests {

    private func canon(_ s: String) -> CanonicalLink? { LinkCanonicaliser.canonicalise(s) }
    private func url(_ s: String) -> String? { canon(s)?.url.absoluteString }

    // MARK: - Instagram

    @Test("Instagram /p/, /reel/, /reels/ and /tv/ all collapse to one canonical post")
    func instagramKindsCollapse() {
        let expected = "https://www.instagram.com/p/C8xYzAbCdEf/"
        #expect(url("https://www.instagram.com/p/C8xYzAbCdEf/") == expected)
        #expect(url("https://www.instagram.com/reel/C8xYzAbCdEf/") == expected)
        #expect(url("https://www.instagram.com/reels/C8xYzAbCdEf/") == expected)
        #expect(url("https://www.instagram.com/tv/C8xYzAbCdEf/") == expected)
        #expect(url("https://instagram.com/p/C8xYzAbCdEf") == expected)
    }

    @Test("The igshid a share adds is dropped, so the same reel shared twice is one item")
    func instagramShareParamsDropped() {
        let a = url("https://www.instagram.com/reel/C8xYzAbCdEf/?igshid=MzRlODBiNWFlZA==")
        let b = url("https://www.instagram.com/reel/C8xYzAbCdEf/?igsh=abc123&utm_source=ig_web")
        #expect(a == b)
        #expect(a == "https://www.instagram.com/p/C8xYzAbCdEf/")
    }

    @Test("The /{user}/p/{code}/ form keeps the author but canonicalises the same")
    func instagramAuthorForm() {
        let link = canon("https://www.instagram.com/nasa/p/C8xYzAbCdEf/")
        #expect(link?.url.absoluteString == "https://www.instagram.com/p/C8xYzAbCdEf/")
        #expect(link?.author == "nasa")
    }

    @Test("Shortcodes are case-sensitive and must survive canonicalisation intact")
    func instagramShortcodeCaseIsPreserved() {
        #expect(url("https://www.instagram.com/p/AbCdEfG/") == "https://www.instagram.com/p/AbCdEfG/")
        #expect(url("https://www.instagram.com/p/AbCdEfG/") != url("https://www.instagram.com/p/abcdefg/"))
    }

    // MARK: - YouTube

    @Test("Every YouTube URL shape reduces to one watch link")
    func youtubeShapesCollapse() {
        let expected = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        #expect(url("https://www.youtube.com/watch?v=dQw4w9WgXcQ") == expected)
        #expect(url("https://youtu.be/dQw4w9WgXcQ") == expected)
        #expect(url("https://www.youtube.com/shorts/dQw4w9WgXcQ") == expected)
        #expect(url("https://www.youtube.com/embed/dQw4w9WgXcQ") == expected)
        #expect(url("https://m.youtube.com/watch?v=dQw4w9WgXcQ") == expected)
    }

    @Test("A start timestamp does not file the same video twice")
    func youtubeTimestampDropped() {
        // ?t= is a moment in a video, not a different video. A library dedupes; a bookmark
        // would not, which is the distinction this test exists to hold.
        #expect(url("https://youtu.be/dQw4w9WgXcQ?t=42") == url("https://youtu.be/dQw4w9WgXcQ"))
        #expect(url("https://www.youtube.com/watch?v=dQw4w9WgXcQ&si=xyz") == url("https://youtu.be/dQw4w9WgXcQ"))
    }

    // MARK: - TikTok

    @Test("A full TikTok video URL keeps its author and id")
    func tiktokFullURL() {
        let link = canon("https://www.tiktok.com/@nasa/video/7234567890123456789?is_from_webapp=1&sender_device=pc")
        #expect(link?.url.absoluteString == "https://www.tiktok.com/@nasa/video/7234567890123456789")
        #expect(link?.contentID == "7234567890123456789")
        #expect(link?.author == "nasa")
        #expect(link?.needsNetworkResolution == false)
    }

    @Test("vm./vt. shortlinks are flagged for a redirect rather than guessed at")
    func tiktokShortlinksNeedResolution() {
        #expect(canon("https://vm.tiktok.com/ZMhqKvXYZ/")?.needsNetworkResolution == true)
        #expect(canon("https://vt.tiktok.com/ZSjqKvXYZ/")?.needsNetworkResolution == true)
        #expect(canon("https://www.tiktok.com/t/ZTdqKvXYZ/")?.needsNetworkResolution == true)
    }

    // MARK: - Reddit

    @Test("A full Reddit permalink reduces to /comments/{id}/ and keeps the subreddit")
    func redditPermalink() {
        let link = canon("https://www.reddit.com/r/design/comments/1abc234/some_long_slug_here/")
        #expect(link?.url.absoluteString == "https://www.reddit.com/comments/1abc234/")
        #expect(link?.contentID == "1abc234")
        #expect(link?.author == "r/design")
    }

    @Test("redd.it carries the post id already, so it needs no redirect")
    func redditShortDomainIsDirect() {
        let link = canon("https://redd.it/1abc234")
        #expect(link?.url.absoluteString == "https://www.reddit.com/comments/1abc234/")
        #expect(link?.needsNetworkResolution == false)
    }

    @Test("old.reddit and the /s/ share link are handled differently, and correctly")
    func redditVariants() {
        #expect(url("https://old.reddit.com/r/design/comments/1abc234/slug/")
                == "https://www.reddit.com/comments/1abc234/")
        // /s/ links really are shorteners and cannot be resolved without a hop.
        #expect(canon("https://www.reddit.com/r/design/s/aBcDeFgH")?.needsNetworkResolution == true)
    }

    // MARK: - X

    @Test("twitter.com and the proxy front-ends all normalise onto x.com")
    func xHostsNormalise() {
        let expected = "https://x.com/nasa/status/1234567890"
        #expect(url("https://twitter.com/nasa/status/1234567890") == expected)
        #expect(url("https://x.com/nasa/status/1234567890") == expected)
        #expect(url("https://fxtwitter.com/nasa/status/1234567890") == expected)
        #expect(url("https://mobile.twitter.com/nasa/status/1234567890?s=20") == expected)
    }

    // MARK: - Pinterest, Threads, Vimeo

    @Test("Pinterest pins canonicalise; pin.it needs a hop")
    func pinterest() {
        #expect(url("https://www.pinterest.com/pin/1234567890/") == "https://www.pinterest.com/pin/1234567890/")
        #expect(canon("https://pin.it/aBcDeFg")?.needsNetworkResolution == true)
    }

    @Test("Threads posts keep author and code")
    func threads() {
        let link = canon("https://www.threads.net/@nasa/post/C8xYzAbCdEf")
        #expect(link?.url.absoluteString == "https://www.threads.net/@nasa/post/C8xYzAbCdEf")
        #expect(link?.author == "nasa")
    }

    @Test("Vimeo reduces to the numeric id")
    func vimeo() {
        #expect(url("https://vimeo.com/123456789?share=copy") == "https://vimeo.com/123456789")
    }

    // MARK: - Shape of the input

    @Test("A URL buried in shared prose is found")
    func urlExtractedFromText() {
        // This is the normal case, not the exotic one: TikTok's share sheet sends a sentence.
        let shared = "Check this out https://vm.tiktok.com/ZMhqKvXYZ/ - come watch"
        #expect(canon(shared)?.platform == .tiktok)
        #expect(canon(shared)?.needsNetworkResolution == true)
    }

    @Test("A bare host with no scheme still canonicalises")
    func bareHost() {
        #expect(url("instagram.com/p/C8xYzAbCdEf/") == "https://www.instagram.com/p/C8xYzAbCdEf/")
    }

    @Test("http is upgraded to https so the two never file separately")
    func schemeUpgraded() {
        #expect(url("http://www.youtube.com/watch?v=dQw4w9WgXcQ")
                == "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    }

    @Test("Fragments and trailing slashes do not create duplicates")
    func fragmentsAndSlashes() {
        #expect(url("https://example.com/article/#section") == url("https://example.com/article"))
        #expect(url("https://example.com/article/") == url("https://example.com/article"))
    }

    @Test("Text with no link at all returns nil rather than a bogus row")
    func noURL() {
        #expect(canon("just some words") == nil)
        #expect(canon("") == nil)
        #expect(canon("   ") == nil)
    }

    // MARK: - Things that must NOT collapse

    @Test("Different posts stay different")
    func distinctPostsStayDistinct() {
        #expect(url("https://www.instagram.com/p/AAAAAAA/") != url("https://www.instagram.com/p/BBBBBBB/"))
        #expect(url("https://youtu.be/dQw4w9WgXcQ") != url("https://youtu.be/oHg5SJYRHA0"))
        #expect(url("https://www.reddit.com/comments/1abc234/") != url("https://www.reddit.com/comments/1abc235/"))
    }

    @Test("An unknown site keeps its meaningful query but loses its tracking")
    func genericSiteKeepsRealQuery() {
        // ?id=42 selects the content; ?utm_source does not. Dropping the wrong one here would
        // silently merge two different pages into one row.
        let link = canon("https://example.com/gallery?id=42&utm_source=newsletter&fbclid=xyz")
        #expect(link?.url.absoluteString == "https://example.com/gallery?id=42")
        #expect(link?.platform == .web)
    }
}

/// The durability table drives the entire thumbnail pipeline, so it gets pinned rather than
/// left as a comment that can drift from the code that reads it.
struct PlatformTests {

    @Test("Platforms are detected with or without www., and across alternate hosts")
    func detection() {
        #expect(Platform.detect(host: "www.instagram.com") == .instagram)
        #expect(Platform.detect(host: "youtu.be") == .youtube)
        #expect(Platform.detect(host: "vm.tiktok.com") == .tiktok)
        #expect(Platform.detect(host: "old.reddit.com") == .reddit)
        #expect(Platform.detect(host: "twitter.com") == .x)
        #expect(Platform.detect(host: "cosmos.so") == .cosmos)
        #expect(Platform.detect(host: "example.com") == .web)
    }

    @Test("The three platforms that hand over nothing are marked unreachable")
    func unreachablePlatforms() {
        // Instagram, Pinterest and X serve no og:image to an unauthenticated client. The
        // fallback tile is their designed state, so this must stay true or the pipeline will
        // sit retrying a fetch that can never succeed.
        #expect(Platform.instagram.thumbnailDurability == .unreachable)
        #expect(Platform.pinterest.thumbnailDurability == .unreachable)
        #expect(Platform.x.thumbnailDurability == .unreachable)
    }

    @Test("TikTok is expiring, which is what forces caching bytes at save time")
    func tiktokExpires() {
        #expect(Platform.tiktok.thumbnailDurability == .expiring)
    }

    @Test("YouTube and Reddit are stable")
    func stablePlatforms() {
        #expect(Platform.youtube.thumbnailDurability == .stable)
        #expect(Platform.reddit.thumbnailDurability == .stable)
    }
}
