import Testing
import Foundation
@testable import QuokkaEngine

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

    @Test("The platforms that serve nothing are marked unavailable, not queued")
    func unreachablePlatformsGetNoPlan() {
        // If any of these ever becomes a fetch plan, the enrichment queue will retry forever
        // against a wall. The typographic tile is the intended outcome.
        #expect(plan("https://www.instagram.com/p/C8xYzAbCdEf/") == .unavailable)
        #expect(plan("https://x.com/nasa/status/1234567890") == .unavailable)
    }

    @Test("Pinterest's small rendition is swapped for the 736px one, and nothing else is touched")
    func largerPinterestImage() {
        let small = URL(string: "https://i.pinimg.com/236x/32/68/65/3268.jpg")!
        #expect(ThumbnailResolver.largerPinterestImage(small).absoluteString == "https://i.pinimg.com/736x/32/68/65/3268.jpg")
        let other = URL(string: "https://i.ytimg.com/vi/x/236x/hq.jpg")!
        #expect(ThumbnailResolver.largerPinterestImage(other) == other)
    }

    @Test("Title and creator come from oEmbed where it is open, and nowhere else")
    func metadataEndpoints() {
        func endpoint(_ raw: String) -> String? {
            LinkCanonicaliser.canonicalise(raw).flatMap(ThumbnailResolver.metadataEndpoint)?.absoluteString
        }
        #expect(endpoint("https://youtu.be/dQw4w9WgXcQ")?.hasPrefix("https://www.youtube.com/oembed?format=json&url=") == true)
        #expect(endpoint("https://www.pinterest.com/pin/1234567890/")?.hasPrefix("https://www.pinterest.com/oembed.json") == true)
        #expect(endpoint("https://www.instagram.com/p/C8xYzAbCdEf/") == nil)
        #expect(endpoint("https://x.com/nasa/status/1234567890") == nil)
    }

    @Test("oEmbed metadata keeps title and author, and drops empties")
    func parseMetadata() {
        let youtube = Data(#"{"title":"Never Gonna Give You Up","author_name":"Rick Astley","type":"video"}"#.utf8)
        #expect(OEmbedMetadata.parse(youtube) == OEmbedMetadata(title: "Never Gonna Give You Up", author: "Rick Astley"))
        #expect(OEmbedMetadata.parse(Data(#"{"title":"  ","author_name":""}"#.utf8)) == nil)
        #expect(OEmbedMetadata.parse(Data("<html>login</html>".utf8)) == nil)
    }

    @Test("A Pinterest pin goes through Pinterest's oEmbed")
    func pinterestUsesOEmbed() {
        guard case .oEmbed(let url)? = plan("https://www.pinterest.com/pin/1234567890/") else {
            Issue.record("expected oEmbed"); return
        }
        #expect(url.absoluteString.hasPrefix("https://www.pinterest.com/oembed.json?url="))
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
