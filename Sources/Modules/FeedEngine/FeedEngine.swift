import Foundation
import FeedKit
import os

private let logger = Logger(subsystem: "com.simpod", category: "FeedEngine")

/// Fetches and parses podcast RSS feeds using FeedKit v10.
/// Invariant: never crashes on malformed RSS — returns partial data or descriptive error.
@Observable
final class FeedEngine: @unchecked Sendable {
    private let dataStore: DataStore

    var isRefreshing = false
    var refreshTotal = 0
    var refreshCompleted = 0
    var refreshingFeedTitle = ""

    init(dataStore: DataStore) {
        self.dataStore = dataStore
    }

    /// Subscribe to a podcast by its RSS feed URL.
    func subscribe(feedURL: String) async throws -> Podcast {
        let feed = try await Feed(urlString: feedURL)

        let podcast = mapToPodcast(feed, feedURL: feedURL)
        try dataStore.savePodcast(podcast)

        let episodes = mapToEpisodes(feed, podcastID: podcast.id)
        try dataStore.saveEpisodes(episodes)

        return podcast
    }

    /// Refresh a podcast feed and return new episodes.
    func refresh(podcast: Podcast) async throws -> [Episode] {
        logger.info("Refreshing feed: \(podcast.title, privacy: .public) — \(podcast.feedURL, privacy: .public)")
        UserDefaults.standard.set("\(podcast.title) — \(podcast.feedURL)", forKey: "com.simpod.crashBreadcrumb")
        let feed = try await Feed(urlString: podcast.feedURL)
        UserDefaults.standard.removeObject(forKey: "com.simpod.crashBreadcrumb")
        logger.info("Parsed feed OK: \(podcast.title, privacy: .public)")

        let episodes = mapToEpisodes(feed, podcastID: podcast.id)
        let existingEpisodes = try dataStore.fetchEpisodes(for: podcast.id)
        let existingGUIDs = Set(existingEpisodes.map(\.guid))

        let newEpisodes = episodes.filter { !existingGUIDs.contains($0.guid) }
        if !newEpisodes.isEmpty {
            try dataStore.saveEpisodes(newEpisodes)
        }

        var updated = podcast
        updated.lastRefreshed = .now
        updated.lastModified = .now
        try dataStore.savePodcast(updated)

        return newEpisodes
    }

    /// Import podcasts from OPML data. Skips already-subscribed feeds.
    func importOPML(data: Data) async throws -> (subscribed: Int, skipped: Int, failed: Int) {
        let feedURLs = try OPMLParser.parseFeedURLs(from: data)

        var subscribed = 0
        var skipped = 0
        var failed = 0

        for feedURL in feedURLs {
            if (try? dataStore.fetchPodcast(byFeedURL: feedURL)) != nil {
                skipped += 1
                continue
            }
            do {
                _ = try await subscribe(feedURL: feedURL)
                subscribed += 1
            } catch {
                print("[FeedEngine] OPML import failed for \(feedURL): \(error)")
                failed += 1
            }
        }

        return (subscribed, skipped, failed)
    }

    /// Refresh all subscribed podcasts with bounded concurrency (max 4).
    /// Sliding-window: seeds 4 tasks, launches the next as each completes.
    /// Debounces duplicate calls; tracks progress via observable properties.
    func refreshAll() async -> [Podcast: [Episode]] {
        let maxConcurrentRefreshes = 4

        let shouldRefresh = await MainActor.run {
            guard !isRefreshing else { return false }
            isRefreshing = true
            return true
        }
        guard shouldRefresh else { return [:] }

        defer {
            Task { @MainActor in
                self.isRefreshing = false
                self.refreshTotal = 0
                self.refreshCompleted = 0
                self.refreshingFeedTitle = ""
            }
        }

        let snapshot = await MainActor.run { dataStore.podcasts }
        await MainActor.run {
            refreshTotal = snapshot.count
            refreshCompleted = 0
            refreshingFeedTitle = ""
        }

        return await withTaskGroup(of: (Podcast, [Episode]).self) { group in
            var iterator = snapshot.makeIterator()

            // Seed initial batch
            for _ in 0..<min(maxConcurrentRefreshes, snapshot.count) {
                guard let podcast = iterator.next() else { break }
                group.addTask { await self.refreshOne(podcast) }
            }

            var results: [Podcast: [Episode]] = [:]
            for await (podcast, episodes) in group {
                results[podcast] = episodes
                await MainActor.run {
                    self.refreshCompleted += 1
                }
                // Launch next as each completes
                if let next = iterator.next() {
                    group.addTask { await self.refreshOne(next) }
                }
            }
            return results
        }
    }

    private func refreshOne(_ podcast: Podcast) async -> (Podcast, [Episode]) {
        await MainActor.run { self.refreshingFeedTitle = podcast.title }
        do {
            logger.info("Starting refresh for: \(podcast.title, privacy: .public)")
            let newEpisodes = try await self.refresh(podcast: podcast)
            logger.info("Completed refresh for: \(podcast.title, privacy: .public) — \(newEpisodes.count) new episodes")
            return (podcast, newEpisodes)
        } catch {
            logger.error("Failed to refresh \(podcast.title, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return (podcast, [])
        }
    }

    // MARK: - Feed Mapping

    private func mapToPodcast(_ feed: Feed, feedURL: String) -> Podcast {
        switch feed {
        case .rss(let rss):
            let ch = rss.channel
            return Podcast(
                feedURL: feedURL,
                title: ch?.title ?? "Untitled Podcast",
                author: ch?.iTunes?.author ?? ch?.managingEditor ?? "",
                artworkURL: ch?.iTunes?.image?.attributes?.href ?? ch?.image?.url,
                podcastDescription: ch?.description ?? ""
            )

        case .atom(let atom):
            return Podcast(
                feedURL: feedURL,
                title: atom.title?.text ?? "Untitled Podcast",
                author: atom.authors?.first?.name ?? "",
                artworkURL: atom.icon,
                podcastDescription: atom.subtitle?.text ?? ""
            )

        case .json(let json):
            return Podcast(
                feedURL: feedURL,
                title: json.title ?? "Untitled Podcast",
                author: json.author?.name ?? "",
                artworkURL: json.icon,
                podcastDescription: json.description ?? ""
            )
        }
    }

    private func mapToEpisodes(_ feed: Feed, podcastID: UUID) -> [Episode] {
        switch feed {
        case .rss(let rss):
            return (rss.channel?.items ?? []).compactMap { item -> Episode? in
                guard let audioURL = item.enclosure?.attributes?.url else { return nil }
                let guid = item.guid?.text ?? audioURL
                return Episode(
                    podcastID: podcastID,
                    guid: guid,
                    title: item.title ?? "Untitled Episode",
                    audioURL: audioURL,
                    duration: item.iTunes?.duration ?? 0,
                    publishedDate: item.pubDate ?? .now,
                    episodeDescription: item.description ?? item.content?.encoded ?? ""
                )
            }

        case .atom(let atom):
            return (atom.entries ?? []).compactMap { entry -> Episode? in
                guard let audioURL = entry.links?.first(where: {
                    $0.attributes?.type?.contains("audio") == true
                })?.attributes?.href else { return nil }
                return Episode(
                    podcastID: podcastID,
                    guid: entry.id ?? audioURL,
                    title: entry.title ?? "Untitled Episode",
                    audioURL: audioURL,
                    publishedDate: entry.published ?? entry.updated ?? .now,
                    episodeDescription: entry.summary?.text ?? ""
                )
            }

        case .json(let json):
            return (json.items ?? []).compactMap { item in
                guard let audioURL = item.attachments?.first(where: {
                    $0.mimeType?.contains("audio") == true
                })?.url else { return nil }
                return Episode(
                    podcastID: podcastID,
                    guid: item.id ?? audioURL,
                    title: item.title ?? "Untitled Episode",
                    audioURL: audioURL,
                    publishedDate: item.datePublished ?? .now,
                    episodeDescription: item.summary ?? ""
                )
            }
        }
    }
}

enum FeedError: LocalizedError {
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): "Invalid feed URL: \(url)"
        }
    }
}

extension Podcast: Hashable {
    static func == (lhs: Podcast, rhs: Podcast) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
