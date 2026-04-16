import Foundation
import Testing
import GRDB
@testable import Simpod

@Suite("Integration Tests")
struct IntegrationTests {

    // MARK: - 1. Subscribe flow populates inbox

    @Test func subscribeFlowPopulatesInbox() throws {
        let store = try DataStore.preview()
        let podcast = Podcast(
            feedURL: "https://example.com/feed",
            title: "Integration Podcast"
        )
        try store.savePodcast(podcast)

        let ep1 = Episode(
            podcastID: podcast.id,
            guid: "inbox-1",
            title: "Inbox Episode 1",
            audioURL: "https://example.com/inbox1.mp3",
            publishedDate: Date(timeIntervalSince1970: 1000)
        )
        let ep2 = Episode(
            podcastID: podcast.id,
            guid: "inbox-2",
            title: "Inbox Episode 2",
            audioURL: "https://example.com/inbox2.mp3",
            publishedDate: Date(timeIntervalSince1970: 2000)
        )
        let ep3 = Episode(
            podcastID: podcast.id,
            guid: "inbox-3",
            title: "Inbox Episode 3",
            audioURL: "https://example.com/inbox3.mp3",
            publishedDate: Date(timeIntervalSince1970: 3000)
        )
        try store.saveEpisodes([ep1, ep2, ep3])

        let episodes = try store.fetchEpisodes(for: podcast.id)
        #expect(episodes.count == 3)
        #expect(episodes[0].status == .inbox)
        #expect(episodes[1].status == .inbox)
        #expect(episodes[2].status == .inbox)
    }

    // MARK: - 2. Triage to queue then verify

    @Test func triageToQueueUpdatesStatusAndAppearsInQueue() throws {
        let store = try DataStore.preview()
        let podcast = Podcast(
            feedURL: "https://example.com/feed",
            title: "Triage Podcast"
        )
        try store.savePodcast(podcast)

        let episode = Episode(
            podcastID: podcast.id,
            guid: "triage-q-1",
            title: "Triage To Queue",
            audioURL: "https://example.com/triage-q.mp3"
        )
        try store.saveEpisode(episode)

        try store.triageToQueue(episodeID: episode.id)

        let episodes = try store.fetchEpisodes(for: podcast.id)
        #expect(episodes.first?.status == .queued)

        let queueItems = try store.fetchQueue()
        #expect(queueItems.count == 1)
        #expect(queueItems[0].episode.id == episode.id)
    }

    // MARK: - 3. Multiple triage preserves queue ordering

    @Test func multipleTriagePreservesQueueOrdering() throws {
        let store = try DataStore.preview()
        let podcast = Podcast(
            feedURL: "https://example.com/feed",
            title: "Order Podcast"
        )
        try store.savePodcast(podcast)

        let ep1 = Episode(
            podcastID: podcast.id,
            guid: "order-1",
            title: "Order Episode 1",
            audioURL: "https://example.com/order1.mp3"
        )
        let ep2 = Episode(
            podcastID: podcast.id,
            guid: "order-2",
            title: "Order Episode 2",
            audioURL: "https://example.com/order2.mp3"
        )
        let ep3 = Episode(
            podcastID: podcast.id,
            guid: "order-3",
            title: "Order Episode 3",
            audioURL: "https://example.com/order3.mp3"
        )
        try store.saveEpisodes([ep1, ep2, ep3])

        try store.triageToQueue(episodeID: ep1.id)
        try store.triageToQueue(episodeID: ep2.id)
        try store.triageToQueue(episodeID: ep3.id)

        let queueItems = try store.fetchQueue()
        #expect(queueItems.count == 3)
        #expect(queueItems[0].episode.id == ep1.id)
        #expect(queueItems[1].episode.id == ep2.id)
        #expect(queueItems[2].episode.id == ep3.id)
        #expect(queueItems[0].queueItem.order == 0)
        #expect(queueItems[1].queueItem.order == 1)
        #expect(queueItems[2].queueItem.order == 2)
    }

    // MARK: - 4. updateLocalFilePath persists

    @Test func updateLocalFilePathPersists() throws {
        let store = try DataStore.preview()
        let podcast = Podcast(
            feedURL: "https://example.com/feed",
            title: "Download Podcast"
        )
        try store.savePodcast(podcast)

        let episode = Episode(
            podcastID: podcast.id,
            guid: "local-path-1",
            title: "Downloaded Episode",
            audioURL: "https://example.com/download.mp3"
        )
        try store.saveEpisode(episode)

        try store.updateLocalFilePath(episode.id, path: "/path/to/file.mp3")

        let episodes = try store.fetchEpisodes(for: podcast.id)
        #expect(episodes.first?.localFilePath == "/path/to/file.mp3")
    }

    // MARK: - 5. Full episode lifecycle

    @Test func fullEpisodeLifecycle() throws {
        let store = try DataStore.preview()
        let podcast = Podcast(
            feedURL: "https://example.com/feed",
            title: "Lifecycle Podcast"
        )
        try store.savePodcast(podcast)

        let episode = Episode(
            podcastID: podcast.id,
            guid: "lifecycle-1",
            title: "Lifecycle Episode",
            audioURL: "https://example.com/lifecycle.mp3"
        )
        try store.saveEpisode(episode)

        // Starts in inbox
        let initial = try store.fetchEpisodes(for: podcast.id)
        #expect(initial.first?.status == .inbox)

        // Triage to queue
        try store.triageToQueue(episodeID: episode.id)
        let queued = try store.fetchEpisodes(for: podcast.id)
        #expect(queued.first?.status == .queued)

        // Update playback position
        try store.updatePlaybackPosition(episode.id, position: 50.0)

        // Mark as played
        try store.updateEpisodeStatus(episode.id, status: .played)

        // Verify final state
        let final = try store.fetchEpisodes(for: podcast.id)
        #expect(final.first?.status == .played)
        #expect(final.first?.playbackPosition == 50.0)
    }

    // MARK: - 6. Refresh deduplication (unique constraint on [podcastID, guid])

    @Test func refreshDeduplicationThrowsOnDuplicateGuid() throws {
        let store = try DataStore.preview()
        let podcast = Podcast(
            feedURL: "https://example.com/feed",
            title: "Dedup Podcast"
        )
        try store.savePodcast(podcast)

        let ep1 = Episode(
            podcastID: podcast.id,
            guid: "ep-1",
            title: "Original Episode",
            audioURL: "https://example.com/ep1.mp3"
        )
        try store.saveEpisode(ep1)

        let ep2 = Episode(
            podcastID: podcast.id,
            guid: "ep-1",
            title: "Duplicate Episode",
            audioURL: "https://example.com/ep1-dup.mp3"
        )

        // Saving a second episode with the same podcastID + guid should throw
        #expect(throws: (any Error).self) {
            try store.saveEpisode(ep2)
        }

        // Only the original should exist
        let episodes = try store.fetchEpisodes(for: podcast.id)
        #expect(episodes.count == 1)
        #expect(episodes.first?.title == "Original Episode")
    }

    // MARK: - 7. Delete podcast cascades queue items and episodes

    @Test func deletePodcastCascadesQueueAndEpisodes() throws {
        let store = try DataStore.preview()
        let podcast = Podcast(
            feedURL: "https://example.com/feed",
            title: "Cascade Podcast"
        )
        try store.savePodcast(podcast)

        let ep1 = Episode(
            podcastID: podcast.id,
            guid: "cascade-1",
            title: "Cascade Episode 1",
            audioURL: "https://example.com/cascade1.mp3"
        )
        let ep2 = Episode(
            podcastID: podcast.id,
            guid: "cascade-2",
            title: "Cascade Episode 2",
            audioURL: "https://example.com/cascade2.mp3"
        )
        try store.saveEpisodes([ep1, ep2])

        try store.triageToQueue(episodeID: ep1.id)
        try store.triageToQueue(episodeID: ep2.id)

        // Confirm queue has both items
        let beforeQueue = try store.fetchQueue()
        #expect(beforeQueue.count == 2)

        // Delete the podcast — cascades to episodes and then to queue items
        try store.deletePodcast(podcast)

        // Queue should be empty
        let afterQueue = try store.fetchQueue()
        #expect(afterQueue.isEmpty)

        // Episodes should be gone too
        let afterEpisodes = try store.fetchEpisodes(for: podcast.id)
        #expect(afterEpisodes.isEmpty)
    }
}
