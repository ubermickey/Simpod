import CloudKit
import Foundation
import Testing
@testable import Simpod

/// Characterization tests for SyncEngine ↔ DataStore handoff around
/// CloudKit `encodedSystemFields`. Exercises pure encode/decode/apply
/// paths via the test-only `init(skipCKSetup: true)` initializer; no
/// real CKSyncEngine is constructed.
@Suite("SyncEngine — encodedSystemFields lifecycle")
struct SyncEngineCharacterizationTests {

    // MARK: - Helpers

    private func makeStore() throws -> DataStore { try DataStore.preview() }

    private func makeEngine(_ store: DataStore) -> SyncEngine {
        SyncEngine(dataStore: store, skipCKSetup: true)
    }

    /// Build a CKRecord for a given UUID/recordType. The act of constructing the
    /// record assigns a recordID; encoding then decoding must preserve that ID.
    private func makeRecord(
        recordType: String,
        uuid: UUID,
        zoneName: String = "SimpodZone"
    ) -> CKRecord {
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let recordID = CKRecord.ID(recordName: uuid.uuidString, zoneID: zoneID)
        return CKRecord(recordType: recordType, recordID: recordID)
    }

    /// Populate the CKRecord with the minimum fields applyFetchedRecord
    /// requires for a valid Podcast decode.
    private func populatePodcastFields(_ record: CKRecord, title: String = "From CK") {
        record["feedURL"] = "https://example.com/feed.xml" as CKRecordValue
        record["title"] = title as CKRecordValue
        record["author"] = "Author" as CKRecordValue
        record["podcastDescription"] = "Desc" as CKRecordValue
        record["lastModified"] = Date() as CKRecordValue
    }

    // MARK: - C1: encodedSystemFields round-trip on inbound apply

    @Test("C1 — applyFetchedRecord persists encodedSystemFields blob alongside model")
    func systemFieldsRoundTrip() throws {
        let store = try makeStore()
        let engine = makeEngine(store)

        let id = UUID()
        let record = makeRecord(recordType: "Podcast", uuid: id)
        populatePodcastFields(record)

        engine.applyFetchedRecord(record)

        let fetched = try #require(try store.fetchPodcast(byID: id))
        let blob = try #require(fetched.cloudKitSystemFields, "Blob must be persisted")
        #expect(!blob.isEmpty, "Blob must be non-empty")

        // Re-decode the blob and verify recordID round-tripped.
        let coder = try NSKeyedUnarchiver(forReadingFrom: blob)
        coder.requiresSecureCoding = true
        let decoded = try #require(CKRecord(coder: coder))
        coder.finishDecoding()
        #expect(decoded.recordID.recordName == id.uuidString)
        #expect(decoded.recordType == "Podcast")
    }

    // MARK: - C2: outbound rehydration uses stored systemFields

    @Test("C2 — ckRecord(for:) rehydrates from stored blob, preserving identity")
    func outboundRehydration() throws {
        let store = try makeStore()
        let engine = makeEngine(store)

        let id = UUID()
        let record = makeRecord(recordType: "Podcast", uuid: id)
        populatePodcastFields(record, title: "Server Title")
        let blob = encodeSystemFields(record)

        // Seed a podcast with a known systemFields blob and a different local title.
        var podcast = Podcast(id: id, feedURL: "https://example.com/feed.xml", title: "Local Title")
        podcast.cloudKitSystemFields = blob
        try store.savePodcast(podcast)

        // Resolve as if SyncEngine were preparing an outbound batch.
        let zoneID = CKRecordZone.ID(zoneName: "SimpodZone", ownerName: CKCurrentUserDefaultName)
        let resolved = try #require(
            engine.resolveRecord(for: CKRecord.ID(recordName: id.uuidString, zoneID: zoneID))
        )

        // Identity preserved (rehydrated, not freshly constructed).
        #expect(resolved.recordID.recordName == id.uuidString)
        // Local mutation applied on top of the rehydrated record.
        #expect(resolved["title"] as? String == "Local Title")
    }

    // MARK: - C3: saveSystemFields does not mark dirty

    @Test("C3 — saveSystemFields persists blob without triggering markDirty")
    func saveSystemFieldsBypassesSync() throws {
        let store = try makeStore()
        let recorder = RecordingSyncCoordinator()
        store.syncCoordinator = recorder

        let podcast = Podcast(feedURL: "https://example.com/feed.xml", title: "P")
        try store.savePodcast(podcast)
        recorder.events.removeAll() // Discard the savePodcast notification

        let blob = Data([0xCA, 0xFE, 0xBA, 0xBE])
        try store.saveSystemFields(podcastID: podcast.id, data: blob)

        #expect(recorder.events.isEmpty, "saveSystemFields must not enqueue sync events")
        let fetched = try #require(try store.fetchPodcast(byID: podcast.id))
        #expect(fetched.cloudKitSystemFields == blob)
    }

    // MARK: - C4: saveFromSync does not mark dirty

    @Test("C4 — saveFromSync(podcast:) does not trigger markDirty")
    func saveFromSyncPodcastBypassesSync() throws {
        let store = try makeStore()
        let recorder = RecordingSyncCoordinator()
        store.syncCoordinator = recorder

        let podcast = Podcast(feedURL: "https://example.com/feed.xml", title: "FromSync")
        try store.saveFromSync(podcast: podcast, systemFields: nil)

        #expect(recorder.events.isEmpty, "saveFromSync must not enqueue sync events")
        #expect(try store.fetchPodcast(byID: podcast.id) != nil)
    }

    @Test("C4 — saveFromSync(episode:) does not trigger markDirty")
    func saveFromSyncEpisodeBypassesSync() throws {
        let store = try makeStore()
        let podcast = Podcast(feedURL: "https://example.com/feed.xml", title: "P")
        try store.savePodcast(podcast)

        let recorder = RecordingSyncCoordinator()
        store.syncCoordinator = recorder

        let episode = Episode(podcastID: podcast.id, title: "E", audioURL: "https://example.com/e.mp3")
        try store.saveFromSync(episode: episode, systemFields: nil)

        #expect(recorder.events.isEmpty)
        #expect(try store.fetchEpisode(byID: episode.id) != nil)
    }

    @Test("C4 — saveFromSync(queueItem:) does not trigger markDirty")
    func saveFromSyncQueueItemBypassesSync() throws {
        let store = try makeStore()
        let podcast = Podcast(feedURL: "https://example.com/feed.xml", title: "P")
        try store.savePodcast(podcast)
        let episode = Episode(podcastID: podcast.id, title: "E", audioURL: "https://example.com/e.mp3")
        try store.saveEpisode(episode)

        let recorder = RecordingSyncCoordinator()
        store.syncCoordinator = recorder

        let item = QueueItem(episodeID: episode.id, order: 0)
        try store.saveFromSync(queueItem: item, systemFields: nil)

        #expect(recorder.events.isEmpty)
        #expect(try store.fetchQueueItem(byID: item.id) != nil)
    }

    // MARK: - C5: model + systemFields land atomically on inbound apply

    @Test("C5 — applyFetchedRecord writes model + blob in one row")
    func atomicInboundApply() throws {
        let store = try makeStore()
        let engine = makeEngine(store)

        let id = UUID()
        let record = makeRecord(recordType: "Episode", uuid: id)
        let podcastID = UUID()
        // Seed the parent podcast so any FK refs would succeed (defensive).
        try store.savePodcast(Podcast(id: podcastID, feedURL: "https://example.com/feed.xml", title: "P"))

        record["podcastID"] = podcastID.uuidString as CKRecordValue
        record["guid"] = "guid-1" as CKRecordValue
        record["title"] = "From CK" as CKRecordValue
        record["audioURL"] = "https://example.com/e.mp3" as CKRecordValue
        record["duration"] = 120.0 as CKRecordValue
        record["playbackPosition"] = 0.0 as CKRecordValue
        record["publishedDate"] = Date() as CKRecordValue
        record["episodeDescription"] = "Desc" as CKRecordValue
        record["status"] = EpisodeStatus.inbox.rawValue as CKRecordValue
        record["lastModified"] = Date() as CKRecordValue

        engine.applyFetchedRecord(record)

        let fetched = try #require(try store.fetchEpisode(byID: id))
        #expect(fetched.title == "From CK")
        #expect(fetched.cloudKitSystemFields != nil)
        #expect(!(fetched.cloudKitSystemFields?.isEmpty ?? true))
    }

    // MARK: - Helpers

    private func encodeSystemFields(_ record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        return coder.encodedData
    }
}

/// Test double for SyncCoordinator — appends every notification to `events`
/// so wiring tests can assert exact sequences.
final class RecordingSyncCoordinator: SyncCoordinator, @unchecked Sendable {
    enum Event: Equatable {
        case dirty(UUID)
        case deleted(UUID)
    }

    private let lock = NSLock()
    private var _events: [Event] = []

    var events: [Event] {
        get { lock.lock(); defer { lock.unlock() }; return _events }
        set { lock.lock(); _events = newValue; lock.unlock() }
    }

    func markDirty(id: UUID) {
        lock.lock(); _events.append(.dirty(id)); lock.unlock()
    }

    func markDeleted(id: UUID) {
        lock.lock(); _events.append(.deleted(id)); lock.unlock()
    }
}
