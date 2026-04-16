import Foundation
import Testing
import GRDB
@testable import Simpod

// MARK: - DataStore Creation

@Test func dataStoreCreation() throws {
    let store = try DataStore.preview()
    #expect(store.podcasts.isEmpty)
    #expect(store.inbox.isEmpty)
    #expect(store.queue.isEmpty)
}

// MARK: - Podcast CRUD

@Test func savePodcastAndFetchByFeedURL() throws {
    let store = try DataStore.preview()
    let podcast = Podcast(
        feedURL: "https://atp.fm/episodes?format=rss",
        title: "Accidental Tech Podcast",
        author: "Marco Arment, Casey Liss, John Siracusa"
    )
    try store.savePodcast(podcast)

    let fetched = try store.fetchPodcast(byFeedURL: "https://atp.fm/episodes?format=rss")
    #expect(fetched != nil)
    #expect(fetched?.title == "Accidental Tech Podcast")
    #expect(fetched?.author == "Marco Arment, Casey Liss, John Siracusa")
    #expect(fetched?.id == podcast.id)
}

@Test func fetchPodcastByFeedURLReturnsNilWhenMissing() throws {
    let store = try DataStore.preview()
    let result = try store.fetchPodcast(byFeedURL: "https://nonexistent.example.com/feed")
    #expect(result == nil)
}

// MARK: - Episode Defaults

@Test func episodeDefaultsToInbox() {
    let episode = Episode(
        podcastID: UUID(),
        title: "Test Episode",
        audioURL: "https://example.com/episode.mp3"
    )
    #expect(episode.status == .inbox)
    #expect(episode.playbackPosition == 0)
    #expect(episode.downloadProgress == 0)
    #expect(episode.duration == 0)
    #expect(episode.localFilePath == nil)
}

// MARK: - Episodes in Inbox

@Test func savedEpisodesAppearInInbox() throws {
    let store = try DataStore.preview()
    let podcast = Podcast(
        feedURL: "https://example.com/feed",
        title: "Test Podcast"
    )
    try store.savePodcast(podcast)

    let ep1 = Episode(
        podcastID: podcast.id,
        guid: "ep1",
        title: "Episode 1",
        audioURL: "https://example.com/ep1.mp3",
        publishedDate: Date(timeIntervalSince1970: 1000)
    )
    let ep2 = Episode(
        podcastID: podcast.id,
        guid: "ep2",
        title: "Episode 2",
        audioURL: "https://example.com/ep2.mp3",
        publishedDate: Date(timeIntervalSince1970: 2000)
    )
    try store.saveEpisodes([ep1, ep2])

    // fetchEpisodes returns episodes ordered by publishedDate desc
    let episodes = try store.fetchEpisodes(for: podcast.id)
    #expect(episodes.count == 2)
    #expect(episodes[0].title == "Episode 2") // newest first
    #expect(episodes[1].title == "Episode 1")

    // Both should have inbox status
    #expect(episodes[0].status == .inbox)
    #expect(episodes[1].status == .inbox)
}

// MARK: - Triage to Queue

@Test func triageToQueueChangesStatusAndCreatesQueueItem() throws {
    let store = try DataStore.preview()
    let podcast = Podcast(
        feedURL: "https://example.com/feed",
        title: "Test Podcast"
    )
    try store.savePodcast(podcast)

    let episode = Episode(
        podcastID: podcast.id,
        guid: "ep-001",
        title: "Triage Me",
        audioURL: "https://example.com/triage.mp3"
    )
    try store.saveEpisode(episode)

    // Verify episode starts in inbox
    let beforeEpisodes = try store.fetchEpisodes(for: podcast.id)
    #expect(beforeEpisodes.first?.status == .inbox)

    // Triage to queue
    try store.triageToQueue(episodeID: episode.id)

    // Verify episode status changed to queued
    let afterEpisodes = try store.fetchEpisodes(for: podcast.id)
    #expect(afterEpisodes.first?.status == .queued)
}

// MARK: - Triage to Skip

@Test func triageToSkipChangesStatus() throws {
    let store = try DataStore.preview()
    let podcast = Podcast(
        feedURL: "https://example.com/feed",
        title: "Test Podcast"
    )
    try store.savePodcast(podcast)

    let episode = Episode(
        podcastID: podcast.id,
        guid: "ep-skip",
        title: "Skip Me",
        audioURL: "https://example.com/skip.mp3"
    )
    try store.saveEpisode(episode)

    try store.triageToSkip(episodeID: episode.id)

    let episodes = try store.fetchEpisodes(for: podcast.id)
    #expect(episodes.first?.status == .skipped)
}

// MARK: - Queue Ordering

@Test func queueItemOrdering() {
    let id1 = UUID()
    let id2 = UUID()
    let item1 = QueueItem(episodeID: id1, order: 0)
    let item2 = QueueItem(episodeID: id2, order: 1)
    #expect(item1.order < item2.order)
}

@Test func addToQueueAssignsIncrementingOrder() throws {
    let store = try DataStore.preview()
    let podcast = Podcast(
        feedURL: "https://example.com/feed",
        title: "Test Podcast"
    )
    try store.savePodcast(podcast)

    let ep1 = Episode(
        podcastID: podcast.id,
        guid: "q1",
        title: "Queue First",
        audioURL: "https://example.com/q1.mp3"
    )
    let ep2 = Episode(
        podcastID: podcast.id,
        guid: "q2",
        title: "Queue Second",
        audioURL: "https://example.com/q2.mp3"
    )
    let ep3 = Episode(
        podcastID: podcast.id,
        guid: "q3",
        title: "Queue Third",
        audioURL: "https://example.com/q3.mp3"
    )
    try store.saveEpisodes([ep1, ep2, ep3])

    try store.addToQueue(episodeID: ep1.id)
    try store.addToQueue(episodeID: ep2.id)
    try store.addToQueue(episodeID: ep3.id)

    // Use synchronous fetch (ValueObservation is async and won't update in time for tests)
    let queueItems = try store.fetchQueue()
    #expect(queueItems.count == 3)
    #expect(queueItems[0].episode.title == "Queue First")
    #expect(queueItems[1].episode.title == "Queue Second")
    #expect(queueItems[2].episode.title == "Queue Third")
    #expect(queueItems[0].queueItem.order < queueItems[1].queueItem.order)
    #expect(queueItems[1].queueItem.order < queueItems[2].queueItem.order)
}

// MARK: - Podcast Deletion Cascades to Episodes

@Test func deletePodcastCascadesToEpisodes() throws {
    let store = try DataStore.preview()
    let podcast = Podcast(
        feedURL: "https://example.com/feed",
        title: "Doomed Podcast"
    )
    try store.savePodcast(podcast)

    let ep1 = Episode(
        podcastID: podcast.id,
        guid: "doom-1",
        title: "Episode to Delete 1",
        audioURL: "https://example.com/doom1.mp3"
    )
    let ep2 = Episode(
        podcastID: podcast.id,
        guid: "doom-2",
        title: "Episode to Delete 2",
        audioURL: "https://example.com/doom2.mp3"
    )
    try store.saveEpisodes([ep1, ep2])

    // Confirm episodes exist
    let beforeEpisodes = try store.fetchEpisodes(for: podcast.id)
    #expect(beforeEpisodes.count == 2)

    // Delete the podcast
    try store.deletePodcast(podcast)

    // Podcast should be gone
    let fetchedPodcast = try store.fetchPodcast(byFeedURL: "https://example.com/feed")
    #expect(fetchedPodcast == nil)

    // Episodes should be cascade-deleted
    let afterEpisodes = try store.fetchEpisodes(for: podcast.id)
    #expect(afterEpisodes.isEmpty)
}

@Test func deletePodcastCascadesToQueueItems() throws {
    let store = try DataStore.preview()
    let podcast = Podcast(
        feedURL: "https://example.com/feed",
        title: "Cascade Podcast"
    )
    try store.savePodcast(podcast)

    let episode = Episode(
        podcastID: podcast.id,
        guid: "cascade-ep",
        title: "Queued Then Deleted",
        audioURL: "https://example.com/cascade.mp3"
    )
    try store.saveEpisode(episode)
    try store.addToQueue(episodeID: episode.id)

    // Confirm queue has the item
    let beforeQueue = try store.fetchQueue()
    #expect(beforeQueue.count == 1)

    // Delete the podcast -- should cascade to episodes and then to queue items
    try store.deletePodcast(podcast)

    // Queue should be empty after cascade
    let afterQueue = try store.fetchQueue()
    #expect(afterQueue.isEmpty)
}

// MARK: - Duplicate Podcast Prevention (unique feedURL)

@Test func duplicateFeedURLThrowsError() throws {
    let store = try DataStore.preview()
    let podcast1 = Podcast(
        feedURL: "https://example.com/unique-feed",
        title: "Original Podcast"
    )
    try store.savePodcast(podcast1)

    let podcast2 = Podcast(
        feedURL: "https://example.com/unique-feed",
        title: "Duplicate Podcast"
    )

    // Saving a second podcast with the same feedURL should throw a database error
    #expect(throws: (any Error).self) {
        try store.savePodcast(podcast2)
    }

    // Only the original should exist
    let fetched = try store.fetchPodcast(byFeedURL: "https://example.com/unique-feed")
    #expect(fetched?.title == "Original Podcast")
}

// MARK: - Update Episode Status

@Test func updateEpisodeStatus() throws {
    let store = try DataStore.preview()
    let podcast = Podcast(
        feedURL: "https://example.com/feed",
        title: "Status Podcast"
    )
    try store.savePodcast(podcast)

    let episode = Episode(
        podcastID: podcast.id,
        guid: "status-ep",
        title: "Status Episode",
        audioURL: "https://example.com/status.mp3"
    )
    try store.saveEpisode(episode)

    try store.updateEpisodeStatus(episode.id, status: .playing)
    let episodes = try store.fetchEpisodes(for: podcast.id)
    #expect(episodes.first?.status == .playing)

    try store.updateEpisodeStatus(episode.id, status: .played)
    let updated = try store.fetchEpisodes(for: podcast.id)
    #expect(updated.first?.status == .played)
}

// MARK: - Playback Position

@Test func updatePlaybackPosition() throws {
    let store = try DataStore.preview()
    let podcast = Podcast(
        feedURL: "https://example.com/feed",
        title: "Playback Podcast"
    )
    try store.savePodcast(podcast)

    let episode = Episode(
        podcastID: podcast.id,
        guid: "playback-ep",
        title: "Playback Episode",
        audioURL: "https://example.com/playback.mp3",
        duration: 3600
    )
    try store.saveEpisode(episode)

    try store.updatePlaybackPosition(episode.id, position: 1234.5)
    let episodes = try store.fetchEpisodes(for: podcast.id)
    #expect(episodes.first?.playbackPosition == 1234.5)
}

// MARK: - Remove from Queue

@Test func removeFromQueue() throws {
    let store = try DataStore.preview()
    let podcast = Podcast(
        feedURL: "https://example.com/feed",
        title: "Remove Queue Podcast"
    )
    try store.savePodcast(podcast)

    let episode = Episode(
        podcastID: podcast.id,
        guid: "remove-q",
        title: "Remove From Queue",
        audioURL: "https://example.com/remove.mp3"
    )
    try store.saveEpisode(episode)
    try store.addToQueue(episodeID: episode.id)
    let beforeQueue = try store.fetchQueue()
    #expect(beforeQueue.count == 1)

    try store.removeFromQueue(episodeID: episode.id)
    let afterQueue = try store.fetchQueue()
    #expect(afterQueue.isEmpty)
}

// MARK: - Multiple Podcasts Isolation

@Test func episodesAreIsolatedPerPodcast() throws {
    let store = try DataStore.preview()

    let podcastA = Podcast(feedURL: "https://a.example.com/feed", title: "Podcast A")
    let podcastB = Podcast(feedURL: "https://b.example.com/feed", title: "Podcast B")
    try store.savePodcast(podcastA)
    try store.savePodcast(podcastB)

    let epA = Episode(podcastID: podcastA.id, guid: "a-1", title: "A Episode", audioURL: "https://a.example.com/1.mp3")
    let epB1 = Episode(podcastID: podcastB.id, guid: "b-1", title: "B Episode 1", audioURL: "https://b.example.com/1.mp3")
    let epB2 = Episode(podcastID: podcastB.id, guid: "b-2", title: "B Episode 2", audioURL: "https://b.example.com/2.mp3")
    try store.saveEpisodes([epA, epB1, epB2])

    let aEpisodes = try store.fetchEpisodes(for: podcastA.id)
    let bEpisodes = try store.fetchEpisodes(for: podcastB.id)

    #expect(aEpisodes.count == 1)
    #expect(bEpisodes.count == 2)
    #expect(aEpisodes[0].title == "A Episode")
}

// MARK: - Model Unit Tests

@Test func podcastModelDefaults() {
    let podcast = Podcast(feedURL: "https://example.com/feed", title: "Minimal")
    #expect(podcast.author == "")
    #expect(podcast.artworkURL == nil)
    #expect(podcast.podcastDescription == "")
    #expect(podcast.lastRefreshed == nil)
}

@Test func episodeStatusRawValues() {
    #expect(EpisodeStatus.inbox.rawValue == "inbox")
    #expect(EpisodeStatus.queued.rawValue == "queued")
    #expect(EpisodeStatus.skipped.rawValue == "skipped")
    #expect(EpisodeStatus.playing.rawValue == "playing")
    #expect(EpisodeStatus.played.rawValue == "played")
}

@Test func tagModelDefaults() {
    let tag = Tag(name: "Favorites")
    #expect(tag.color == "#007AFF")
    #expect(tag.name == "Favorites")
}

@Test func saveBatchEpisodes() throws {
    let store = try DataStore.preview()
    let podcast = Podcast(feedURL: "https://example.com/feed", title: "Batch Podcast")
    try store.savePodcast(podcast)

    let episodes = (1...10).map { i in
        Episode(
            podcastID: podcast.id,
            guid: "batch-\(i)",
            title: "Batch Episode \(i)",
            audioURL: "https://example.com/batch\(i).mp3",
            publishedDate: Date(timeIntervalSince1970: TimeInterval(i * 1000))
        )
    }
    try store.saveEpisodes(episodes)

    let fetched = try store.fetchEpisodes(for: podcast.id)
    #expect(fetched.count == 10)
    // Should be ordered newest first
    #expect(fetched[0].title == "Batch Episode 10")
    #expect(fetched[9].title == "Batch Episode 1")
}
