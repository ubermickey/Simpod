import Foundation

/// Dependency container — creates and holds shared module instances.
@Observable
final class AppContainer {
    let dataStore: DataStore
    let feedEngine: FeedEngine
    let audioEngine: AudioEngine
    let downloadManager: DownloadManager
    let backgroundRefresh: BackgroundRefreshManager
    let syncEngine: SyncEngine
    let diagnostics: DiagnosticsManager

    init() throws {
        self.dataStore = try DataStore.production()
        self.feedEngine = FeedEngine(dataStore: dataStore)
        self.audioEngine = AudioEngine(dataStore: dataStore)
        self.downloadManager = DownloadManager()
        self.backgroundRefresh = BackgroundRefreshManager(feedEngine: feedEngine)
        self.syncEngine = SyncEngine(dataStore: dataStore)
        self.diagnostics = DiagnosticsManager()

        // Wire DataStore → SyncEngine seam so local mutations enqueue uploads.
        dataStore.syncCoordinator = syncEngine

        diagnostics.start()

        // Wire position persistence
        audioEngine.onPositionUpdate = { [weak dataStore] episodeID, position in
            try? dataStore?.updatePlaybackPosition(episodeID, position: position)
        }
    }

    /// Preview/test container with in-memory database.
    static func preview() throws -> AppContainer {
        try AppContainer(dataStore: DataStore.preview())
    }

    private init(dataStore: DataStore) {
        self.dataStore = dataStore
        self.feedEngine = FeedEngine(dataStore: dataStore)
        self.audioEngine = AudioEngine(dataStore: dataStore)
        self.downloadManager = DownloadManager()
        self.backgroundRefresh = BackgroundRefreshManager(feedEngine: feedEngine)
        self.syncEngine = SyncEngine(dataStore: dataStore)
        self.diagnostics = DiagnosticsManager()

        dataStore.syncCoordinator = syncEngine
    }
}
