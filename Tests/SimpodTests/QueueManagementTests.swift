import Foundation
import Testing
@testable import Simpod

@Suite("Queue Management")
struct QueueManagementTests {

    // MARK: - Helpers

    /// Create a fresh in-memory DataStore for each test.
    private func makeStore() throws -> DataStore {
        try DataStore.preview()
    }

    /// Save a podcast and return it.
    private func savePodcast(to store: DataStore, feedURL: String = "https://example.com/feed") throws -> Podcast {
        let podcast = Podcast(feedURL: feedURL, title: "Test Podcast")
        try store.savePodcast(podcast)
        return podcast
    }

    /// Save an episode with a unique guid and return it.
    private func saveEpisode(
        to store: DataStore,
        podcastID: UUID,
        guid: String,
        title: String? = nil
    ) throws -> Episode {
        let episode = Episode(
            podcastID: podcastID,
            guid: guid,
            title: title ?? "Episode \(guid)",
            audioURL: "https://example.com/\(guid).mp3"
        )
        try store.saveEpisode(episode)
        return episode
    }

    // MARK: - 1. moveToTop

    @Test func testMoveToTop() throws {
        let store = try makeStore()
        let podcast = try savePodcast(to: store)

        let ep1 = try saveEpisode(to: store, podcastID: podcast.id, guid: "ep1")
        let ep2 = try saveEpisode(to: store, podcastID: podcast.id, guid: "ep2")
        let ep3 = try saveEpisode(to: store, podcastID: podcast.id, guid: "ep3")

        try store.addToQueue(episodeID: ep1.id)
        try store.addToQueue(episodeID: ep2.id)
        try store.addToQueue(episodeID: ep3.id)

        // Move the last episode (ep3, order 2) to top
        try store.moveToTop(episodeID: ep3.id)

        let queue = try store.fetchQueue()
        #expect(queue.count == 3)
        #expect(queue[0].episode.id == ep3.id)
        #expect(queue[1].episode.id == ep1.id)
        #expect(queue[2].episode.id == ep2.id)
        #expect(queue[0].queueItem.order == 0)
        #expect(queue[1].queueItem.order == 1)
        #expect(queue[2].queueItem.order == 2)
    }

    // MARK: - 2. moveToBottom

    @Test func testMoveToBottom() throws {
        let store = try makeStore()
        let podcast = try savePodcast(to: store)

        let ep1 = try saveEpisode(to: store, podcastID: podcast.id, guid: "ep1")
        let ep2 = try saveEpisode(to: store, podcastID: podcast.id, guid: "ep2")
        let ep3 = try saveEpisode(to: store, podcastID: podcast.id, guid: "ep3")

        try store.addToQueue(episodeID: ep1.id)
        try store.addToQueue(episodeID: ep2.id)
        try store.addToQueue(episodeID: ep3.id)

        // Move the first episode (ep1, order 0) to bottom
        try store.moveToBottom(episodeID: ep1.id)

        let queue = try store.fetchQueue()
        #expect(queue.count == 3)
        #expect(queue[0].episode.id == ep2.id)
        #expect(queue[1].episode.id == ep3.id)
        #expect(queue[2].episode.id == ep1.id)
        #expect(queue[0].queueItem.order == 0)
        #expect(queue[1].queueItem.order == 1)
        #expect(queue[2].queueItem.order == 2)
    }

    // MARK: - 3. addToQueueAtTop

    @Test func testAddToQueueAtTop() throws {
        let store = try makeStore()
        let podcast = try savePodcast(to: store)

        let ep1 = try saveEpisode(to: store, podcastID: podcast.id, guid: "ep1")
        let ep2 = try saveEpisode(to: store, podcastID: podcast.id, guid: "ep2")
        let ep3 = try saveEpisode(to: store, podcastID: podcast.id, guid: "ep3")

        // Queue ep1 and ep2 normally
        try store.addToQueue(episodeID: ep1.id)
        try store.addToQueue(episodeID: ep2.id)

        // Add ep3 from inbox directly to top
        try store.addToQueueAtTop(episodeID: ep3.id)

        let queue = try store.fetchQueue()
        #expect(queue.count == 3)
        #expect(queue[0].episode.id == ep3.id)
        #expect(queue[0].queueItem.order == 0)
        #expect(queue[1].episode.id == ep1.id)
        #expect(queue[1].queueItem.order == 1)
        #expect(queue[2].episode.id == ep2.id)
        #expect(queue[2].queueItem.order == 2)

        // ep3's status should be .queued
        let ep3Fetched = try store.fetchEpisode(byID: ep3.id)
        #expect(ep3Fetched?.status == .queued)
    }

    // MARK: - 4. hideEpisode removes from queue and sets status

    @Test func testHideEpisode() throws {
        let store = try makeStore()
        let podcast = try savePodcast(to: store)

        let ep1 = try saveEpisode(to: store, podcastID: podcast.id, guid: "ep1")
        try store.addToQueue(episodeID: ep1.id)

        // Confirm it's in queue
        let queueBefore = try store.fetchQueue()
        #expect(queueBefore.count == 1)

        // Hide with no reminder
        try store.hideEpisode(ep1.id, remindAt: nil)

        // Should be removed from queue
        let queueAfter = try store.fetchQueue()
        #expect(queueAfter.isEmpty)

        // Status should be .hidden
        let fetched = try store.fetchEpisode(byID: ep1.id)
        #expect(fetched?.status == .hidden)
        #expect(fetched?.hiddenUntil == nil)
    }

    // MARK: - 5. hideEpisode with reminder sets hiddenUntil

    @Test func testHideEpisodeWithReminder() throws {
        let store = try makeStore()
        let podcast = try savePodcast(to: store)

        let ep1 = try saveEpisode(to: store, podcastID: podcast.id, guid: "ep1")
        let futureDate = Date(timeIntervalSinceNow: 86400) // tomorrow

        try store.hideEpisode(ep1.id, remindAt: futureDate)

        let fetched = try store.fetchEpisode(byID: ep1.id)
        #expect(fetched?.status == .hidden)
        // Compare within 1-second tolerance to avoid floating-point drift
        let storedInterval = fetched?.hiddenUntil?.timeIntervalSinceReferenceDate ?? 0
        let expectedInterval = futureDate.timeIntervalSinceReferenceDate
        #expect(abs(storedInterval - expectedInterval) < 1.0)
    }

    // MARK: - 6. unhideEpisode returns to inbox

    @Test func testUnhideEpisode() throws {
        let store = try makeStore()
        let podcast = try savePodcast(to: store)

        let ep1 = try saveEpisode(to: store, podcastID: podcast.id, guid: "ep1")

        // Hide it first
        try store.hideEpisode(ep1.id, remindAt: Date(timeIntervalSinceNow: 3600))

        let hiddenState = try store.fetchEpisode(byID: ep1.id)
        #expect(hiddenState?.status == .hidden)

        // Now unhide it
        try store.unhideEpisode(ep1.id)

        let restored = try store.fetchEpisode(byID: ep1.id)
        #expect(restored?.status == .inbox)
        #expect(restored?.hiddenUntil == nil)
    }

    // MARK: - 7. unhideExpiredEpisodes only returns past-reminder episodes

    @Test func testUnhideExpiredEpisodes() throws {
        let store = try makeStore()
        let podcast = try savePodcast(to: store)

        let epPast = try saveEpisode(to: store, podcastID: podcast.id, guid: "ep-past")
        let epFuture = try saveEpisode(to: store, podcastID: podcast.id, guid: "ep-future")

        // epPast: reminder in the past (already expired)
        try store.hideEpisode(epPast.id, remindAt: Date(timeIntervalSinceNow: -3600))

        // epFuture: reminder in the future (should not be unhidden)
        try store.hideEpisode(epFuture.id, remindAt: Date(timeIntervalSinceNow: 86400))

        // Run the auto-unhide sweep
        try store.unhideExpiredEpisodes()

        let pastFetched = try store.fetchEpisode(byID: epPast.id)
        let futureFetched = try store.fetchEpisode(byID: epFuture.id)

        // Past reminder episode should be back in inbox
        #expect(pastFetched?.status == .inbox)
        #expect(pastFetched?.hiddenUntil == nil)

        // Future reminder episode should remain hidden
        #expect(futureFetched?.status == .hidden)
        #expect(futureFetched?.hiddenUntil != nil)
    }

    // MARK: - 8. unhideExpiredEpisodes does not touch indefinitely hidden episodes

    @Test func testUnhideDoesNotTouchIndefiniteHide() throws {
        let store = try makeStore()
        let podcast = try savePodcast(to: store)

        let ep1 = try saveEpisode(to: store, podcastID: podcast.id, guid: "ep1")

        // Hide with no reminder date (indefinite hide)
        try store.hideEpisode(ep1.id, remindAt: nil)

        let hiddenState = try store.fetchEpisode(byID: ep1.id)
        #expect(hiddenState?.status == .hidden)
        #expect(hiddenState?.hiddenUntil == nil)

        // Run the auto-unhide sweep
        try store.unhideExpiredEpisodes()

        // Should still be hidden — nil hiddenUntil means "hide indefinitely"
        let after = try store.fetchEpisode(byID: ep1.id)
        #expect(after?.status == .hidden)
        #expect(after?.hiddenUntil == nil)
    }
}
