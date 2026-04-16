# Module Contracts -- Simpod (DRAFT — pending Council ratification)

## MODULE CONTRACT: FeedEngine

PROVIDES:
- `subscribe(feedURL: URL) async throws -> Podcast`: Parse RSS feed, return podcast metadata + episodes
- `refresh(podcast: Podcast) async throws -> [Episode]`: Fetch new episodes for a subscribed podcast
- `refreshAll() async throws -> [Podcast: [Episode]]`: Refresh all subscriptions
- `importOPML(data: Data) async throws -> (subscribed: Int, skipped: Int, failed: Int)`: Import podcast subscriptions from OPML data

REQUIRES:
- Network access (URLSession)
- RSS parsing library (TBD — Council decision)
- DataStore.save(podcast:) — to persist parsed data

INVARIANTS:
- Never crashes on malformed RSS — returns partial data or descriptive error
- Always normalizes episode dates to UTC
- Idempotent: refreshing twice with same feed data produces identical results

OWNER: Lane 1 (Feed + Audio Engine)
STATUS: DRAFT

---

## MODULE CONTRACT: AudioEngine

PROVIDES:
- `play(episode: Episode) async`: Start/resume playback
- `pause()`: Pause playback
- `seek(to: TimeInterval)`: Seek to position
- `currentPosition: TimeInterval`: Current playback position (observable)
- `playbackState: PlaybackState`: .playing / .paused / .stopped / .loading (observable)
- `setSpeed(rate: Float)`: Playback speed (0.5x - 3.0x)

REQUIRES:
- AVFoundation framework
- Episode.localFileURL or Episode.streamURL
- Background audio entitlement

INVARIANTS:
- Playback never silently fails — always transitions to an error state visible to UI
- Position is persisted every 5 seconds (survives app termination)
- Resumes correctly after phone call, Siri, or other audio interruption

OWNER: Lane 1 (Feed + Audio Engine)
STATUS: DRAFT

---

## MODULE CONTRACT: DownloadManager

PROVIDES:
- `download(episode: Episode) async throws -> URL`: Download episode audio to local storage
- `cancelDownload(episode: Episode)`: Cancel in-progress download
- `downloadProgress(episode: Episode) -> Double`: Progress 0.0-1.0 (observable)
- `deleteDownload(episode: Episode)`: Remove local audio file

REQUIRES:
- URLSession background download capability
- Local file storage (app's documents directory)
- DataStore.update(episode:) — to update download status

INVARIANTS:
- Downloads continue when app is backgrounded
- Partial downloads resume, not restart
- Storage usage is queryable (total downloaded bytes)

OWNER: Lane 1 (Feed + Audio Engine)
STATUS: DRAFT

---

## MODULE CONTRACT: DataStore

PROVIDES:
- `save(podcast:)`, `save(episode:)`, `save(queueItem:)`: Persist entities
- `fetchPodcasts() -> [Podcast]`: All subscribed podcasts
- `fetchEpisodes(for: Podcast) -> [Episode]`: Episodes for a podcast
- `fetchQueue() -> [QueueItem]`: Ordered queue
- `fetchInbox() -> [Episode]`: Unread/untriaged episodes
- `applyTag(_ tag: Tag, to: Episode)`: Tag an episode

REQUIRES:
- Persistence framework (SwiftData or Core Data — Council decision)
- CloudKit integration point for SyncEngine

INVARIANTS:
- All reads are synchronous from local cache — never blocks on network
- Queue order is always consistent (no gaps, no duplicates)
- Deleting a podcast cascades to its episodes and queue items

OWNER: Lane 1 (Feed + Audio Engine) + Lane 3 (Sync)
STATUS: DRAFT

---

## MODULE CONTRACT: SyncEngine

PROVIDES:
- `syncNow() async`: Force immediate sync to iCloud
- `syncState: SyncState`: .idle / .syncing / .error (observable)
- `lastSyncDate: Date?`: When sync last succeeded

REQUIRES:
- CloudKit / CKSyncEngine (iOS 17+)
- DataStore — reads and writes all entities
- Network access

INVARIANTS:
- Never overwrites newer data with older data (last-writer-wins with timestamps)
- Sync failures are retried automatically with exponential backoff
- Works correctly on first launch with existing iCloud data (restore flow)

OWNER: Lane 3 (iCloud Sync)
STATUS: DRAFT

---

## MODULE CONTRACT: InboxManager

PROVIDES:
- `triage(episode: Episode, action: .queue | .skip)`: Move episode from inbox to queue or archive
- `triageAll(podcast: Podcast, action: .queue | .skip)`: Bulk triage
- `inboxCount: Int`: Number of untriaged episodes (observable, for badge)

REQUIRES:
- DataStore.fetchInbox()
- DataStore.save(queueItem:)

INVARIANTS:
- Every new episode starts in inbox — never goes directly to queue without user action
- Triage is a one-tap operation — no confirmation dialogs
- Inbox count badge updates within 1 second of change

OWNER: Lane 2 (UI Shell + Inbox)
STATUS: DRAFT

---

## Module Contract Registry (for CLAUDE.md)

| Module | Provides | Requires | Invariants | Status |
|--------|----------|----------|------------|--------|
| FeedEngine | subscribe, refresh, refreshAll, importOPML | URLSession, RSS lib, DataStore | No crash on malformed RSS; idempotent | DRAFT |
| AudioEngine | play, pause, seek, speed, state | AVFoundation, Episode URLs | Never silent fail; position persisted | DRAFT |
| DownloadManager | download, cancel, progress, delete | URLSession bg, file storage, DataStore | Bg downloads; resumable; queryable size | DRAFT |
| DataStore | CRUD for all entities, tags | Persistence framework, CloudKit hook | Reads never block; queue consistent | DRAFT |
| SyncEngine | syncNow, syncState, lastSync | CloudKit/CKSyncEngine, DataStore | No overwrite newer; auto-retry; restore | DRAFT |
| InboxManager | triage, triageAll, inboxCount | DataStore | All episodes start in inbox; one-tap | DRAFT |
