import Foundation
import Testing
@testable import Simpod

@Suite("OPMLParser")
struct OPMLTests {

    // MARK: - 1. Valid OPML with 3 feeds

    @Test func parseValidOPMLWithThreeFeeds() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
          <head><title>My Podcasts</title></head>
          <body>
            <outline text="Accidental Tech Podcast" xmlUrl="https://atp.fm/episodes?format=rss"/>
            <outline text="Cortex" xmlUrl="https://www.relay.fm/cortex/feed"/>
            <outline text="Hardcore History" xmlUrl="https://feeds.feedburner.com/dancarlin/history"/>
          </body>
        </opml>
        """
        let data = Data(xml.utf8)

        let urls = try OPMLParser.parseFeedURLs(from: data)

        #expect(urls.count == 3)
        #expect(urls[0] == "https://atp.fm/episodes?format=rss")
        #expect(urls[1] == "https://www.relay.fm/cortex/feed")
        #expect(urls[2] == "https://feeds.feedburner.com/dancarlin/history")
    }

    // MARK: - 2. Nested outline groups (category folders)

    @Test func parseOPMLWithNestedGroups() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
          <head><title>Categorised Podcasts</title></head>
          <body>
            <outline text="Technology">
              <outline text="Accidental Tech Podcast" xmlUrl="https://atp.fm/episodes?format=rss"/>
              <outline text="Cortex" xmlUrl="https://www.relay.fm/cortex/feed"/>
            </outline>
            <outline text="Comedy">
              <outline text="My Brother My Brother And Me" xmlUrl="https://feeds.maximumfun.org/mbmbam/MBMBAMpodcast.xml"/>
            </outline>
          </body>
        </opml>
        """
        let data = Data(xml.utf8)

        let urls = try OPMLParser.parseFeedURLs(from: data)

        #expect(urls.count == 3)
        #expect(urls.contains("https://atp.fm/episodes?format=rss"))
        #expect(urls.contains("https://www.relay.fm/cortex/feed"))
        #expect(urls.contains("https://feeds.maximumfun.org/mbmbam/MBMBAMpodcast.xml"))
    }

    // MARK: - 3. Empty OPML (no feeds)

    @Test func parseEmptyOPMLThrowsNoFeedsFound() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
          <head><title>Empty</title></head>
          <body></body>
        </opml>
        """
        let data = Data(xml.utf8)

        #expect(throws: OPMLError.noFeedsFound) {
            try OPMLParser.parseFeedURLs(from: data)
        }
    }

    // MARK: - 4. Invalid XML

    @Test func parseInvalidXMLThrowsParseFailure() throws {
        let data = Data("not xml at all <<<>>>".utf8)

        #expect(throws: (any Error).self) {
            try OPMLParser.parseFeedURLs(from: data)
        }

        // Verify it is specifically an OPMLError.parseFailure
        do {
            _ = try OPMLParser.parseFeedURLs(from: data)
        } catch OPMLError.parseFailure {
            // expected — pass
        } catch {
            Issue.record("Expected OPMLError.parseFailure but got \(error)")
        }
    }

    // MARK: - 5. Duplicate URLs are deduplicated

    @Test func parseDuplicateURLsReturnsDeduplicatedResult() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
          <head><title>Duplicates</title></head>
          <body>
            <outline text="ATP First" xmlUrl="https://atp.fm/episodes?format=rss"/>
            <outline text="ATP Again" xmlUrl="https://atp.fm/episodes?format=rss"/>
          </body>
        </opml>
        """
        let data = Data(xml.utf8)

        let urls = try OPMLParser.parseFeedURLs(from: data)

        #expect(urls.count == 1)
        #expect(urls[0] == "https://atp.fm/episodes?format=rss")
    }
}
