import Testing
@testable import Simpod

@Suite("Local Search Tests")
struct SearchTests {
    @Test("Search finds podcast by title")
    func searchPodcastByTitle() throws {
        let store = try DataStore.preview()
        let podcast = Podcast(feedURL: "https://example.com/feed", title: "Tech Talk Daily", author: "Jane Smith")
        try store.savePodcast(podcast)

        let results = try store.searchLocal(query: "Tech Talk")
        #expect(results.podcasts.count == 1)
        #expect(results.podcasts[0].title == "Tech Talk Daily")
    }

    @Test("Search finds podcast by author")
    func searchPodcastByAuthor() throws {
        let store = try DataStore.preview()
        let podcast = Podcast(feedURL: "https://example.com/feed", title: "My Podcast", author: "Jane Smith")
        try store.savePodcast(podcast)

        let results = try store.searchLocal(query: "Jane")
        #expect(results.podcasts.count == 1)
    }

    @Test("Search finds episode by title")
    func searchEpisodeByTitle() throws {
        let store = try DataStore.preview()
        let podcast = Podcast(feedURL: "https://example.com/feed", title: "My Show")
        try store.savePodcast(podcast)
        let episode = Episode(podcastID: podcast.id, title: "Understanding Swift Concurrency", audioURL: "https://example.com/ep1.mp3")
        try store.saveEpisode(episode)

        let results = try store.searchLocal(query: "Swift Concurrency")
        #expect(results.episodes.count == 1)
        #expect(results.episodes[0].episode.title == "Understanding Swift Concurrency")
    }

    @Test("Search finds episode by description")
    func searchEpisodeByDescription() throws {
        let store = try DataStore.preview()
        let podcast = Podcast(feedURL: "https://example.com/feed", title: "My Show")
        try store.savePodcast(podcast)
        let episode = Episode(
            podcastID: podcast.id,
            title: "Episode 42",
            audioURL: "https://example.com/ep42.mp3",
            episodeDescription: "In this episode we discuss advanced concurrency patterns"
        )
        try store.saveEpisode(episode)

        let results = try store.searchLocal(query: "concurrency patterns")
        #expect(results.episodes.count == 1)
    }

    @Test("Empty query returns empty results")
    func emptyQuery() throws {
        let store = try DataStore.preview()
        let results = try store.searchLocal(query: "")
        #expect(results.podcasts.isEmpty)
        #expect(results.episodes.isEmpty)
    }

    @Test("Prefix matching works")
    func prefixMatching() throws {
        let store = try DataStore.preview()
        let podcast = Podcast(feedURL: "https://example.com/feed", title: "Technology Today")
        try store.savePodcast(podcast)

        let results = try store.searchLocal(query: "tech")
        #expect(results.podcasts.count == 1)
    }

    @Test("No match returns empty results")
    func noMatch() throws {
        let store = try DataStore.preview()
        let podcast = Podcast(feedURL: "https://example.com/feed", title: "Cooking Show")
        try store.savePodcast(podcast)

        let results = try store.searchLocal(query: "programming")
        #expect(results.podcasts.isEmpty)
        #expect(results.episodes.isEmpty)
    }
}
