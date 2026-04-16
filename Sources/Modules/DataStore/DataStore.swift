import Foundation
import GRDB
import Observation

/// Central data store backed by GRDB (SQLite).
/// Uses @Observable + ValueObservation for reactive SwiftUI updates.
@Observable
final class DataStore: @unchecked Sendable {
    private let db: DatabaseQueue

    var podcasts: [Podcast] = []
    var inbox: [Episode] = []
    var queue: [QueueItemWithEpisode] = []

    init(db: DatabaseQueue) throws {
        self.db = db
        try Self.migrate(db)
        startObservations()
    }

    /// Create an in-memory store for previews and tests.
    static func preview() throws -> DataStore {
        try DataStore(db: DatabaseQueue())
    }

    /// Create the production store at the default path.
    static func production() throws -> DataStore {
        let url = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("simpod.db")
        let db = try DatabaseQueue(path: url.path)
        return try DataStore(db: db)
    }

    // MARK: - Migrations

    private static func migrate(_ db: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1-initial") { db in
            try db.create(table: "podcast") { t in
                t.primaryKey("id", .text).notNull()
                t.column("feedURL", .text).notNull().unique()
                t.column("title", .text).notNull()
                t.column("author", .text).notNull().defaults(to: "")
                t.column("artworkURL", .text)
                t.column("podcastDescription", .text).notNull().defaults(to: "")
                t.column("lastRefreshed", .datetime)
                t.column("lastModified", .datetime).notNull()
            }

            try db.create(table: "episode") { t in
                t.primaryKey("id", .text).notNull()
                t.column("podcastID", .text).notNull()
                    .references("podcast", onDelete: .cascade)
                t.column("guid", .text).notNull().defaults(to: "")
                t.column("title", .text).notNull()
                t.column("audioURL", .text).notNull()
                t.column("localFilePath", .text)
                t.column("duration", .double).notNull().defaults(to: 0)
                t.column("playbackPosition", .double).notNull().defaults(to: 0)
                t.column("publishedDate", .datetime).notNull()
                t.column("episodeDescription", .text).notNull().defaults(to: "")
                t.column("status", .text).notNull().defaults(to: "inbox")
                t.column("downloadProgress", .double).notNull().defaults(to: 0)
                t.column("lastModified", .datetime).notNull()
                t.uniqueKey(["podcastID", "guid"])
            }

            try db.create(table: "queueItem") { t in
                t.primaryKey("id", .text).notNull()
                t.column("episodeID", .text).notNull().unique()
                    .references("episode", onDelete: .cascade)
                t.column("order", .integer).notNull()
                t.column("addedDate", .datetime).notNull()
                t.column("lastModified", .datetime).notNull()
            }

            try db.create(table: "tag") { t in
                t.primaryKey("id", .text).notNull()
                t.column("name", .text).notNull().unique()
                t.column("color", .text).notNull().defaults(to: "#007AFF")
            }

            try db.create(table: "episodeTag") { t in
                t.column("episodeID", .text).notNull()
                    .references("episode", onDelete: .cascade)
                t.column("tagID", .text).notNull()
                    .references("tag", onDelete: .cascade)
                t.primaryKey(["episodeID", "tagID"])
            }

            try db.create(table: "podcastTag") { t in
                t.column("podcastID", .text).notNull()
                    .references("podcast", onDelete: .cascade)
                t.column("tagID", .text).notNull()
                    .references("tag", onDelete: .cascade)
                t.primaryKey(["podcastID", "tagID"])
            }
        }

        try migrator.migrate(db)
    }

    // MARK: - Observations

    private var observationCancellables: [AnyDatabaseCancellable] = []

    private func startObservations() {
        let db = self.db

        // Dispatch to MainActor — GRDB's ValueObservation.start(in:) is
        // @MainActor-isolated because it delivers updates on the main thread.
        Task { @MainActor [weak self] in
            guard let self else { return }

            let podcastCancellable = ValueObservation.tracking { db in
                try Podcast.order(Podcast.Columns.title).fetchAll(db)
            }.start(in: db) { error in
                print("Podcast observation error: \(error)")
            } onChange: { [weak self] podcasts in
                self?.podcasts = podcasts
            }

            let inboxCancellable = ValueObservation.tracking { db in
                try Episode
                    .filter(Episode.Columns.status == EpisodeStatus.inbox.rawValue)
                    .order(Episode.Columns.publishedDate.desc)
                    .fetchAll(db)
            }.start(in: db) { error in
                print("Inbox observation error: \(error)")
            } onChange: { [weak self] episodes in
                self?.inbox = episodes
            }

            let queueCancellable = ValueObservation.tracking { db in
                try QueueItem
                    .order(QueueItem.Columns.order)
                    .including(required: QueueItem.episode)
                    .asRequest(of: QueueItemWithEpisode.self)
                    .fetchAll(db)
            }.start(in: db) { error in
                print("Queue observation error: \(error)")
            } onChange: { [weak self] items in
                self?.queue = items
            }

            self.observationCancellables = [
                podcastCancellable,
                inboxCancellable,
                queueCancellable
            ]
        }
    }

    // MARK: - Podcast CRUD

    func savePodcast(_ podcast: Podcast) throws {
        try db.write { db in
            try podcast.save(db)
        }
    }

    func deletePodcast(_ podcast: Podcast) throws {
        try db.write { db in
            _ = try podcast.delete(db)
        }
    }

    func fetchPodcast(byFeedURL url: String) throws -> Podcast? {
        try db.read { db in
            try Podcast.filter(Podcast.Columns.feedURL == url).fetchOne(db)
        }
    }

    // MARK: - Episode CRUD

    func saveEpisode(_ episode: Episode) throws {
        try db.write { db in
            try episode.save(db)
        }
    }

    func saveEpisodes(_ episodes: [Episode]) throws {
        try db.write { db in
            for episode in episodes {
                try episode.save(db)
            }
        }
    }

    func updateEpisodeStatus(_ episodeID: UUID, status: EpisodeStatus) throws {
        try db.write { db in
            if var episode = try Episode.fetchOne(db, id: episodeID) {
                episode.status = status
                episode.lastModified = .now
                try episode.update(db)
            }
        }
    }

    func updatePlaybackPosition(_ episodeID: UUID, position: TimeInterval) throws {
        try db.write { db in
            if var episode = try Episode.fetchOne(db, id: episodeID) {
                episode.playbackPosition = position
                episode.lastModified = .now
                try episode.update(db)
            }
        }
    }

    func fetchEpisodes(for podcastID: UUID) throws -> [Episode] {
        try db.read { db in
            try Episode
                .filter(Episode.Columns.podcastID == podcastID)
                .order(Episode.Columns.publishedDate.desc)
                .fetchAll(db)
        }
    }

    func updateLocalFilePath(_ episodeID: UUID, path: String?) throws {
        try db.write { db in
            if var episode = try Episode.fetchOne(db, id: episodeID) {
                episode.localFilePath = path
                episode.lastModified = .now
                try episode.update(db)
            }
        }
    }

    // MARK: - Queue Operations

    func addToQueue(episodeID: UUID) throws {
        try db.write { db in
            // Get next order position
            let maxOrder = try QueueItem.select(max(QueueItem.Columns.order)).fetchOne(db) ?? -1
            let item = QueueItem(episodeID: episodeID, order: maxOrder + 1)
            try item.save(db)

            // Update episode status
            if var episode = try Episode.fetchOne(db, id: episodeID) {
                episode.status = .queued
                episode.lastModified = .now
                try episode.update(db)
            }
        }
    }

    func removeFromQueue(episodeID: UUID) throws {
        try db.write { db in
            _ = try QueueItem
                .filter(QueueItem.Columns.episodeID == episodeID)
                .deleteAll(db)
        }
    }

    func reorderQueue(itemIDs: [UUID]) throws {
        try db.write { db in
            for (index, id) in itemIDs.enumerated() {
                if var item = try QueueItem.fetchOne(db, id: id) {
                    item.order = index
                    item.lastModified = .now
                    try item.update(db)
                }
            }
        }
    }

    // MARK: - Inbox Operations

    func triageToQueue(episodeID: UUID) throws {
        try addToQueue(episodeID: episodeID)
    }

    func triageToSkip(episodeID: UUID) throws {
        try updateEpisodeStatus(episodeID, status: .skipped)
    }

    var inboxCount: Int { inbox.count }

    // MARK: - Direct Queries (for tests and sync)

    func fetchQueue() throws -> [QueueItemWithEpisode] {
        try db.read { db in
            try QueueItem
                .order(QueueItem.Columns.order)
                .including(required: QueueItem.episode)
                .asRequest(of: QueueItemWithEpisode.self)
                .fetchAll(db)
        }
    }

    // MARK: - Sync Operations

    func fetchPodcast(byID id: UUID) throws -> Podcast? {
        try db.read { db in try Podcast.fetchOne(db, id: id) }
    }

    func fetchEpisode(byID id: UUID) throws -> Episode? {
        try db.read { db in try Episode.fetchOne(db, id: id) }
    }

    func fetchQueueItem(byID id: UUID) throws -> QueueItem? {
        try db.read { db in try QueueItem.fetchOne(db, id: id) }
    }

    func fetchAllPodcasts() throws -> [Podcast] {
        try db.read { db in try Podcast.fetchAll(db) }
    }

    func fetchAllEpisodes() throws -> [Episode] {
        try db.read { db in try Episode.fetchAll(db) }
    }

    func fetchAllQueueItems() throws -> [QueueItem] {
        try db.read { db in try QueueItem.fetchAll(db) }
    }

    func saveFromSync(podcast: Podcast) throws {
        try db.write { db in try podcast.save(db) }
    }

    func saveFromSync(episode: Episode) throws {
        try db.write { db in try episode.save(db) }
    }

    func saveFromSync(queueItem: QueueItem) throws {
        try db.write { db in try queueItem.save(db) }
    }

    func deleteByID<T: FetchableRecord & PersistableRecord & Identifiable>(
        _ type: T.Type, id: T.ID
    ) throws where T.ID: DatabaseValueConvertible {
        try db.write { db in _ = try T.deleteOne(db, id: id) }
    }
}

/// A queue item joined with its episode data.
struct QueueItemWithEpisode: Codable, Sendable, FetchableRecord {
    var queueItem: QueueItem
    var episode: Episode
}
