import Foundation
import Testing
import GRDB
import CryptoKit
@testable import Simpod

/// Hard gates A1–A6 from plan `floating-beaming-dahl.md` —
/// "To Do Nothing At All". Verifies the body-hash short-circuit, ETag-rot
/// defense, no-op write skip, changed-feed parse path, nil-hash fallback,
/// and the v5 migration on a synthesized v4-state DB.
@Suite("Feed Refresh Efficiency")
struct FeedRefreshEfficiencyTests {

    // MARK: - Fixture

    private static let sampleFeedXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
    <channel>
    <title>Test Podcast</title>
    <link>https://example.test</link>
    <description>Test description</description>
    <itunes:author>Test Author</itunes:author>
    <item>
    <title>Episode 1</title>
    <guid>ep-guid-1</guid>
    <enclosure url="https://example.test/ep1.mp3" type="audio/mpeg" length="1000"/>
    <pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate>
    </item>
    <item>
    <title>Episode 2</title>
    <guid>ep-guid-2</guid>
    <enclosure url="https://example.test/ep2.mp3" type="audio/mpeg" length="1000"/>
    <pubDate>Tue, 02 Jan 2024 00:00:00 GMT</pubDate>
    </item>
    </channel>
    </rss>
    """

    private static var sampleData: Data { Data(sampleFeedXML.utf8) }
    private static var sampleHash: String { FeedEngine.sha256Hex(sampleData) }

    private static func seedPodcast(
        in store: DataStore,
        feedURL: String = "https://example.test/feed",
        etag: String? = nil,
        lastModified: String? = nil,
        feedBodyHash: String? = nil
    ) throws -> Podcast {
        let podcast = Podcast(
            feedURL: feedURL,
            title: "Test Podcast",
            author: "Test Author",
            httpETag: etag,
            httpLastModified: lastModified,
            feedBodyHash: feedBodyHash
        )
        try store.savePodcast(podcast)
        return podcast
    }

    // MARK: - A1: body-hash short-circuit on unchanged feed

    @Test func bodyHashShortCircuitsOnUnchangedFeed() async throws {
        let store = try DataStore.preview()
        let engine = FeedEngine(dataStore: store)
        let podcast = try Self.seedPodcast(in: store)

        let baselineSaveCount = store.saveRefreshCount

        // Stub: 200 + same body twice, no ETag.
        engine.debugFetchOverride = { _, _, _, knownHash in
            let bodyHash = FeedEngine.sha256Hex(Self.sampleData)
            if let knownHash, knownHash == bodyHash {
                return .unchangedBody(etag: nil, lastModified: nil)
            }
            return .changed(data: Self.sampleData, etag: nil, lastModified: nil, hash: bodyHash)
        }

        // First refresh — must parse, insert 2 episodes, populate hash.
        _ = try await engine.refresh(podcast: podcast)
        let afterFirst = try #require(try store.fetchPodcast(byID: podcast.id))
        #expect(afterFirst.feedBodyHash == Self.sampleHash)
        #expect(store.saveRefreshCount == baselineSaveCount + 1)
        let firstEpisodeCount = try store.fetchEpisodes(for: podcast.id).count
        #expect(firstEpisodeCount == 2)

        // Second refresh — body identical, hash matches. No write, no parse.
        _ = try await engine.refresh(podcast: afterFirst)
        #expect(store.saveRefreshCount == baselineSaveCount + 1)
        let secondEpisodeCount = try store.fetchEpisodes(for: podcast.id).count
        #expect(secondEpisodeCount == 2)
    }

    // MARK: - A2: ETag-rot defense

    @Test func etagRotDefensePreservesStoredValidator() async throws {
        let store = try DataStore.preview()
        let engine = FeedEngine(dataStore: store)
        let podcast = try Self.seedPodcast(in: store, etag: "W/\"abc123\"")

        // First call: server returns the ETag.
        // Second call: server omits the ETag header (Cloudflare strip).
        final class Counter: @unchecked Sendable {
            private let lock = NSLock()
            private var value = 0
            func next() -> Int { lock.lock(); defer { lock.unlock() }; value += 1; return value }
        }
        let counter = Counter()
        engine.debugFetchOverride = { _, _, _, knownHash in
            let n = counter.next()
            let bodyHash = FeedEngine.sha256Hex(Self.sampleData)
            let etag: String? = (n == 1) ? "W/\"abc123\"" : nil
            let lastModified: String? = (n == 1) ? "Wed, 01 Jan 2025 00:00:00 GMT" : nil
            if let knownHash, knownHash == bodyHash {
                return .unchangedBody(etag: etag, lastModified: lastModified)
            }
            return .changed(data: Self.sampleData, etag: etag, lastModified: lastModified, hash: bodyHash)
        }

        _ = try await engine.refresh(podcast: podcast)
        let afterFirst = try #require(try store.fetchPodcast(byID: podcast.id))
        #expect(afterFirst.httpETag == "W/\"abc123\"")
        #expect(afterFirst.httpLastModified == "Wed, 01 Jan 2025 00:00:00 GMT")

        _ = try await engine.refresh(podcast: afterFirst)
        let afterSecond = try #require(try store.fetchPodcast(byID: podcast.id))
        // Critical: validator NOT clobbered to nil.
        #expect(afterSecond.httpETag == "W/\"abc123\"")
        #expect(afterSecond.httpLastModified == "Wed, 01 Jan 2025 00:00:00 GMT")
    }

    // MARK: - A3: no-op write skip on identical body+validators

    @Test func noOpWriteSkipOnUnchangedPodcast() async throws {
        let store = try DataStore.preview()
        let engine = FeedEngine(dataStore: store)
        // Pre-populate with hash matching what server will return.
        let podcast = try Self.seedPodcast(
            in: store,
            etag: "E",
            lastModified: "Wed, 01 Jan 2025 00:00:00 GMT",
            feedBodyHash: Self.sampleHash
        )
        let baselineSaveCount = store.saveRefreshCount
        // Read canonical (post-SQLite-roundtrip) baseline to avoid Date precision drift.
        let stored = try #require(try store.fetchPodcast(byID: podcast.id))
        let baselineLastModified = stored.lastModified

        engine.debugFetchOverride = { _, _, _, knownHash in
            let bodyHash = FeedEngine.sha256Hex(Self.sampleData)
            if let knownHash, knownHash == bodyHash {
                return .unchangedBody(etag: "E", lastModified: "Wed, 01 Jan 2025 00:00:00 GMT")
            }
            return .changed(data: Self.sampleData, etag: "E", lastModified: "Wed, 01 Jan 2025 00:00:00 GMT", hash: bodyHash)
        }

        _ = try await engine.refresh(podcast: stored)
        #expect(store.saveRefreshCount == baselineSaveCount)
        let after = try #require(try store.fetchPodcast(byID: podcast.id))
        #expect(after.lastModified == baselineLastModified)
        #expect(after.feedBodyHash == Self.sampleHash)
    }

    // MARK: - A4: changed feed still parses and updates

    @Test func changedFeedParsesAndUpdates() async throws {
        let store = try DataStore.preview()
        let engine = FeedEngine(dataStore: store)
        let podcast = try Self.seedPodcast(in: store, feedBodyHash: "stale-hash-value")
        let baselineSaveCount = store.saveRefreshCount

        engine.debugFetchOverride = { _, _, _, knownHash in
            let bodyHash = FeedEngine.sha256Hex(Self.sampleData)
            if let knownHash, knownHash == bodyHash {
                return .unchangedBody(etag: nil, lastModified: nil)
            }
            return .changed(data: Self.sampleData, etag: nil, lastModified: nil, hash: bodyHash)
        }

        let newEpisodes = try await engine.refresh(podcast: podcast)
        #expect(newEpisodes.count == 2)
        let after = try #require(try store.fetchPodcast(byID: podcast.id))
        #expect(after.feedBodyHash == Self.sampleHash)
        #expect(store.saveRefreshCount == baselineSaveCount + 1)
        #expect(try store.fetchEpisodes(for: podcast.id).count == 2)
    }

    // MARK: - A5: nil feedBodyHash falls back to normal refresh

    @Test func nilFeedBodyHashFallsBackToNormalRefresh() async throws {
        let store = try DataStore.preview()
        let engine = FeedEngine(dataStore: store)
        let podcast = try Self.seedPodcast(in: store, feedBodyHash: nil)
        let baselineSaveCount = store.saveRefreshCount

        engine.debugFetchOverride = { _, _, _, knownHash in
            let bodyHash = FeedEngine.sha256Hex(Self.sampleData)
            if let knownHash, knownHash == bodyHash {
                return .unchangedBody(etag: nil, lastModified: nil)
            }
            return .changed(data: Self.sampleData, etag: nil, lastModified: nil, hash: bodyHash)
        }

        // First refresh: nil hash → fallback to .changed → parse + insert.
        _ = try await engine.refresh(podcast: podcast)
        let afterFirst = try #require(try store.fetchPodcast(byID: podcast.id))
        #expect(afterFirst.feedBodyHash == Self.sampleHash)
        #expect(store.saveRefreshCount == baselineSaveCount + 1)
        #expect(try store.fetchEpisodes(for: podcast.id).count == 2)

        // Second refresh: hash now populated, body identical → short-circuit.
        _ = try await engine.refresh(podcast: afterFirst)
        #expect(store.saveRefreshCount == baselineSaveCount + 1)
        #expect(try store.fetchEpisodes(for: podcast.id).count == 2)
    }

    // MARK: - A6: migration succeeds on synthesized v4-state DB

    @Test func migrationAddsFeedBodyHashOnPreV5Database() throws {
        // Build a v4-state DB by manually marking v1–v4 applied and creating
        // the v4 podcast table schema with one row + an episode row.
        let queue = try DatabaseQueue()
        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE grdb_migrations (identifier TEXT PRIMARY KEY NOT NULL);
                INSERT INTO grdb_migrations VALUES
                    ('v1-initial'),
                    ('v2-hidden-until'),
                    ('v3-fts5-search'),
                    ('v4-conditional-get');

                CREATE TABLE podcast (
                    id TEXT PRIMARY KEY NOT NULL,
                    feedURL TEXT NOT NULL UNIQUE,
                    title TEXT NOT NULL,
                    author TEXT NOT NULL DEFAULT '',
                    artworkURL TEXT,
                    podcastDescription TEXT NOT NULL DEFAULT '',
                    lastRefreshed DATETIME,
                    lastModified DATETIME NOT NULL,
                    httpETag TEXT,
                    httpLastModified TEXT
                );

                CREATE TABLE episode (
                    id TEXT PRIMARY KEY NOT NULL,
                    podcastID TEXT NOT NULL REFERENCES podcast(id) ON DELETE CASCADE,
                    guid TEXT NOT NULL DEFAULT '',
                    title TEXT NOT NULL,
                    audioURL TEXT NOT NULL,
                    localFilePath TEXT,
                    duration DOUBLE NOT NULL DEFAULT 0,
                    playbackPosition DOUBLE NOT NULL DEFAULT 0,
                    publishedDate DATETIME NOT NULL,
                    episodeDescription TEXT NOT NULL DEFAULT '',
                    status TEXT NOT NULL DEFAULT 'inbox',
                    downloadProgress DOUBLE NOT NULL DEFAULT 0,
                    lastModified DATETIME NOT NULL,
                    hiddenUntil DATETIME,
                    UNIQUE(podcastID, guid)
                );

                CREATE TABLE queueItem (
                    id TEXT PRIMARY KEY NOT NULL,
                    episodeID TEXT NOT NULL UNIQUE REFERENCES episode(id) ON DELETE CASCADE,
                    "order" INTEGER NOT NULL,
                    addedDate DATETIME NOT NULL,
                    lastModified DATETIME NOT NULL
                );

                CREATE TABLE tag (
                    id TEXT PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL UNIQUE,
                    color TEXT NOT NULL DEFAULT '#007AFF'
                );

                CREATE TABLE episodeTag (
                    episodeID TEXT NOT NULL REFERENCES episode(id) ON DELETE CASCADE,
                    tagID TEXT NOT NULL REFERENCES tag(id) ON DELETE CASCADE,
                    PRIMARY KEY (episodeID, tagID)
                );

                CREATE TABLE podcastTag (
                    podcastID TEXT NOT NULL REFERENCES podcast(id) ON DELETE CASCADE,
                    tagID TEXT NOT NULL REFERENCES tag(id) ON DELETE CASCADE,
                    PRIMARY KEY (podcastID, tagID)
                );
                """)

            // Insert one podcast + one episode to verify they survive migration.
            try db.execute(
                sql: """
                INSERT INTO podcast (id, feedURL, title, author, podcastDescription, lastModified)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    "11111111-1111-1111-1111-111111111111",
                    "https://example.test/preexisting",
                    "Pre-existing Podcast",
                    "Pre-existing Author",
                    "",
                    Date.now
                ]
            )
            try db.execute(
                sql: """
                INSERT INTO episode (id, podcastID, guid, title, audioURL, publishedDate, lastModified)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    "22222222-2222-2222-2222-222222222222",
                    "11111111-1111-1111-1111-111111111111",
                    "preexisting-ep",
                    "Pre-existing Episode",
                    "https://example.test/ep.mp3",
                    Date.now,
                    Date.now
                ]
            )
        }

        // Open via DataStore — this runs only the v5 migration.
        _ = try DataStore(db: queue)

        // Verify column exists and pre-existing rows survive via raw SQL —
        // avoids coupling the migration gate to GRDB's UUID encoding
        // (Codable UUIDs round-trip through a different representation than
        // raw TEXT inserts, so fetchOne-by-UUID is not a reliable probe here).
        try queue.read { db in
            let columns = try Row.fetchAll(db, sql: "PRAGMA table_info(podcast)")
                .compactMap { $0["name"] as String? }
            #expect(columns.contains("feedBodyHash"))

            let podcastRow = try Row.fetchOne(
                db,
                sql: "SELECT title, feedBodyHash FROM podcast WHERE id = ?",
                arguments: ["11111111-1111-1111-1111-111111111111"]
            )
            let fetchedRow = try #require(podcastRow)
            #expect(fetchedRow["title"] as String? == "Pre-existing Podcast")
            #expect(fetchedRow["feedBodyHash"] as String? == nil)

            let episodeCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM episode WHERE guid = ?",
                arguments: ["preexisting-ep"]
            )
            #expect(episodeCount == 1)
        }
    }
}
