import Combine
import Foundation
import GRDB
import Observation

/// Central data store backed by GRDB (SQLite).
/// Uses @Observable + ValueObservation for reactive SwiftUI updates.
@Observable
final class DataStore: @unchecked Sendable {
    private static let recentEpisodeCutoff: TimeInterval = 24 * 60 * 60 // 24 hours
    private let db: any DatabaseWriter

    /// Set post-init by SimpodApp to wire DataStore mutations into SyncEngine.
    /// `weak` to avoid a retain cycle with SyncEngine, which holds a strong
    /// reference to DataStore.
    weak var syncCoordinator: (any SyncCoordinator)?

    var podcasts: [Podcast] = []
    var inbox: [EpisodeWithPodcast] = []
    var queue: [QueueItemWithEpisodeAndPodcast] = []
    var reminders: [EpisodeWithPodcast] = []
    /// Stored to keep ContentView's tab badge from re-observing `inbox`
    /// and re-filtering on every render (see plan §Change 2).
    var inboxCount: Int = 0

    #if DEBUG
    /// Suppresses the auto-refresh in ContentView's `.task` so a debug-driven
    /// burst is the only refresh trigger during the deterministic UI test.
    nonisolated(unsafe) static var suppressInitialAutoRefresh: Bool = false

    /// Debounce window in ms for inbox/queue observations. Read once at type
    /// initialization. Defaults to 50; overridable in DEBUG via the
    /// `SIMPOD_DEBOUNCE_MS` env var (set 0 for the negative-control run).
    /// In RELEASE this branch is stripped — the sink chain uses the literal
    /// `.milliseconds(50)` exactly as in commit a1433c4.
    static let debounceMilliseconds: Int = {
        if let raw = ProcessInfo.processInfo.environment["SIMPOD_DEBOUNCE_MS"],
           let ms = Int(raw) {
            return ms
        }
        return 50
    }()

    var inboxSinkCount: Int = 0
    var saveRefreshCount: Int = 0
    var lastInboxPayloadCount: Int = 0
    #endif

    init(db: any DatabaseWriter) throws {
        self.db = db
        try Self.migrate(db)
        startObservations()
    }

    /// Create an in-memory store for previews and tests.
    static func preview() throws -> DataStore {
        try DataStore(db: DatabaseQueue())
    }

    /// Create the production store at the default path.
    /// Uses DatabasePool (WAL) so SwiftUI reads never block on refresh writes.
    static func production() throws -> DataStore {
        let url = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("simpod.db")
        let db = try DatabasePool(path: url.path)
        return try DataStore(db: db)
    }

    // MARK: - Migrations

    private static func migrate(_ db: any DatabaseWriter) throws {
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

        migrator.registerMigration("v2-hidden-until") { db in
            try db.alter(table: "episode") { t in
                t.add(column: "hiddenUntil", .datetime)
            }
        }

        migrator.registerMigration("v3-fts5-search") { db in
            try db.execute(sql: """
                CREATE VIRTUAL TABLE podcastSearch USING fts5(
                    title, author, podcastDescription,
                    content=podcast, content_rowid=rowid,
                    tokenize='unicode61'
                );

                INSERT INTO podcastSearch(podcastSearch) VALUES('rebuild');

                CREATE TRIGGER podcast_ai AFTER INSERT ON podcast BEGIN
                    INSERT INTO podcastSearch(rowid, title, author, podcastDescription)
                    VALUES (NEW.rowid, NEW.title, NEW.author, NEW.podcastDescription);
                END;
                CREATE TRIGGER podcast_ad AFTER DELETE ON podcast BEGIN
                    INSERT INTO podcastSearch(podcastSearch, rowid, title, author, podcastDescription)
                    VALUES ('delete', OLD.rowid, OLD.title, OLD.author, OLD.podcastDescription);
                END;
                CREATE TRIGGER podcast_au AFTER UPDATE ON podcast BEGIN
                    INSERT INTO podcastSearch(podcastSearch, rowid, title, author, podcastDescription)
                    VALUES ('delete', OLD.rowid, OLD.title, OLD.author, OLD.podcastDescription);
                    INSERT INTO podcastSearch(rowid, title, author, podcastDescription)
                    VALUES (NEW.rowid, NEW.title, NEW.author, NEW.podcastDescription);
                END;

                CREATE VIRTUAL TABLE episodeSearch USING fts5(
                    title, episodeDescription,
                    content=episode, content_rowid=rowid,
                    tokenize='unicode61'
                );

                INSERT INTO episodeSearch(episodeSearch) VALUES('rebuild');

                CREATE TRIGGER episode_ai AFTER INSERT ON episode BEGIN
                    INSERT INTO episodeSearch(rowid, title, episodeDescription)
                    VALUES (NEW.rowid, NEW.title, NEW.episodeDescription);
                END;
                CREATE TRIGGER episode_ad AFTER DELETE ON episode BEGIN
                    INSERT INTO episodeSearch(episodeSearch, rowid, title, episodeDescription)
                    VALUES ('delete', OLD.rowid, OLD.title, OLD.episodeDescription);
                END;
                CREATE TRIGGER episode_au AFTER UPDATE ON episode BEGIN
                    INSERT INTO episodeSearch(episodeSearch, rowid, title, episodeDescription)
                    VALUES ('delete', OLD.rowid, OLD.title, OLD.episodeDescription);
                    INSERT INTO episodeSearch(rowid, title, episodeDescription)
                    VALUES (NEW.rowid, NEW.title, NEW.episodeDescription);
                END;
                """)
        }

        migrator.registerMigration("v4-conditional-get") { db in
            try db.alter(table: "podcast") { t in
                t.add(column: "httpETag", .text)
                t.add(column: "httpLastModified", .text)
            }
        }

        migrator.registerMigration("v5-feed-body-hash") { db in
            try db.alter(table: "podcast") { t in
                t.add(column: "feedBodyHash", .text)
            }
        }

        migrator.registerMigration("v6-cloudkit-system-fields") { db in
            try db.alter(table: "podcast") { t in
                t.add(column: "cloudKitSystemFields", .blob)
            }
            try db.alter(table: "episode") { t in
                t.add(column: "cloudKitSystemFields", .blob)
            }
            try db.alter(table: "queueItem") { t in
                t.add(column: "cloudKitSystemFields", .blob)
            }
        }

        try migrator.migrate(db)
    }

    // MARK: - Observations

    private var observationCancellables: [AnyDatabaseCancellable] = []
    private var combineCancellables: Set<AnyCancellable> = []
    private var timerCancellable: AnyCancellable?

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

            // Inbox & queue use Combine debounce(50ms) to coalesce
            // refresh-burst observation deliveries onto a single MainActor
            // assignment per silence window — see plan §C.
            ValueObservation.tracking { db in
                try Episode
                    .filter(
                        Episode.Columns.status == EpisodeStatus.inbox.rawValue
                        || (Episode.Columns.status == EpisodeStatus.hidden.rawValue
                            && Episode.Columns.hiddenUntil <= Date.now)
                    )
                    .order(Episode.Columns.publishedDate.desc)
                    .including(required: Episode.podcast)
                    .asRequest(of: EpisodeWithPodcast.self)
                    .fetchAll(db)
            }
            .publisher(in: db)
            #if DEBUG
            .debounce(for: .milliseconds(Self.debounceMilliseconds), scheduler: DispatchQueue.main)
            #else
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            #endif
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Inbox observation error: \(error)")
                    }
                },
                receiveValue: { [weak self] episodes in
                    guard let self else { return }
                    self.inbox = episodes
                    let cutoff = Date.now.addingTimeInterval(-Self.recentEpisodeCutoff)
                    self.inboxCount = episodes.filter { $0.episode.publishedDate >= cutoff }.count
                    #if DEBUG
                    self.inboxSinkCount += 1
                    self.lastInboxPayloadCount = episodes.count
                    #endif
                }
            )
            .store(in: &self.combineCancellables)

            ValueObservation.tracking { db in
                try QueueItem
                    .order(QueueItem.Columns.order)
                    .including(required: QueueItem.episode
                        .including(required: Episode.podcast))
                    .asRequest(of: QueueItemWithEpisodeAndPodcast.self)
                    .fetchAll(db)
            }
            .publisher(in: db)
            #if DEBUG
            .debounce(for: .milliseconds(Self.debounceMilliseconds), scheduler: DispatchQueue.main)
            #else
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            #endif
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Queue observation error: \(error)")
                    }
                },
                receiveValue: { [weak self] items in
                    self?.queue = items
                }
            )
            .store(in: &self.combineCancellables)

            let remindersCancellable = ValueObservation.tracking { db in
                try Episode
                    .filter(
                        Episode.Columns.status == EpisodeStatus.hidden.rawValue
                        && Episode.Columns.hiddenUntil > Date.now
                    )
                    .order(Episode.Columns.hiddenUntil)
                    .including(required: Episode.podcast)
                    .asRequest(of: EpisodeWithPodcast.self)
                    .fetchAll(db)
            }.start(in: db) { error in
                print("Reminders observation error: \(error)")
            } onChange: { [weak self] episodes in
                self?.reminders = episodes
                try? self?.unhideExpiredEpisodes()
            }

            self.observationCancellables = [
                podcastCancellable,
                remindersCancellable
            ]

            // 60-second timer to sweep expired hidden episodes
            self.timerCancellable = Timer.publish(every: 60, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self else { return }
                    try? self.unhideExpiredEpisodes()
                }

            // Startup cleanup: unhide any episodes that expired while the app was closed
            try? self.unhideExpiredEpisodes()
        }
    }

    // MARK: - Podcast CRUD

    func savePodcast(_ podcast: Podcast) throws {
        try db.write { db in
            try podcast.save(db)
        }
        syncCoordinator?.markDirty(id: podcast.id)
    }

    func deletePodcast(_ podcast: Podcast) throws {
        try db.write { db in
            _ = try podcast.delete(db)
        }
        syncCoordinator?.markDeleted(id: podcast.id)
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
        syncCoordinator?.markDirty(id: episode.id)
    }

    func saveEpisodes(_ episodes: [Episode]) throws {
        try db.write { db in
            for episode in episodes {
                try episode.save(db)
            }
        }
        for episode in episodes {
            syncCoordinator?.markDirty(id: episode.id)
        }
    }

    func updateEpisodeStatus(_ episodeID: UUID, status: EpisodeStatus) throws {
        let didUpdate: Bool = try db.write { db in
            if var episode = try Episode.fetchOne(db, id: episodeID) {
                episode.status = status
                episode.lastModified = .now
                try episode.update(db)
                return true
            }
            return false
        }
        if didUpdate { syncCoordinator?.markDirty(id: episodeID) }
    }

    func updatePlaybackPosition(_ episodeID: UUID, position: TimeInterval) throws {
        let didUpdate: Bool = try db.write { db in
            if var episode = try Episode.fetchOne(db, id: episodeID) {
                episode.playbackPosition = position
                episode.lastModified = .now
                try episode.update(db)
                return true
            }
            return false
        }
        if didUpdate { syncCoordinator?.markDirty(id: episodeID) }
    }

    func fetchEpisodes(for podcastID: UUID) throws -> [Episode] {
        try db.read { db in
            try Episode
                .filter(Episode.Columns.podcastID == podcastID)
                .order(Episode.Columns.publishedDate.desc)
                .fetchAll(db)
        }
    }

    func fetchExistingGUIDs(for podcastID: UUID) throws -> Set<String> {
        try db.read { db in
            let guids = try String.fetchAll(db, sql:
                "SELECT guid FROM episode WHERE podcastID = ?",
                arguments: [podcastID.uuidString])
            return Set(guids)
        }
    }

    func saveRefreshResult(podcast: Podcast, newEpisodes: [Episode]) throws {
        // No-op skip: if neither the podcast row nor any episode would be
        // written, do not even open a write transaction. This prevents
        // spurious ValueObservation fires (R1) and CKSyncEngine pushes (M2).
        let stored = try db.read { db in try Podcast.fetchOne(db, id: podcast.id) }
        let podcastChanged = stored.map { !$0.refreshFieldsEqual(podcast) } ?? true
        guard podcastChanged || !newEpisodes.isEmpty else { return }

        try db.write { db in
            if podcastChanged {
                try podcast.save(db)
            }
            for episode in newEpisodes {
                try episode.save(db)
            }
            #if DEBUG
            self.saveRefreshCount += 1
            #endif
        }
        // markDirty only for what was actually written. Refresh-time
        // no-op (the early `guard` above) already returned without touching
        // the sync layer, so v5's no-write quietude survives.
        if podcastChanged { syncCoordinator?.markDirty(id: podcast.id) }
        for episode in newEpisodes { syncCoordinator?.markDirty(id: episode.id) }
    }

    func updateLocalFilePath(_ episodeID: UUID, path: String?) throws {
        // Sync skip: localFilePath is device-local, filtered out of
        // ckRecord(for: Episode) at SyncEngine.swift:175. No markDirty.
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
        let result: (queueItemID: UUID, episodeUpdated: Bool) = try db.write { db in
            let maxOrder = try QueueItem.select(max(QueueItem.Columns.order)).fetchOne(db) ?? -1
            let item = QueueItem(episodeID: episodeID, order: maxOrder + 1)
            try item.save(db)

            var episodeUpdated = false
            if var episode = try Episode.fetchOne(db, id: episodeID) {
                episode.status = .queued
                episode.lastModified = .now
                try episode.update(db)
                episodeUpdated = true
            }
            return (item.id, episodeUpdated)
        }
        syncCoordinator?.markDirty(id: result.queueItemID)
        if result.episodeUpdated { syncCoordinator?.markDirty(id: episodeID) }
    }

    func removeFromQueue(episodeID: UUID) throws {
        let removedIDs: [UUID] = try db.write { db in
            let items = try QueueItem
                .filter(QueueItem.Columns.episodeID == episodeID)
                .fetchAll(db)
            _ = try QueueItem
                .filter(QueueItem.Columns.episodeID == episodeID)
                .deleteAll(db)
            return items.map(\.id)
        }
        for id in removedIDs { syncCoordinator?.markDeleted(id: id) }
    }

    func reorderQueue(itemIDs: [UUID]) throws {
        let updatedIDs: [UUID] = try db.write { db in
            var updated: [UUID] = []
            for (index, id) in itemIDs.enumerated() {
                if var item = try QueueItem.fetchOne(db, id: id) {
                    if item.order != index {
                        item.order = index
                        item.lastModified = .now
                        try item.update(db)
                        updated.append(id)
                    }
                }
            }
            return updated
        }
        for id in updatedIDs { syncCoordinator?.markDirty(id: id) }
    }

    // MARK: - Inbox Operations

    func triageToQueue(episodeID: UUID) throws {
        try addToQueue(episodeID: episodeID)
    }

    func triageToSkip(episodeID: UUID) throws {
        try updateEpisodeStatus(episodeID, status: .skipped)
    }

    // MARK: - Local Search

    struct LocalSearchResults {
        var podcasts: [Podcast]
        var episodes: [EpisodeWithPodcast]
    }

    func searchLocal(query: String) throws -> LocalSearchResults {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return LocalSearchResults(podcasts: [], episodes: [])
        }

        let ftsQuery = trimmed.split(separator: " ")
            .map { "\($0)*" }
            .joined(separator: " ")

        return try db.read { db in
            let podcastRowIDs = try Int64.fetchAll(db, sql: """
                SELECT rowid FROM podcastSearch WHERE podcastSearch MATCH ? ORDER BY rank
                """, arguments: [ftsQuery])

            let podcasts: [Podcast]
            if podcastRowIDs.isEmpty {
                podcasts = []
            } else {
                let placeholders = podcastRowIDs.map { _ in "?" }.joined(separator: ",")
                podcasts = try Podcast.fetchAll(db, sql: """
                    SELECT * FROM podcast WHERE rowid IN (\(placeholders))
                    """, arguments: StatementArguments(podcastRowIDs))
            }

            let episodeRowIDs = try Int64.fetchAll(db, sql: """
                SELECT rowid FROM episodeSearch WHERE episodeSearch MATCH ? ORDER BY rank
                """, arguments: [ftsQuery])

            var episodes: [EpisodeWithPodcast] = []
            if !episodeRowIDs.isEmpty {
                let placeholders = episodeRowIDs.map { _ in "?" }.joined(separator: ",")
                let matchedEpisodes = try Episode.fetchAll(db, sql: """
                    SELECT * FROM episode WHERE rowid IN (\(placeholders))
                    """, arguments: StatementArguments(episodeRowIDs))

                for episode in matchedEpisodes {
                    if let podcast = try Podcast.fetchOne(db, id: episode.podcastID) {
                        episodes.append(EpisodeWithPodcast(episode: episode, podcast: podcast))
                    }
                }
            }

            return LocalSearchResults(podcasts: podcasts, episodes: episodes)
        }
    }

    // MARK: - Direct Queries (for tests and sync)

    func fetchQueue() throws -> [QueueItemWithEpisodeAndPodcast] {
        try db.read { db in
            try QueueItem
                .order(QueueItem.Columns.order)
                .including(required: QueueItem.episode
                    .including(required: Episode.podcast))
                .asRequest(of: QueueItemWithEpisodeAndPodcast.self)
                .fetchAll(db)
        }
    }

    // MARK: - Test Helpers

    /// Directly set hiddenUntil for a hidden episode. For use in tests only.
    func setHiddenUntilForTesting(episodeID: UUID, date: Date) throws {
        try db.write { db in
            if var episode = try Episode.fetchOne(db, id: episodeID) {
                episode.hiddenUntil = date
                episode.lastModified = .now
                try episode.update(db)
            }
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

    /// Sync skip: inbound write path. Calling markDirty here would create
    /// an upload loop with CKSyncEngine. Persists model fields and the
    /// CloudKit system-fields blob in one transaction so a fetched record's
    /// recordChangeTag is preserved for the next outbound save.
    func saveFromSync(podcast: Podcast, systemFields: Data?) throws {
        var copy = podcast
        if let systemFields { copy.cloudKitSystemFields = systemFields }
        try db.write { db in try copy.save(db) }
    }

    func saveFromSync(episode: Episode, systemFields: Data?) throws {
        var copy = episode
        if let systemFields { copy.cloudKitSystemFields = systemFields }
        try db.write { db in try copy.save(db) }
    }

    func saveFromSync(queueItem: QueueItem, systemFields: Data?) throws {
        var copy = queueItem
        if let systemFields { copy.cloudKitSystemFields = systemFields }
        try db.write { db in try copy.save(db) }
    }

    /// Persist a CloudKit system-fields blob alone (no model field changes).
    /// Called from SyncEngine after a successful upload echo. Sync skip — never
    /// triggers markDirty (would loop). Uses the model's Codable filter to
    /// match the same UUID encoding GRDB used at insert time.
    func saveSystemFields(podcastID: UUID, data: Data) throws {
        try db.write { db in
            try Podcast
                .filter(Podcast.Columns.id == podcastID)
                .updateAll(db, [Podcast.Columns.cloudKitSystemFields.set(to: data)])
        }
    }

    func saveSystemFields(episodeID: UUID, data: Data) throws {
        try db.write { db in
            try Episode
                .filter(Episode.Columns.id == episodeID)
                .updateAll(db, [Episode.Columns.cloudKitSystemFields.set(to: data)])
        }
    }

    func saveSystemFields(queueItemID: UUID, data: Data) throws {
        try db.write { db in
            try QueueItem
                .filter(QueueItem.Columns.id == queueItemID)
                .updateAll(db, [QueueItem.Columns.cloudKitSystemFields.set(to: data)])
        }
    }

    /// Sync skip: only invoked by inbound applyDeletion. UI deletes go through
    /// typed wrappers (deletePodcast, etc.), which mark dirty/deleted themselves.
    func deleteByID<T: FetchableRecord & PersistableRecord & Identifiable>(
        _ type: T.Type, id: T.ID
    ) throws where T.ID: DatabaseValueConvertible {
        try db.write { db in _ = try T.deleteOne(db, id: id) }
    }

    // MARK: - Extended Queue Operations

    /// Move an existing queue item to position 0 (play next), normalizing all orders.
    func moveToTop(episodeID: UUID) throws {
        let dirtyIDs: [UUID] = try db.write { db in
            var items = try QueueItem
                .order(QueueItem.Columns.order)
                .fetchAll(db)

            guard let idx = items.firstIndex(where: { $0.episodeID == episodeID }) else { return [] }

            let item = items.remove(at: idx)
            items.insert(item, at: 0)

            var dirty: [UUID] = []
            for (index, var qi) in items.enumerated() {
                if qi.order != index {
                    qi.order = index
                    qi.lastModified = .now
                    try qi.update(db)
                    dirty.append(qi.id)
                }
            }
            return dirty
        }
        for id in dirtyIDs { syncCoordinator?.markDirty(id: id) }
    }

    /// Move an existing queue item to the last position, normalizing all orders.
    func moveToBottom(episodeID: UUID) throws {
        let dirtyIDs: [UUID] = try db.write { db in
            var items = try QueueItem
                .order(QueueItem.Columns.order)
                .fetchAll(db)

            guard let idx = items.firstIndex(where: { $0.episodeID == episodeID }) else { return [] }

            let item = items.remove(at: idx)
            items.append(item)

            var dirty: [UUID] = []
            for (index, var qi) in items.enumerated() {
                if qi.order != index {
                    qi.order = index
                    qi.lastModified = .now
                    try qi.update(db)
                    dirty.append(qi.id)
                }
            }
            return dirty
        }
        for id in dirtyIDs { syncCoordinator?.markDirty(id: id) }
    }

    /// Add a NEW episode to the queue at position 0, shifting all existing items down.
    func addToQueueAtTop(episodeID: UUID) throws {
        let result: (queueDirty: [UUID], episodeUpdated: Bool) = try db.write { db in
            let existing = try QueueItem
                .order(QueueItem.Columns.order)
                .fetchAll(db)

            var dirty: [UUID] = []
            for var qi in existing {
                qi.order += 1
                qi.lastModified = .now
                try qi.update(db)
                dirty.append(qi.id)
            }

            let newItem = QueueItem(episodeID: episodeID, order: 0)
            try newItem.save(db)
            dirty.append(newItem.id)

            var episodeUpdated = false
            if var episode = try Episode.fetchOne(db, id: episodeID) {
                episode.status = .queued
                episode.lastModified = .now
                try episode.update(db)
                episodeUpdated = true
            }
            return (dirty, episodeUpdated)
        }
        for id in result.queueDirty { syncCoordinator?.markDirty(id: id) }
        if result.episodeUpdated { syncCoordinator?.markDirty(id: episodeID) }
    }

    /// Hide an episode for 24 hours. Removes it from the queue if present.
    func hideEpisode(_ episodeID: UUID) throws {
        let result: (deletedQueueIDs: [UUID], episodeUpdated: Bool) = try db.write { db in
            let removedItems = try QueueItem
                .filter(QueueItem.Columns.episodeID == episodeID)
                .fetchAll(db)
            _ = try QueueItem
                .filter(QueueItem.Columns.episodeID == episodeID)
                .deleteAll(db)

            var episodeUpdated = false
            if var episode = try Episode.fetchOne(db, id: episodeID) {
                episode.status = .hidden
                episode.hiddenUntil = Date.now + 86400
                episode.lastModified = .now
                try episode.update(db)
                episodeUpdated = true
            }
            return (removedItems.map(\.id), episodeUpdated)
        }
        for id in result.deletedQueueIDs { syncCoordinator?.markDeleted(id: id) }
        if result.episodeUpdated { syncCoordinator?.markDirty(id: episodeID) }
    }

    /// Return a hidden episode to the inbox, clearing the reminder date.
    func unhideEpisode(_ episodeID: UUID) throws {
        let didUpdate: Bool = try db.write { db in
            if var episode = try Episode.fetchOne(db, id: episodeID) {
                episode.status = .inbox
                episode.hiddenUntil = nil
                episode.lastModified = .now
                try episode.update(db)
                return true
            }
            return false
        }
        if didUpdate { syncCoordinator?.markDirty(id: episodeID) }
    }

    // MARK: - Playback Continuity

    /// Move an episode to queue position 0 and start playback.
    /// Deduplicates: removes any existing queue entry for this episode first.
    /// Audio engine calls occur AFTER the db.write transaction commits
    /// to prevent reentrant writes (AudioEngine.stop → persistPosition → db.write).
    func moveEpisodeToTopAndPlay(_ episodeID: UUID, audioEngine: AudioEngine) throws {
        struct WriteResult {
            var playbackInfo: (url: URL, isLocal: Bool, position: TimeInterval)?
            var dirtyQueueIDs: [UUID] = []
            var deletedQueueIDs: [UUID] = []
            var episodeUpdated: Bool = false
        }

        let result: WriteResult = try db.write { db in
            var out = WriteResult()

            let removed = try QueueItem
                .filter(QueueItem.Columns.episodeID == episodeID)
                .fetchAll(db)
            _ = try QueueItem
                .filter(QueueItem.Columns.episodeID == episodeID)
                .deleteAll(db)
            out.deletedQueueIDs = removed.map(\.id)

            let existing = try QueueItem
                .order(QueueItem.Columns.order)
                .fetchAll(db)

            for var qi in existing {
                qi.order += 1
                qi.lastModified = .now
                try qi.update(db)
                out.dirtyQueueIDs.append(qi.id)
            }

            let newItem = QueueItem(episodeID: episodeID, order: 0)
            try newItem.save(db)
            out.dirtyQueueIDs.append(newItem.id)

            if var episode = try Episode.fetchOne(db, id: episodeID) {
                episode.status = .queued
                episode.lastModified = .now
                try episode.update(db)
                out.episodeUpdated = true

                if let localPath = episode.localFilePath,
                   let fileURL = URL(string: localPath) ?? URL(fileURLWithPath: localPath) as URL? {
                    out.playbackInfo = (url: fileURL, isLocal: true, position: episode.playbackPosition)
                } else if let remoteURL = URL(string: episode.audioURL) {
                    out.playbackInfo = (url: remoteURL, isLocal: false, position: episode.playbackPosition)
                }
            }
            return out
        }

        for id in result.deletedQueueIDs { syncCoordinator?.markDeleted(id: id) }
        for id in result.dirtyQueueIDs { syncCoordinator?.markDirty(id: id) }
        if result.episodeUpdated { syncCoordinator?.markDirty(id: episodeID) }

        if let info = result.playbackInfo {
            if info.isLocal {
                try audioEngine.play(fileURL: info.url, episodeID: episodeID, startPosition: info.position)
            } else {
                audioEngine.playStream(url: info.url, episodeID: episodeID, startPosition: info.position)
            }
        }
    }

    /// Append one random eligible unplayed episode from the last 24 hours to the queue,
    /// but only if no next queue item exists after the currently playing one.
    func appendRandomRecentUnplayedEpisodeIfNeeded(currentlyPlayingID: UUID?) throws {
        let dirty: (queueItemID: UUID?, episodeID: UUID?) = try db.write { db in
            let items = try QueueItem
                .order(QueueItem.Columns.order)
                .fetchAll(db)

            if let playingID = currentlyPlayingID,
               let currentIndex = items.firstIndex(where: { $0.episodeID == playingID }),
               currentIndex + 1 < items.count {
                return (nil, nil)
            }

            let currentQueueEpisodeIDs = items.map(\.episodeID)
            let cutoff = Date.now.addingTimeInterval(-86400)

            var candidates = try Episode
                .filter(Episode.Columns.publishedDate > cutoff)
                .filter(Episode.Columns.status == EpisodeStatus.inbox.rawValue)
                .filter(Episode.Columns.playbackPosition == 0)
                .fetchAll(db)

            candidates = candidates.filter { ep in
                !currentQueueEpisodeIDs.contains(ep.id) && ep.id != currentlyPlayingID
            }

            guard !candidates.isEmpty else { return (nil, nil) }

            let picked = candidates.randomElement()!
            let maxOrder = items.last?.order ?? -1
            let newItem = QueueItem(episodeID: picked.id, order: maxOrder + 1)
            try newItem.save(db)

            var episode = picked
            episode.status = .queued
            episode.lastModified = .now
            try episode.update(db)

            return (newItem.id, picked.id)
        }
        if let qid = dirty.queueItemID { syncCoordinator?.markDirty(id: qid) }
        if let eid = dirty.episodeID { syncCoordinator?.markDirty(id: eid) }
    }

    // MARK: - Debug / Test Hooks

    /// Wipe all rows from podcast/episode/queueItem tables. Always-compiled
    /// (so it can be called from a debug-gated env-var hook), but has no
    /// production caller — verified by Scripts/check-debug-guards.sh §G-RELEASE.
    func wipeAll() throws {
        let deleted: (queueIDs: [UUID], episodeIDs: [UUID], podcastIDs: [UUID]) = try db.write { db in
            let qids = try QueueItem.fetchAll(db).map(\.id)
            let eids = try Episode.fetchAll(db).map(\.id)
            let pids = try Podcast.fetchAll(db).map(\.id)
            _ = try QueueItem.deleteAll(db)
            _ = try Episode.deleteAll(db)
            _ = try Podcast.deleteAll(db)
            return (qids, eids, pids)
        }
        for id in deleted.queueIDs { syncCoordinator?.markDeleted(id: id) }
        for id in deleted.episodeIDs { syncCoordinator?.markDeleted(id: id) }
        for id in deleted.podcastIDs { syncCoordinator?.markDeleted(id: id) }
    }

    #if DEBUG
    /// Insert N podcast rows whose feedURL resolves to StubFeedURLProtocol fixtures.
    /// Used by the deterministic refresh-debounce UI test (plan §F.2).
    func seedPodcasts(count: Int) throws {
        try db.write { db in
            for i in 1...count {
                let n = String(format: "%03d", i)
                let podcast = Podcast(
                    feedURL: "stub://feed-\(n)",
                    title: "Stub Feed \(n)"
                )
                try podcast.save(db)
            }
        }
    }

    /// Reset the inbox/saveRefresh debug counters to zero. Test calls this
    /// just before triggering the burst so post-burst reads are unambiguous.
    func resetDebugCounters() {
        inboxSinkCount = 0
        saveRefreshCount = 0
        lastInboxPayloadCount = 0
    }

    /// Synchronous read of the inbox query, exposed for the debug panel's
    /// three-way exact-match check (plan §H).
    func debugInboxEpisodeCount() throws -> Int {
        try db.read { db in
            try Episode
                .filter(
                    Episode.Columns.status == EpisodeStatus.inbox.rawValue
                    || (Episode.Columns.status == EpisodeStatus.hidden.rawValue
                        && Episode.Columns.hiddenUntil <= Date.now)
                )
                .fetchCount(db)
        }
    }

    func debugPodcastCount() throws -> Int {
        try db.read { db in try Podcast.fetchCount(db) }
    }
    #endif

    /// Auto-unhide all episodes whose 24-hour hide period has passed (hiddenUntil <= now).
    /// Read-first: avoids opening an empty write transaction (which would re-fire
    /// every ValueObservation tracking the episode table — see plan §Change 1).
    func unhideExpiredEpisodes() throws {
        let toUnhide = try db.read { db in
            try Episode
                .filter(Episode.Columns.status == EpisodeStatus.hidden.rawValue
                    && Episode.Columns.hiddenUntil <= Date.now)
                .fetchAll(db)
        }
        guard !toUnhide.isEmpty else { return }

        try db.write { db in
            for var episode in toUnhide {
                episode.status = .inbox
                episode.hiddenUntil = nil
                episode.lastModified = .now
                try episode.update(db)
            }
        }
        for episode in toUnhide { syncCoordinator?.markDirty(id: episode.id) }
    }
}

extension DataStore {
    /// Single inbox-then-queue scan for the podcast that owns the given
    /// episode. Used by MiniPlayerView and AudioEngine's Now Playing
    /// publisher; keeping one helper prevents the two sites from drifting.
    func currentPlayingPodcast(episodeID: UUID) -> Podcast? {
        if let match = inbox.first(where: { $0.episode.id == episodeID }) {
            return match.podcast
        }
        if let match = queue.first(where: { $0.episode.id == episodeID }) {
            return match.podcast
        }
        return nil
    }
}

/// A queue item joined with its episode data.
struct QueueItemWithEpisode: Codable, Sendable, FetchableRecord {
    var queueItem: QueueItem
    var episode: Episode
}

/// An episode joined with its parent podcast.
struct EpisodeWithPodcast: Codable, Sendable, FetchableRecord, Identifiable {
    var episode: Episode
    var podcast: Podcast
    var id: UUID { episode.id }
}

/// A queue item joined with its episode and parent podcast.
struct QueueItemWithEpisodeAndPodcast: Codable, Sendable, FetchableRecord, Identifiable {
    var queueItem: QueueItem
    var episode: Episode
    var podcast: Podcast
    var id: UUID { queueItem.id }
}
