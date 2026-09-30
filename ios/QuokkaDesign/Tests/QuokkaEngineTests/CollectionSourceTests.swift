import Testing
import Foundation
@testable import QuokkaEngine

/// Pasting a collection is how a library starts with hundreds of pictures. These pin which
/// links count as collections and what is read out of each feed.
struct CollectionSourceTests {

    @Test("Pinterest boards and profiles are collections; pins and Pinterest's own pages are not")
    func pinterestDetection() {
        #expect(CollectionSource.detect("https://www.pinterest.com/matthew/kitchens/") == .pinterestBoard(user: "matthew", board: "kitchens"))
        #expect(CollectionSource.detect("https://pinterest.com/matthew/") == .pinterestProfile(user: "matthew"))
        #expect(CollectionSource.detect("https://uk.pinterest.com/matthew/kitchens") == .pinterestBoard(user: "matthew", board: "kitchens"))
        #expect(CollectionSource.detect("https://www.pinterest.com/pin/1234567890/") == nil)
        #expect(CollectionSource.detect("https://www.pinterest.com/ideas/kitchens/123/") == nil)
        #expect(CollectionSource.detect("https://www.pinterest.com/search/pins/?q=kitchen") == nil)
    }

    @Test("An Are.na channel is a collection; a block or another site is not")
    func arenaDetection() {
        #expect(CollectionSource.detect("https://www.are.na/matthew-park/references") == .arenaChannel(slug: "references"))
        #expect(CollectionSource.detect("https://www.are.na/block/3235876") == nil)
        #expect(CollectionSource.detect("https://www.youtube.com/watch?v=dQw4w9WgXcQ") == nil)
        #expect(CollectionSource.detect("not a link") == nil)
    }

    @Test("Feeds are the board's RSS, the profile's RSS, and the channel's contents")
    func feeds() {
        #expect(CollectionSource.pinterestBoard(user: "m", board: "k").feedURL.absoluteString == "https://www.pinterest.com/m/k.rss")
        #expect(CollectionSource.pinterestProfile(user: "m").feedURL.absoluteString == "https://www.pinterest.com/m/feed.rss")
        #expect(CollectionSource.arenaChannel(slug: "refs").feedURL.absoluteString == "https://api.are.na/v2/channels/refs/contents?per=100&page=1")
    }

    @Test("A Pinterest RSS item gives its pin link and its title, entities decoded")
    func pinterestRSS() {
        let xml = """
            <rss><channel><title>Kitchens</title>
            <item><title>Warm oak &amp; steel</title><link>https://www.pinterest.com/pin/111/</link>
            <description>&lt;img src=&quot;https://i.pinimg.com/236x/aa.jpg&quot;&gt;</description></item>
            <item><title></title><link>https://www.pinterest.com/pin/222/</link></item>
            <item><title>Not a pin</title><link>https://example.com/</link></item>
            </channel></rss>
            """
        let posts = CollectionSource.pinterestBoard(user: "m", board: "k").posts(from: Data(xml.utf8))
        #expect(posts == [
            CollectedPost(url: "https://www.pinterest.com/pin/111/", title: "Warm oak & steel"),
            CollectedPost(url: "https://www.pinterest.com/pin/222/", title: nil),
        ])
    }

    @Test("Only Are.na blocks with a picture are imported, as block pages")
    func arenaContents() {
        let json = """
            {"contents":[
              {"id":1,"title":"Asimov","image":{"display":{"url":"https://images.are.na/a"}}},
              {"id":2,"title":"Just words","image":null,"class":"Text"},
              {"id":3,"title":"","image":{"display":{"url":"https://images.are.na/c"}}}
            ]}
            """
        let posts = CollectionSource.arenaChannel(slug: "refs").posts(from: Data(json.utf8))
        #expect(posts == [
            CollectedPost(url: "https://www.are.na/block/1", title: "Asimov"),
            CollectedPost(url: "https://www.are.na/block/3", title: nil),
        ])
        #expect(CollectionSource.arenaChannel(slug: "refs").posts(from: Data("oops".utf8)).isEmpty)
    }
}
