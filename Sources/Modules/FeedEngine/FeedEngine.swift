import Foundation
import FeedKit
import os

private let logger = Logger(subsystem: "com.simpod", category: "FeedEngine")
private let signposter = OSSignposter(subsystem: "com.simpod", category: "FeedEngine")

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
        let result = try await fetchFeedData(urlString: feedURL, etag: nil, lastModified: nil)
        guard case .fetched(let data, let etag, let lastModified) = result else {
            throw FeedError.invalidURL(feedURL)
        }
        let feed = try Feed(data: data)

        var podcast = mapToPodcast(feed, feedURL: feedURL)
        podcast.httpETag = etag
        podcast.httpLastModified = lastModified
        try dataStore.savePodcast(podcast)

        let episodes = mapToEpisodes(feed, podcastID: podcast.id)
        try dataStore.saveEpisodes(episodes)

        return podcast
    }

    /// Refresh a podcast feed and return new episodes.
    func refresh(podcast: Podcast) async throws -> [Episode] {
        logger.info("Refreshing feed: \(podcast.title, privacy: .public) — \(podcast.feedURL, privacy: .public)")
        UserDefaults.standard.set("\(podcast.title) — \(podcast.feedURL)", forKey: "com.simpod.crashBreadcrumb")

        let fetchState = signposter.beginInterval("http-fetch", "\(podcast.title, privacy: .public)")
        let result = try await fetchFeedData(
            urlString: podcast.feedURL,
            etag: podcast.httpETag,
            lastModified: podcast.httpLastModified
        )
        signposter.endInterval("http-fetch", fetchState)
        UserDefaults.standard.removeObject(forKey: "com.simpod.crashBreadcrumb")

        switch result {
        case .notModified:
            logger.info("Feed not modified (304): \(podcast.title, privacy: .public)")
            var updated = podcast
            updated.lastRefreshed = .now
            try dataStore.savePodcast(updated)
            return []

        case .fetched(let data, let etag, let lastModified):
            let parseState = signposter.beginInterval("xml-parse", "\(podcast.title, privacy: .public)")
            let feed = try Feed(data: data)
            signposter.endInterval("xml-parse", parseState)
            logger.info("Parsed feed OK: \(podcast.title, privacy: .public) (\(data.count) bytes)")

            let episodes = mapToEpisodes(feed, podcastID: podcast.id)
            let existingGUIDs = try dataStore.fetchExistingGUIDs(for: podcast.id)

            let newEpisodes = episodes.filter { !existingGUIDs.contains($0.guid) }

            var updated = podcast
            updated.lastRefreshed = .now
            updated.lastModified = .now
            updated.httpETag = etag
            updated.httpLastModified = lastModified
            try dataStore.saveRefreshResult(podcast: updated, newEpisodes: newEpisodes)

            return newEpisodes
        }
    }

    /// Import podcasts from OPML data. Skips already-subscribed feeds.
    /// Invariant: subscribed + skipped + failed == feedURLs.count.
    func importOPML(data: Data) async throws -> (subscribed: Int, skipped: Int, failed: Int) {
        let feedURLs = try OPMLParser.parseFeedURLs(from: data)
        let maxConcurrent = 4

        var newFeedURLs: [String] = []
        var skipped = 0
        for url in feedURLs {
            if (try? dataStore.fetchPodcast(byFeedURL: url)) != nil {
                skipped += 1
            } else {
                newFeedURLs.append(url)
            }
        }

        let (subscribed, failed) = await withTaskGroup(of: Bool.self) { group -> (Int, Int) in
            var iterator = newFeedURLs.makeIterator()

            for _ in 0..<min(maxConcurrent, newFeedURLs.count) {
                guard let feedURL = iterator.next() else { break }
                group.addTask {
                    do {
                        _ = try await self.subscribe(feedURL: feedURL)
                        return true
                    } catch {
                        logger.error("OPML import failed for \(feedURL, privacy: .public): \(error.localizedDescription, privacy: .public)")
                        return false
                    }
                }
            }

            var ok = 0
            var bad = 0
            for await success in group {
                if success { ok += 1 } else { bad += 1 }
                if let next = iterator.next() {
                    group.addTask {
                        do {
                            _ = try await self.subscribe(feedURL: next)
                            return true
                        } catch {
                            logger.error("OPML import failed for \(next, privacy: .public): \(error.localizedDescription, privacy: .public)")
                            return false
                        }
                    }
                }
            }
            return (ok, bad)
        }

        return (subscribed: subscribed, skipped: skipped, failed: failed)
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

        let batchState = signposter.beginInterval("refreshAll", "\(snapshot.count) feeds")
        let results = await withTaskGroup(of: (Podcast, [Episode]).self) { group in
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
        signposter.endInterval("refreshAll", batchState)

        let notModifiedCount = results.values.filter { $0.isEmpty }.count
        let totalNew = results.values.map(\.count).reduce(0, +)
        logger.info("Refresh complete: \(results.count) feeds, \(notModifiedCount) unchanged, \(totalNew) new episodes")

        return results
    }

    private func refreshOne(_ podcast: Podcast) async -> (Podcast, [Episode]) {
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

    // MARK: - HTTP Fetch

    private enum FeedFetchResult {
        case notModified
        case fetched(data: Data, etag: String?, lastModified: String?)
    }

    private func fetchFeedData(
        urlString: String,
        etag: String?,
        lastModified: String?
    ) async throws -> FeedFetchResult {
        guard let url = URL(string: urlString) else {
            throw FeedError.invalidURL(urlString)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        if let lastModified {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedError.invalidURL(urlString)
        }

        let newETag = httpResponse.value(forHTTPHeaderField: "ETag")
        let newLastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified")

        switch httpResponse.statusCode {
        case 304:
            return .notModified
        case 200...299:
            return .fetched(data: data, etag: newETag, lastModified: newLastModified)
        case 301, 308:
            return .fetched(data: data, etag: newETag, lastModified: newLastModified)
        case 404, 410:
            throw FeedError.feedGone(urlString)
        case 500...599:
            throw FeedError.serverError(urlString, httpResponse.statusCode)
        default:
            throw FeedError.httpError(urlString, httpResponse.statusCode)
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
    case feedGone(String)
    case serverError(String, Int)
    case httpError(String, Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): "Invalid feed URL: \(url)"
        case .feedGone(let url): "Feed no longer available: \(url)"
        case .serverError(let url, let code): "Server error \(code) for feed: \(url)"
        case .httpError(let url, let code): "HTTP error \(code) for feed: \(url)"
        }
    }
}

extension Podcast: Hashable {
    static func == (lhs: Podcast, rhs: Podcast) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
