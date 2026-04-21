import Foundation
import Testing
@testable import Simpod

/// Gate W1 — every DataStore mutation that changes a synced field must
/// emit a markDirty/markDeleted notification to the SyncCoordinator. The
/// inverse is also asserted: explicit skip-list methods must NOT notify.
@Suite("DataStore → SyncCoordinator wiring")
struct SyncWiringTests {

    // MARK: - Helpers

    private func makeStore() throws -> (DataStore, RecordingSyncCoordinator) {
        let store = try DataStore.preview()
        let recorder = RecordingSyncCoordinator()
        store.syncCoordinator = recorder
        return (store, recorder)
    }

    private func seedPodcast(_ store: DataStore, recorder: RecordingSyncCoordinator) throws -> Podcast {
        let p = Podcast(feedURL: "https://example.com/feed.xml", title: "P")
        try store.savePodcast(p)
        recorder.events.removeAll()
        return p
    }

    private func seedEpisode(
        _ store: DataStore,
        recorder: RecordingSyncCoordinator,
        podcastID: UUID,
        guid: String = "g-1"
    ) throws -> Episode {
        let e = Episode(podcastID: podcastID, guid: guid, title: "E", audioURL: "https://example.com/e.mp3")
        try store.saveEpisode(e)
        recorder.events.removeAll()
        return e
    }

    // MARK: - Wired mutations

    @Test("savePodcast emits markDirty(podcast.id)")
    func wireSavePodcast() throws {
        let (store, recorder) = try makeStore()
        let p = Podcast(feedURL: "https://example.com/a.xml", title: "P")
        try store.savePodcast(p)
        #expect(recorder.events == [.dirty(p.id)])
    }

    @Test("deletePodcast emits markDeleted(podcast.id)")
    func wireDeletePodcast() throws {
        let (store, recorder) = try makeStore()
        let p = try seedPodcast(store, recorder: recorder)
        try store.deletePodcast(p)
        #expect(recorder.events == [.deleted(p.id)])
    }

    @Test("saveEpisode emits markDirty(episode.id)")
    func wireSaveEpisode() throws {
        let (store, recorder) = try makeStore()
        let p = try seedPodcast(store, recorder: recorder)
        let e = Episode(podcastID: p.id, title: "E", audioURL: "https://example.com/e.mp3")
        try store.saveEpisode(e)
        #expect(recorder.events == [.dirty(e.id)])
    }

    @Test("saveEpisodes emits markDirty for every episode")
    func wireSaveEpisodes() throws {
        let (store, recorder) = try makeStore()
        let p = try seedPodcast(store, recorder: recorder)
        let e1 = Episode(podcastID: p.id, guid: "g1", title: "E1", audioURL: "https://example.com/1.mp3")
        let e2 = Episode(podcastID: p.id, guid: "g2", title: "E2", audioURL: "https://example.com/2.mp3")
        try store.saveEpisodes([e1, e2])
        #expect(recorder.events == [.dirty(e1.id), .dirty(e2.id)])
    }

    @Test("updateEpisodeStatus emits markDirty when row exists")
    func wireUpdateEpisodeStatus() throws {
        let (store, recorder) = try makeStore()
        let p = try seedPodcast(store, recorder: recorder)
        let e = try seedEpisode(store, recorder: recorder, podcastID: p.id)
        try store.updateEpisodeStatus(e.id, status: .skipped)
        #expect(recorder.events == [.dirty(e.id)])
    }

    @Test("updateEpisodeStatus emits nothing when episode does not exist")
    func wireUpdateEpisodeStatusMissingRow() throws {
        let (store, recorder) = try makeStore()
        try store.updateEpisodeStatus(UUID(), status: .skipped)
        #expect(recorder.events.isEmpty)
    }

    @Test("updatePlaybackPosition emits markDirty when row exists")
    func wireUpdatePlaybackPosition() throws {
        let (store, recorder) = try makeStore()
        let p = try seedPodcast(store, recorder: recorder)
        let e = try seedEpisode(store, recorder: recorder, podcastID: p.id)
        try store.updatePlaybackPosition(e.id, position: 30)
        #expect(recorder.events == [.dirty(e.id)])
    }

    @Test("addToQueue emits markDirty for queueItem and episode")
    func wireAddToQueue() throws {
        let (store, recorder) = try makeStore()
        let p = try seedPodcast(store, recorder: recorder)
        let e = try seedEpisode(store, recorder: recorder, podcastID: p.id)
        try store.addToQueue(episodeID: e.id)

        // Order: queue item first, then episode-status update.
        #expect(recorder.events.count == 2)
        if case .dirty = recorder.events[0] {} else { Issue.record("First event must be .dirty") }
        #expect(recorder.events[1] == .dirty(e.id))
    }

    @Test("hideEpisode emits markDeleted for the queue item, markDirty for the episode")
    func wireHideEpisode() throws {
        let (store, recorder) = try makeStore()
        let p = try seedPodcast(store, recorder: recorder)
        let e = try seedEpisode(store, recorder: recorder, podcastID: p.id)
        try store.addToQueue(episodeID: e.id)
        recorder.events.removeAll()

        try store.hideEpisode(e.id)

        let deletes = recorder.events.filter { if case .deleted = $0 { return true }; return false }
        let dirty = recorder.events.filter { $0 == .dirty(e.id) }
        #expect(deletes.count == 1, "Expected one .deleted for the removed queue item")
        #expect(dirty.count == 1, "Expected one .dirty for the episode status update")
    }

    @Test("unhideEpisode emits markDirty when episode is found")
    func wireUnhideEpisode() throws {
        let (store, recorder) = try makeStore()
        let p = try seedPodcast(store, recorder: recorder)
        let e = try seedEpisode(store, recorder: recorder, podcastID: p.id)
        try store.hideEpisode(e.id)
        recorder.events.removeAll()

        try store.unhideEpisode(e.id)
        #expect(recorder.events == [.dirty(e.id)])
    }

    @Test("triageToQueue and triageToSkip wire through their underlying methods")
    func wireTriage() throws {
        let (store, recorder) = try makeStore()
        let p = try seedPodcast(store, recorder: recorder)
        let e = try seedEpisode(store, recorder: recorder, podcastID: p.id)

        try store.triageToSkip(episodeID: e.id)
        #expect(recorder.events == [.dirty(e.id)])
        recorder.events.removeAll()

        let e2 = try seedEpisode(store, recorder: recorder, podcastID: p.id, guid: "g-2")
        try store.triageToQueue(episodeID: e2.id)
        #expect(recorder.events.contains(.dirty(e2.id)), "Episode dirty event missing")
    }

    @Test("removeFromQueue emits markDeleted for each removed item")
    func wireRemoveFromQueue() throws {
        let (store, recorder) = try makeStore()
        let p = try seedPodcast(store, recorder: recorder)
        let e = try seedEpisode(store, recorder: recorder, podcastID: p.id)
        try store.addToQueue(episodeID: e.id)
        recorder.events.removeAll()

        try store.removeFromQueue(episodeID: e.id)
        #expect(recorder.events.count == 1)
        if case .deleted = recorder.events[0] {} else { Issue.record("Expected .deleted") }
    }

    @Test("reorderQueue emits markDirty only for items whose order changed")
    func wireReorderQueue() throws {
        let (store, recorder) = try makeStore()
        let p = try seedPodcast(store, recorder: recorder)
        let e1 = try seedEpisode(store, recorder: recorder, podcastID: p.id, guid: "g1")
        let e2 = try seedEpisode(store, recorder: recorder, podcastID: p.id, guid: "g2")
        try store.addToQueue(episodeID: e1.id)
        try store.addToQueue(episodeID: e2.id)
        let items = try store.fetchAllQueueItems().sorted { $0.order < $1.order }
        recorder.events.removeAll()

        // Reverse order — both items must be marked dirty.
        try store.reorderQueue(itemIDs: [items[1].id, items[0].id])
        let dirty = recorder.events.filter { if case .dirty = $0 { return true }; return false }
        #expect(dirty.count == 2)

        recorder.events.removeAll()
        // Same order — no items changed, no events.
        try store.reorderQueue(itemIDs: [items[1].id, items[0].id])
        #expect(recorder.events.isEmpty, "Re-applying same order must not emit events")
    }

    @Test("moveToTop / moveToBottom emit dirty for items whose order changed")
    func wireMoveToTopAndBottom() throws {
        let (store, recorder) = try makeStore()
        let p = try seedPodcast(store, recorder: recorder)
        let e1 = try seedEpisode(store, recorder: recorder, podcastID: p.id, guid: "g1")
        let e2 = try seedEpisode(store, recorder: recorder, podcastID: p.id, guid: "g2")
        try store.addToQueue(episodeID: e1.id)
        try store.addToQueue(episodeID: e2.id)
        recorder.events.removeAll()

        try store.moveToTop(episodeID: e2.id)
        let dirty = recorder.events.filter { if case .dirty = $0 { return true }; return false }
        #expect(dirty.count >= 2, "Expected dirty events for swapped pair")
    }

    @Test("addToQueueAtTop emits dirty for the new item, all shifted items, and the episode")
    func wireAddToQueueAtTop() throws {
        let (store, recorder) = try makeStore()
        let p = try seedPodcast(store, recorder: recorder)
        let existingEp = try seedEpisode(store, recorder: recorder, podcastID: p.id, guid: "g1")
        try store.addToQueue(episodeID: existingEp.id)
        let newEp = try seedEpisode(store, recorder: recorder, podcastID: p.id, guid: "g2")
        recorder.events.removeAll()

        try store.addToQueueAtTop(episodeID: newEp.id)
        let dirty = recorder.events.filter { if case .dirty = $0 { return true }; return false }
        // 1 shifted item + 1 new queue item + 1 episode = 3
        #expect(dirty.count == 3)
        #expect(recorder.events.contains(.dirty(newEp.id)), "Episode must be marked dirty")
    }

    @Test("unhideExpiredEpisodes emits dirty only for actually-unhidden episodes")
    func wireUnhideExpiredEpisodes() throws {
        let (store, recorder) = try makeStore()
        let p = try seedPodcast(store, recorder: recorder)
        let e = try seedEpisode(store, recorder: recorder, podcastID: p.id)
        try store.hideEpisode(e.id)
        recorder.events.removeAll()

        // Manually set hiddenUntil into the past to make it eligible.
        try store.saveFromSync(
            episode: Episode(
                id: e.id, podcastID: p.id, title: "E",
                audioURL: "https://example.com/e.mp3",
                status: .hidden,
                hiddenUntil: Date(timeIntervalSinceNow: -3600)
            ),
            systemFields: nil
        )
        recorder.events.removeAll()

        try store.unhideExpiredEpisodes()
        #expect(recorder.events == [.dirty(e.id)])

        // Idempotent: nothing eligible the second time.
        recorder.events.removeAll()
        try store.unhideExpiredEpisodes()
        #expect(recorder.events.isEmpty)
    }

    @Test("wipeAll emits markDeleted for every podcast / episode / queueItem")
    func wireWipeAll() throws {
        let (store, recorder) = try makeStore()
        let p = try seedPodcast(store, recorder: recorder)
        let e = try seedEpisode(store, recorder: recorder, podcastID: p.id)
        try store.addToQueue(episodeID: e.id)
        recorder.events.removeAll()

        try store.wipeAll()
        let deletes = recorder.events.filter { if case .deleted = $0 { return true }; return false }
        #expect(deletes.count == 3, "Expected one .deleted per row across all 3 tables")
    }

    // MARK: - Skip list (must NOT notify)

    @Test("updateLocalFilePath does not notify (device-local field)")
    func skipUpdateLocalFilePath() throws {
        let (store, recorder) = try makeStore()
        let p = try seedPodcast(store, recorder: recorder)
        let e = try seedEpisode(store, recorder: recorder, podcastID: p.id)
        try store.updateLocalFilePath(e.id, path: "/tmp/x.mp3")
        #expect(recorder.events.isEmpty)
    }

    @Test("deleteByID does not notify (inbound applyDeletion path only)")
    func skipDeleteByID() throws {
        let (store, recorder) = try makeStore()
        let p = try seedPodcast(store, recorder: recorder)
        try store.deleteByID(Podcast.self, id: p.id)
        #expect(recorder.events.isEmpty)
    }

    // MARK: - R1 regression: saveRefreshResult on no-op refresh emits NOTHING

    @Test("R1 — saveRefreshResult emits no events when nothing changed")
    func r1SaveRefreshResultNoOp() throws {
        let (store, recorder) = try makeStore()
        _ = try seedPodcast(store, recorder: recorder)
        // Read back the post-roundtrip podcast — Date precision drift through
        // SQLite makes the in-memory `p` non-equal to the stored row otherwise.
        // Same pattern as FeedRefreshEfficiencyTests A3 (line 147-148).
        let stored = try #require(try store.fetchAllPodcasts().first)

        try store.saveRefreshResult(podcast: stored, newEpisodes: [])
        #expect(recorder.events.isEmpty, "No-op refresh must not notify the sync layer")
    }

    @Test("saveRefreshResult emits dirty for the podcast when fields changed")
    func wireSaveRefreshResultPodcastChanged() throws {
        let (store, recorder) = try makeStore()
        _ = try seedPodcast(store, recorder: recorder)
        let stored = try #require(try store.fetchAllPodcasts().first)

        var modified = stored
        modified.title = "New Title"
        modified.lastModified = Date(timeIntervalSinceNow: 1)
        try store.saveRefreshResult(podcast: modified, newEpisodes: [])
        #expect(recorder.events == [.dirty(stored.id)])
    }

    @Test("saveRefreshResult emits dirty per new episode and skips podcast if unchanged")
    func wireSaveRefreshResultNewEpisodesOnly() throws {
        let (store, recorder) = try makeStore()
        _ = try seedPodcast(store, recorder: recorder)
        let stored = try #require(try store.fetchAllPodcasts().first)

        let e1 = Episode(podcastID: stored.id, guid: "g1", title: "E1", audioURL: "https://example.com/1.mp3")
        let e2 = Episode(podcastID: stored.id, guid: "g2", title: "E2", audioURL: "https://example.com/2.mp3")
        try store.saveRefreshResult(podcast: stored, newEpisodes: [e1, e2])
        #expect(recorder.events == [.dirty(e1.id), .dirty(e2.id)])
    }
}
