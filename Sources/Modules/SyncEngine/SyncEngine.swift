import CloudKit
import Foundation
import Observation

// MARK: - Sync State

enum SyncState: Sendable {
    case idle
    case syncing
    case error(String)
}

// MARK: - SyncEngine

/// Manages iCloud sync via CKSyncEngine (iOS 17+).
/// Invariant: No overwrite of newer local data; auto-retries on transient failures.
/// Degrades gracefully when CloudKit is unavailable (no account, simulator, no entitlement).
@Observable
final class SyncEngine: @unchecked Sendable {

    // MARK: - Observable State

    var syncState: SyncState = .idle
    var lastSyncDate: Date?

    // MARK: - Private

    private let dataStore: DataStore
    private var engine: CKSyncEngine?

    private static let containerID = "iCloud.com.simpod.app"
    private static let zoneName = "SimpodZone"
    private static let stateKey = "com.simpod.syncengine.state"

    // MARK: - CKRecord Type Names

    private enum RecordType {
        static let podcast = "Podcast"
        static let episode = "Episode"
        static let queueItem = "QueueItem"
    }

    // MARK: - Zone ID

    private static var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    // MARK: - Init

    init(dataStore: DataStore) {
        self.dataStore = dataStore
        // Setup CKSyncEngine on a background task so it never blocks app launch.
        // CKSyncEngine(configuration) can hang on devices without CloudKit entitlements.
        Task.detached { [self] in
            self.setupEngine()
        }
    }

    // MARK: - Public API

    /// Inform the sync engine that a local entity needs uploading to CloudKit.
    /// Enqueues a save-record pending change; CKSyncEngine will call nextRecordZoneChangeBatch.
    func markDirty(id: UUID) {
        guard let engine else {
            print("[SyncEngine] markDirty called but engine is unavailable")
            return
        }
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: Self.zoneID)
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
    }

    /// Inform the sync engine that a local entity was deleted and should be removed from CloudKit.
    func markDeleted(id: UUID) {
        guard let engine else {
            print("[SyncEngine] markDeleted called but engine is unavailable")
            return
        }
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: Self.zoneID)
        engine.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID)])
    }

    /// Trigger an immediate fetch from CloudKit (e.g., pull-to-refresh).
    func fetchNow() async {
        guard let engine else {
            print("[SyncEngine] fetchNow called but engine is unavailable")
            return
        }
        do {
            try await engine.fetchChanges()
        } catch {
            print("[SyncEngine] fetchNow error: \(error)")
        }
    }

    /// Trigger an immediate send of pending local changes (e.g., "sync now" button).
    func sendNow() async {
        guard let engine else {
            print("[SyncEngine] sendNow called but engine is unavailable")
            return
        }
        do {
            try await engine.sendChanges()
        } catch {
            print("[SyncEngine] sendNow error: \(error)")
        }
    }

    // MARK: - Private Setup

    private func setupEngine() {
        // CKSyncEngine crashes at runtime if the CloudKit entitlement is missing.
        // Check for iCloud availability before attempting to create the engine.
        guard FileManager.default.ubiquityIdentityToken != nil else {
            print("[SyncEngine] iCloud unavailable — skipping CKSyncEngine setup")
            return
        }

        // Restore serialized state from UserDefaults, if any.
        let serializedState: CKSyncEngine.State.Serialization? = {
            guard
                let data = UserDefaults.standard.data(forKey: Self.stateKey),
                let decoded = try? JSONDecoder().decode(
                    CKSyncEngine.State.Serialization.self,
                    from: data
                )
            else { return nil }
            return decoded
        }()

        let configuration = CKSyncEngine.Configuration(
            database: CKContainer(identifier: Self.containerID).privateCloudDatabase,
            stateSerialization: serializedState,
            delegate: self
        )

        let syncEngine = CKSyncEngine(configuration)
        self.engine = syncEngine
        print("[SyncEngine] CKSyncEngine started successfully")
    }

    // MARK: - CKRecord Mapping: Models → CKRecord

    private func ckRecord(for podcast: Podcast) -> CKRecord {
        let recordID = CKRecord.ID(recordName: podcast.id.uuidString, zoneID: Self.zoneID)
        let record = CKRecord(recordType: RecordType.podcast, recordID: recordID)
        record["feedURL"] = podcast.feedURL as CKRecordValue
        record["title"] = podcast.title as CKRecordValue
        record["author"] = podcast.author as CKRecordValue
        record["artworkURL"] = podcast.artworkURL as CKRecordValue?
        record["podcastDescription"] = podcast.podcastDescription as CKRecordValue
        if let lastRefreshed = podcast.lastRefreshed {
            record["lastRefreshed"] = lastRefreshed as CKRecordValue
        }
        record["lastModified"] = podcast.lastModified as CKRecordValue
        return record
    }

    private func ckRecord(for episode: Episode) -> CKRecord {
        let recordID = CKRecord.ID(recordName: episode.id.uuidString, zoneID: Self.zoneID)
        let record = CKRecord(recordType: RecordType.episode, recordID: recordID)
        record["podcastID"] = episode.podcastID.uuidString as CKRecordValue
        record["guid"] = episode.guid as CKRecordValue
        record["title"] = episode.title as CKRecordValue
        record["audioURL"] = episode.audioURL as CKRecordValue
        record["duration"] = episode.duration as CKRecordValue
        record["playbackPosition"] = episode.playbackPosition as CKRecordValue
        record["publishedDate"] = episode.publishedDate as CKRecordValue
        record["episodeDescription"] = episode.episodeDescription as CKRecordValue
        record["status"] = episode.status.rawValue as CKRecordValue
        record["lastModified"] = episode.lastModified as CKRecordValue
        // localFilePath and downloadProgress are device-local — not synced
        return record
    }

    private func ckRecord(for item: QueueItem) -> CKRecord {
        let recordID = CKRecord.ID(recordName: item.id.uuidString, zoneID: Self.zoneID)
        let record = CKRecord(recordType: RecordType.queueItem, recordID: recordID)
        record["episodeID"] = item.episodeID.uuidString as CKRecordValue
        record["order"] = item.order as CKRecordValue
        record["addedDate"] = item.addedDate as CKRecordValue
        record["lastModified"] = item.lastModified as CKRecordValue
        return record
    }

    /// Resolve a pending save change to a CKRecord by looking up the entity in DataStore.
    /// Returns nil if the entity no longer exists (it was deleted locally), causing the
    /// batch initializer to skip that change.
    private func resolveRecord(for recordID: CKRecord.ID) -> CKRecord? {
        guard let uuid = UUID(uuidString: recordID.recordName) else {
            print("[SyncEngine] Cannot parse UUID from recordName: \(recordID.recordName)")
            return nil
        }

        if let podcast = try? dataStore.fetchPodcast(byID: uuid) {
            return ckRecord(for: podcast)
        }
        if let episode = try? dataStore.fetchEpisode(byID: uuid) {
            return ckRecord(for: episode)
        }
        if let item = try? dataStore.fetchQueueItem(byID: uuid) {
            return ckRecord(for: item)
        }

        print("[SyncEngine] Pending record \(recordID.recordName) not found in DataStore — skipping")
        return nil
    }

    // MARK: - CKRecord Mapping: CKRecord → Models

    private func podcast(from record: CKRecord) -> Podcast? {
        guard
            let id = UUID(uuidString: record.recordID.recordName),
            let feedURL = record["feedURL"] as? String,
            let title = record["title"] as? String,
            let lastModified = record["lastModified"] as? Date
        else { return nil }

        return Podcast(
            id: id,
            feedURL: feedURL,
            title: title,
            author: record["author"] as? String ?? "",
            artworkURL: record["artworkURL"] as? String,
            podcastDescription: record["podcastDescription"] as? String ?? "",
            lastRefreshed: record["lastRefreshed"] as? Date,
            lastModified: lastModified
        )
    }

    private func episode(from record: CKRecord) -> Episode? {
        guard
            let id = UUID(uuidString: record.recordID.recordName),
            let podcastIDString = record["podcastID"] as? String,
            let podcastID = UUID(uuidString: podcastIDString),
            let title = record["title"] as? String,
            let audioURL = record["audioURL"] as? String,
            let publishedDate = record["publishedDate"] as? Date,
            let lastModified = record["lastModified"] as? Date
        else { return nil }

        let statusRaw = record["status"] as? String ?? EpisodeStatus.inbox.rawValue
        let status = EpisodeStatus(rawValue: statusRaw) ?? .inbox

        return Episode(
            id: id,
            podcastID: podcastID,
            guid: record["guid"] as? String ?? "",
            title: title,
            audioURL: audioURL,
            localFilePath: nil, // device-local, not synced
            duration: record["duration"] as? TimeInterval ?? 0,
            playbackPosition: record["playbackPosition"] as? TimeInterval ?? 0,
            publishedDate: publishedDate,
            episodeDescription: record["episodeDescription"] as? String ?? "",
            status: status,
            downloadProgress: 0, // device-local, not synced
            lastModified: lastModified
        )
    }

    private func queueItem(from record: CKRecord) -> QueueItem? {
        guard
            let id = UUID(uuidString: record.recordID.recordName),
            let episodeIDString = record["episodeID"] as? String,
            let episodeID = UUID(uuidString: episodeIDString),
            let order = record["order"] as? Int,
            let addedDate = record["addedDate"] as? Date,
            let lastModified = record["lastModified"] as? Date
        else { return nil }

        return QueueItem(
            id: id,
            episodeID: episodeID,
            order: order,
            addedDate: addedDate,
            lastModified: lastModified
        )
    }

    // MARK: - Apply Fetched Record (latest-write-wins)

    private func applyFetchedRecord(_ record: CKRecord) {
        let recordType = record.recordType

        do {
            switch recordType {
            case RecordType.podcast:
                guard let incoming = podcast(from: record) else {
                    print("[SyncEngine] Failed to parse Podcast from CKRecord \(record.recordID.recordName)")
                    return
                }
                if let existing = try dataStore.fetchPodcast(byID: incoming.id) {
                    if incoming.lastModified > existing.lastModified {
                        try dataStore.saveFromSync(podcast: incoming)
                    }
                } else {
                    try dataStore.saveFromSync(podcast: incoming)
                }

            case RecordType.episode:
                guard let incoming = episode(from: record) else {
                    print("[SyncEngine] Failed to parse Episode from CKRecord \(record.recordID.recordName)")
                    return
                }
                if let existing = try dataStore.fetchEpisode(byID: incoming.id) {
                    if incoming.lastModified > existing.lastModified {
                        // Preserve device-local fields from the existing record
                        var merged = incoming
                        merged.localFilePath = existing.localFilePath
                        merged.downloadProgress = existing.downloadProgress
                        try dataStore.saveFromSync(episode: merged)
                    }
                } else {
                    try dataStore.saveFromSync(episode: incoming)
                }

            case RecordType.queueItem:
                guard let incoming = queueItem(from: record) else {
                    print("[SyncEngine] Failed to parse QueueItem from CKRecord \(record.recordID.recordName)")
                    return
                }
                if let existing = try dataStore.fetchQueueItem(byID: incoming.id) {
                    if incoming.lastModified > existing.lastModified {
                        try dataStore.saveFromSync(queueItem: incoming)
                    }
                } else {
                    try dataStore.saveFromSync(queueItem: incoming)
                }

            default:
                print("[SyncEngine] Unknown record type: \(recordType)")
            }
        } catch {
            print("[SyncEngine] Error applying fetched record \(record.recordID.recordName): \(error)")
        }
    }

    // MARK: - Apply Deletion

    private func applyDeletion(recordID: CKRecord.ID, recordType: String) {
        guard let uuid = UUID(uuidString: recordID.recordName) else {
            print("[SyncEngine] Cannot parse UUID from recordName: \(recordID.recordName)")
            return
        }

        do {
            switch recordType {
            case RecordType.podcast:
                try dataStore.deleteByID(Podcast.self, id: uuid)
            case RecordType.episode:
                try dataStore.deleteByID(Episode.self, id: uuid)
            case RecordType.queueItem:
                try dataStore.deleteByID(QueueItem.self, id: uuid)
            default:
                print("[SyncEngine] Unknown record type for deletion: \(recordType)")
            }
        } catch {
            print("[SyncEngine] Error deleting record \(recordID.recordName): \(error)")
        }
    }

    // MARK: - Persist Sync State

    private func persistState(_ serialization: CKSyncEngine.State.Serialization) {
        do {
            let data = try JSONEncoder().encode(serialization)
            UserDefaults.standard.set(data, forKey: Self.stateKey)
        } catch {
            print("[SyncEngine] Failed to persist sync state: \(error)")
        }
    }
}

// MARK: - CKSyncEngineDelegate

extension SyncEngine: CKSyncEngineDelegate {

    nonisolated func handleEvent(
        _ event: CKSyncEngine.Event,
        syncEngine: CKSyncEngine
    ) async {
        switch event {

        case .stateUpdate(let stateEvent):
            // CRITICAL: Must persist serialized state on every update so it survives app launch.
            persistState(stateEvent.stateSerialization)

        case .accountChange(let accountEvent):
            handleAccountChange(accountEvent)

        case .fetchedDatabaseChanges(let fetchEvent):
            // Zone-level changes — log zone deletions (SimpodZone deleted on another device).
            for deletion in fetchEvent.deletions {
                print("[SyncEngine] Zone deleted remotely: \(deletion.zoneID.zoneName)")
            }

        case .fetchedRecordZoneChanges(let fetchEvent):
            // Individual record-level changes — apply to DataStore with latest-write-wins.
            for modification in fetchEvent.modifications {
                applyFetchedRecord(modification.record)
            }
            for deletion in fetchEvent.deletions {
                applyDeletion(recordID: deletion.recordID, recordType: deletion.recordType)
            }
            DispatchQueue.main.async {
                self.lastSyncDate = Date()
                self.syncState = .idle
            }

        case .sentRecordZoneChanges(let sentEvent):
            // Log failed saves — CKSyncEngine retries transient errors automatically.
            for failure in sentEvent.failedRecordSaves {
                print("[SyncEngine] Failed to save record \(failure.record.recordID.recordName): \(failure.error)")
            }
            DispatchQueue.main.async {
                self.lastSyncDate = Date()
                self.syncState = .idle
            }

        case .willFetchChanges:
            DispatchQueue.main.async { self.syncState = .syncing }

        case .willSendChanges:
            DispatchQueue.main.async { self.syncState = .syncing }

        case .willFetchRecordZoneChanges:
            break // willFetchChanges is sufficient for our status updates

        case .didFetchRecordZoneChanges:
            break

        case .didFetchChanges:
            break // final status set in fetchedRecordZoneChanges

        case .didSendChanges:
            break // final status set in sentRecordZoneChanges

        case .sentDatabaseChanges:
            break // we don't manipulate zones explicitly

        @unknown default:
            print("[SyncEngine] Unhandled CKSyncEngine event: \(event)")
        }
    }

    nonisolated func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        // Filter engine's pending changes to those within the requested scope.
        let pendingChanges = syncEngine.state.pendingRecordZoneChanges.filter { change in
            context.options.scope.contains(change)
        }

        guard !pendingChanges.isEmpty else { return nil }

        // The batch initializer respects batch-size limits and calls our provider
        // only for save changes; delete changes are included automatically.
        return await CKSyncEngine.RecordZoneChangeBatch(
            pendingChanges: pendingChanges
        ) { [self] recordID in
            resolveRecord(for: recordID)
        }
    }

    // MARK: - Account Change Handling

    private func handleAccountChange(_ event: CKSyncEngine.Event.AccountChange) {
        switch event.changeType {
        case .signIn:
            print("[SyncEngine] iCloud account signed in — sync enabled")
            DispatchQueue.main.async { self.syncState = .idle }

        case .signOut:
            print("[SyncEngine] iCloud account signed out")
            UserDefaults.standard.removeObject(forKey: Self.stateKey)
            DispatchQueue.main.async { self.syncState = .error("iCloud account signed out") }

        case .switchAccounts:
            print("[SyncEngine] iCloud account switched — resetting sync state")
            UserDefaults.standard.removeObject(forKey: Self.stateKey)
            DispatchQueue.main.async { self.syncState = .idle }

        @unknown default:
            print("[SyncEngine] Unknown account change type")
        }
    }
}
