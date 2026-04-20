# Swim Lane Plan -- Simpod

## Dependency DAG

```
[Lane 1: Feed + Audio Engine] ──→ [Lane 4: Integration + Polish]
                                ↗
[Lane 2: UI Shell + Inbox]   ──→ [Lane 4: Integration + Polish]
                                ↗
[Lane 3: iCloud Sync]        ──→ [Lane 4: Integration + Polish]

Lane 1 and Lane 2: INDEPENDENT — parallel
Lane 1 and Lane 3: INDEPENDENT — parallel
Lane 2 and Lane 3: INDEPENDENT — parallel
Lane 4: DEPENDS ON Lanes 1, 2, 3 (sync point)

[Lane 5: AI Playlists] — POST-MVP, depends on Lane 1 (needs episode data)
```

## Lanes

### Lane 1: Feed + Audio Engine (Backend Core) — IN PROGRESS
- **Features**: RSS feed parsing, episode metadata extraction, audio download manager, AVPlayer playback engine, background download scheduling, smart speed, voice boost
- **Depends on**: Nothing — foundational lane
- **Deliverable**: Headless podcast engine that can subscribe to feeds, download episodes, and play audio — no UI needed
- **Completed**:
  - FeedEngine: subscribe, refresh, refreshAll with bounded concurrency
  - HTTP conditional GET (ETag/If-Modified-Since) — skips re-download on 304
  - Body-hash (SHA-256) short-circuit for Cloudflare-stripped ETag hosts; ETag-rot defense; no-op write skip (v5-feed-body-hash migration)
  - Refresh pipeline: DatabasePool, concurrency 2, 15s per-feed timeout, read-first unhide, debounced inbox/queue observations
  - os_signpost instrumentation (http-fetch, xml-parse, refreshAll)
  - MetricKit diagnostics subscriber
  - AudioEngine Now Playing (MPNowPlayingInfoCenter), remote commands (MPRemoteCommandCenter), route-change pause on oldDeviceUnavailable
- **Remaining**:
  - Background URLSession downloads
  - Smart Speed / Voice Boost DSP
- **Acceptance criteria**: 
  - Parse 10 real podcast feeds without failure
  - Download episode audio in background
  - Play audio while app is backgrounded
  - Resume playback after phone call interruption
- **Estimated effort**: L (largest lane — core of the product)
- **Pillar**: Pillar 1 (Backend)

### Lane 2: UI Shell + Inbox
- **Features**: App shell (tab bar / navigation), Inbox screen (Castro-style triage), Queue screen, Now Playing screen, mini player, podcast search (Apple + Podcast Index), subscription management, tag/category system
- **Depends on**: Nothing — can develop against mock data / protocol stubs
- **Deliverable**: Full SwiftUI app with all screens functional against mock data
- **Acceptance criteria**:
  - New episodes appear in inbox
  - Triage: queue or skip with one tap
  - Queue reorder via drag
  - Now Playing shows episode info + controls
  - Search finds podcasts via Apple/Podcast Index API
  - Tags can be created and assigned
- **Estimated effort**: L (many screens, interaction design)
- **Pillar**: Pillar 1 (UI), Pillar 2 (UI)

### Lane 3: iCloud Sync
- **Features**: CloudKit schema, CKSyncEngine integration, sync for subscriptions + queue + playback position + tags, conflict resolution, first-launch restore
- **Depends on**: Nothing — can develop against local data store, sync layer is additive
- **Deliverable**: Sync engine that mirrors local data to CloudKit and resolves conflicts
- **Acceptance criteria**:
  - Data syncs within 30s
  - No data loss on conflict
  - Fresh install restores full library
- **Estimated effort**: M
- **Pillar**: Pillar 2 (Backend)

### Lane 4: Integration + Polish (Sync Point)
- **Features**: Wire UI to real audio engine, connect sync to data layer, end-to-end testing, performance optimization, edge case handling
- **Depends on**: Lanes 1, 2, 3 (all must reach deliverable state)
- **Deliverable**: Working Simpod app — all features integrated and tested
- **Acceptance criteria**:
  - Core flow works end-to-end (subscribe → inbox → triage → play offline)
  - Sync works across devices
  - No playback failures in 100-episode stress test
- **Estimated effort**: M
- **Pillar**: All pillars (Overall)

### Lane 5: AI Playlists (POST-MVP)
- **Features**: AI service integration, episode analysis, playlist generation, curation UI
- **Depends on**: Lane 1 (needs episode data model and metadata)
- **Deliverable**: AI-generated playlists from subscribed episodes
- **Acceptance criteria**: User describes topic → gets relevant playlist
- **Estimated effort**: L
- **Pillar**: Pillar 3

## Sync Points

| Sync Point | Lanes Merging | Trigger | Integration Test |
|------------|--------------|---------|-----------------|
| Core Integration | Lane 1 + Lane 2 | Audio engine + UI shell both pass acceptance | Play episode through full UI flow |
| Full Integration | Lanes 1 + 2 + 3 | Sync engine passes acceptance | Sync queue change across two devices |
| AI Integration (post-MVP) | Lane 1 + Lane 5 | AI service returns playlists | Generate and play AI playlist |

## Execution Order
1. Start Lanes 1, 2, and 3 in parallel
2. Core Integration sync point when Lanes 1 + 2 complete
3. Full Integration sync point when Lane 3 also completes
4. Lane 4 (Polish) after full integration
5. Lane 5 (AI) post-MVP, after Lane 1 is stable
