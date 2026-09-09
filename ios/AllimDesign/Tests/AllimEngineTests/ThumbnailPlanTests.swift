import Testing
import Foundation
@testable import AllimEngine

/// The per-platform table here came out of research into what each site actually serves an
/// unauthenticated client. Getting it wrong is expensive in both directions: a missing plan
/// means a blank tile forever, and a plan for a platform that serves nothing means the queue
/// retries a fetch that can never succeed.
struct ThumbnailPlanTests {

    private func plan(_ raw: String) -> ThumbnailPlan? {
        LinkCanonicaliser.canonicalise(raw).map(ThumbnailResolver.plan(for:))
    }

    @Test("YouTube thumbnails are derived from the id, best quality first")
    func youtubeWalksQualities() {
        guard case .directCandidates(let urls)? = plan("https://youtu.be/dQw4w9WgXcQ") else {
            Issue.record("expected direct candidates"); return
        }
        #expect(urls.map(\.absoluteString) == [
            "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg",
            "https://i.ytimg.com/vi/dQw4w9WgXcQ/sddefault.jpg",
            "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
        ])
    }

    @Test("TikTok goes through oEmbed, which is public and needs no key")
    func tiktokUsesOEmbed() {
        guard case .oEmbed(let url)? = plan("https://www.tiktok.com/@nasa/video/7234567890123456789") else {
            Issue.record("expected oEmbed"); return
        }
        #expect(url.absoluteString.hasPrefix("https://www.tiktok.com/oembed?url="))
    }

    @Test("The three platforms that serve nothing are marked unavailable, not queued")
    func unreachablePlatformsGetNoPlan() {
        // If any of these ever becomes a fetch plan, the enrichment queue will retry forever
        // against a wall. The typographic tile is the intended outcome.
        #expect(plan("https://www.instagram.com/p/C8xYzAbCdEf/") == .unavailable)
        #expect(plan("https://www.pinterest.com/pin/1234567890/") == .unavailable)
        #expect(plan("https://x.com/nasa/status/1234567890") == .unavailable)
    }

    @Test("Reddit and unknown sites go through Open Graph")
    func openGraphSites() {
        guard case .openGraph? = plan("https://www.reddit.com/r/design/comments/1abc234/slug/") else {
            Issue.record("expected openGraph for reddit"); return
        }
        guard case .openGraph? = plan("https://example.com/article") else {
            Issue.record("expected openGraph for web"); return
        }
    }

    // MARK: - The Reddit rewrite

    @Test("A signed preview.redd.it URL is rewritten onto the permanent host")
    func redditPreviewRewrite() {
        let signed = URL(string: "https://preview.redd.it/abc123def.jpg?width=640&crop=smart&auth=deadbeef&s=cafe")!
        let permanent = ThumbnailResolver.permanentRedditURL(signed)
        #expect(permanent.absoluteString == "https://i.redd.it/abc123def.jpg")
    }

    @Test("external-preview is rewritten too, and unrelated hosts are left alone")
    func redditRewriteScope() {
        let external = URL(string: "https://external-preview.redd.it/xyz.png?auth=abc")!
        #expect(ThumbnailResolver.permanentRedditURL(external).absoluteString == "https://i.redd.it/xyz.png")

        // Must not touch anything else -- a blanket host rewrite would corrupt every other
        // platform's thumbnail URL.
        let untouched = URL(string: "https://i.ytimg.com/vi/abc/hqdefault.jpg")!
        #expect(ThumbnailResolver.permanentRedditURL(untouched) == untouched)

        let alreadyPermanent = URL(string: "https://i.redd.it/abc.jpg")!
        #expect(ThumbnailResolver.permanentRedditURL(alreadyPermanent) == alreadyPermanent)
    }

    // MARK: - Storage keys

    @Test("The storage key is stable for a post and independent of its image URL")
    func storageKeyIsPostKeyed() {
        let post = URL(string: "https://www.tiktok.com/@nasa/video/7234567890123456789")!
        #expect(StorageKey.forPost(post) == StorageKey.forPost(post))
        #expect(StorageKey.forPost(post).count == 32)
        #expect(StorageKey.forPost(post) != StorageKey.forPost(URL(string: "https://www.tiktok.com/@nasa/video/1")!))
    }
}
