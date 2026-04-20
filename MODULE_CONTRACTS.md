# Module Contracts -- Simpod

## MODULE CONTRACT: FeedEngine

PROVIDES:
- `subscribe(feedURL: String) async throws -> Podcast`: Fetch + parse RSS feed, store validators, return podcast metadata + episodes
- `refresh(podcast: Podcast) async throws -> [Episode]`: Fetch new episodes with HTTP conditional GET (ETag/If-Modified-Since); returns `[]` on 304
- `refreshAll() async -> [Podcast: [Episode]]`: Refresh all subscriptions with bounded concurrency (max 4), sliding window
- `importOPML(data: Data) async throws -> (subscribed: Int, skipped: Int, failed: Int)`: Import podcast subscriptions from OPML data

REQUIRES:
- Network access (URLSession)
- FeedKit v10 (`Feed(data:)` for parse-only)
- DataStore.savePodcast / DataStore.saveEpisodes / DataStore.fetchEpisodes

INVARIANTS:
- Never crashes on malformed RSS — returns partial data or descriptive error
- Supports HTTP conditional GET (ETag/If-Modified-Since); skips download+parse on 304
- Body-hash (SHA-256) short-circuit: on `200 OK` with byte-identical body, skip parse and skip write
- ETag-rot defense: never overwrites stored `httpETag` / `httpLastModified` with nil when server omits the header
- `lastModified` bumped only when new episodes inserted OR `feedBodyHash` actually changed
- Idempotent: refreshing twice with same feed data produces identical results and zero writes
- os_signpost intervals for http-fetch, xml-parse, and refreshAll batch timing

OWNER: Lane 1 (Feed + Audio Engine)
STATUS: IN PROGRESS (body-hash + ETag-rot defense shipped; adaptive scheduling deferred)

---

## MODULE CONTRACT: AudioEngine

PROVIDES:
- `play(episode:)` / `pause()` / `resume()` / `stop()` / `seek(to:)` / `setSpeed(_:)` / `skipForward(_:)` / `skipBackward(_:)`
- `currentPosition` / `duration` / `playbackRate` / `playbackState` (all observable)
- `updateNowPlayingInfo(fullPublish:)` / `clearNowPlayingInfo()` — MediaPlayer surface; internal so tests can drive publish without an AVAudioEngine output chain

REQUIRES:
- AVFoundation + MediaPlayer frameworks
- Episode.localFileURL or Episode.streamURL
- Background audio entitlement
- Weak DataStore reference (for queue-aware next-track and artwork lookup)

INVARIANTS:
- Playback never silently fails — always transitions to an error state visible to UI
- Position is persisted on pause / resume / seek / stop (survives app termination)
- Resumes correctly after phone call, Siri, or other audio interruption
- Pauses only on `oldDeviceUnavailable` route changes (headphone unplug, AirPods removal) — never on `newDeviceAvailable`
- MPNowPlayingInfoCenter full-publish on episode change; in-place rate/elapsed mutation on transport events; full clear on stop
- Remote commands (play / pause / toggle / skip± / next / changePlaybackPosition) bound; unused defaults explicitly disabled
- Artwork cache bounded to 8 FIFO entries; async load on miss never blocks the publish path

OWNER: Lane 1 (Feed + Audio Engine)
STATUS: IN PROGRESS (MediaPlayer + transport shipped; Smart Speed / Voice Boost DSP deferred)

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
- `moveToTop(episodeID:)`: Reorder queue item to first position
- `moveToBottom(episodeID:)`: Reorder queue item to last position
- `addToQueueAtTop(episodeID:)`: Add episode from inbox to top of queue
- `hideEpisode(_:)`: Hide for 24 hours (fixed duration), remove from queue
- `unhideEpisode(_:)`: Return hidden episode to inbox, clear reminder
- `unhideExpiredEpisodes()`: Auto-unhide episodes past their reminder date

REQUIRES:
- GRDB / SQLite with DatabasePool (Council #1: 2026-04-14)
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
| FeedEngine | subscribe, refresh, refreshAll, importOPML | URLSession, FeedKit v10, DataStore, CryptoKit | Conditional GET; body-hash short-circuit; ETag-rot defense; no-op write skip; idempotent | IN PROGRESS |
| AudioEngine | play/pause/resume/stop/seek/speed/skip±; Now Playing + remote commands | AVFoundation, MediaPlayer, weak DataStore, bg audio entitlement | Never silent fail; position persisted; route-change pause only on oldDeviceUnavailable; MediaPlayer publish/mutate/clear | IN PROGRESS |
| DownloadManager | download, cancel, progress, delete | URLSession bg, file storage, DataStore | Bg downloads; resumable; queryable size | DRAFT |
| DataStore | CRUD, tags, moveToTop/Bottom, hide/unhide, addToQueueAtTop, currentPlayingPodcast, moveEpisodeToTopAndPlay | GRDB DatabasePool, CloudKit hook | Reads never block; queue consistent; refresh writes elide on no-op | IN PROGRESS |
| SyncEngine | syncNow, syncState, lastSync | CKSyncEngine, DataStore | No overwrite newer; auto-retry; restore | DRAFT |
| InboxManager | triage, triageAll, inboxCount | DataStore | All episodes start in inbox; one-tap | DRAFT |
