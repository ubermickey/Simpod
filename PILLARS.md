# Pillar Tracker -- Simpod

## Pillar 1: User can play podcast episodes reliably (online + offline)
| Dimension | Status | Key Deliverables | Acceptance Criteria |
|-----------|--------|-------------------|-------------------|
| Backend | IN PROGRESS | RSS feed parser (FeedKit + conditional GET), episode downloader, audio engine, background download scheduler, os_signpost diagnostics | Episodes download without failure; audio plays while app is backgrounded/locked; playback resumes after interruption |
| UI | NOT STARTED | Now Playing screen, playback controls (play/pause/skip/seek), download progress indicator, mini player | One tap to play; playback controls respond < 100ms; mini player persists across screens |
| Overall | NOT STARTED | Subscribe to feed → episodes appear → download → play offline | User subscribes, downloads episode on WiFi, plays on subway with no signal — zero failures |

## Pillar 2: Cross-device sync via iCloud
| Dimension | Status | Key Deliverables | Acceptance Criteria |
|-----------|--------|-------------------|-------------------|
| Backend | NOT STARTED | CloudKit/CKSyncEngine integration, sync conflict resolution, subscription + queue + position sync | Data syncs within 30s of change; no data loss on conflict; works on fresh device install |
| UI | NOT STARTED | Sync status indicator, first-launch restore flow | User sees sync state; new device restores full library automatically |
| Overall | NOT STARTED | Change queue on iPhone → see change on iPad | Queue reorder on device A appears on device B within 30s |

## Pillar 3: AI-curated playlists (post-MVP)
| Dimension | Status | Key Deliverables | Acceptance Criteria |
|-----------|--------|-------------------|-------------------|
| Backend | NOT STARTED | AI service integration, episode analysis/embedding, recommendation engine, playlist generation | AI generates playlist of 5-10 episodes matching a topic/mood query |
| UI | NOT STARTED | Playlist views, AI curation controls, topic/mood selector | User describes what they want to hear → gets a playlist in < 5s |
| Overall | NOT STARTED | User asks for "tech news deep dives" → gets relevant playlist from subscriptions | Playlist contains relevant episodes; user rates 4/5 recommendations as good |

---

## Pillar-Lane Mapping (draft — pending Council ratification)
- Pillar 1 → Lane 1 (Audio Engine + RSS), Lane 2 (UI / Now Playing)
- Pillar 2 → Lane 3 (iCloud Sync)
- Pillar 3 → Lane 4 (AI — post-MVP, not started until Pillars 1+2 are solid)
