# Requirements Brief -- Simpod

## Strategic Summary
- **Vision**: An offline-first podcast player built for reliable listening with minimal data usage
- **Problem**: Overcast has unfixed bugs making it unusable; existing apps are bloated or unreliable. Want AI playlist customization eventually, but the foundation must work solidly first
- **User**: Mike — power listener (20+ subscriptions), commuter with spotty connectivity, privacy-conscious. Building primarily for himself
- **Success metric**: Mike uses Simpod daily as his default podcast player
- **Anti-goals**: No ads, no tracking, no telemetry — ever
- **Time horizon**: Long-term product
- **Risk appetite**: Building — ship reliable, full PDSA cycles, quality gates

## Competitive Analysis
- **Existing solutions**: Overcast (buggy but great UX philosophy — minimal taps, minimalist design), Apple Podcasts (bloated)
- **Steal from**: Castro (triage inbox model), Pocket Casts (cross-platform sync approach), Snipd (AI episode highlights and summaries)
- **Reject from**: Castro (instability), Pocket Casts (cluttered UI, subscription model), Snipd (AI-first over playback-first)

## Tactical Plan
- **Core flow**: Open app -> see new episodes inbox -> triage (queue or skip) -> tap play on queued episode (Castro-style inbox-first)
- **Top 3 stories**:
  1. Play episodes reliably (subscribe, download, play offline/online without failures)
  2. Cross-device sync (subscriptions, queue, playback position via iCloud)
  3. AI-curated playlists (generated based on topics, mood, listening history — post-MVP)
- **Core entities**: Podcast (feed URL, title, artwork, tags) -> Episode (audio URL, duration, position, status, tags) -> QueueItem (order, source). Plus user-defined categories/tags. Playlist entity for future AI curation
- **Tech preferences**: Swift / native iOS (SwiftUI)
- **Hard constraints**: Must work offline, iOS 17+ minimum, no paid services at MVP
- **Integration points**: RSS/Atom feeds (primary), Apple Podcast Lookup API (search/artwork), Podcast Index API (search/discovery). AI service (OpenAI/Claude) deferred to post-MVP
- **UI type**: Native iOS, SwiftUI, minimal chrome / utilitarian (Overcast's sparse design philosophy)
- **Auth model**: iCloud/CloudKit for cross-device sync — no user accounts, Apple handles identity
- **Deploy target**: Side-load via Xcode to personal devices (no App Store at MVP)
- **MVP definition**: Full player in 1-2 months: inbox triage + tags + Apple/Podcast Index search + reliable offline playback + iCloud sync. No AI features at MVP

## Probe Target (feeds GENESIS.md Section 1)
The #1 technical risk to probe: **Background audio playback + download reliability on iOS**. If episodes can't reliably download in the background and play while the app is backgrounded/locked, the entire product fails. This involves AVFoundation, BGTaskScheduler, and URLSession background downloads — all notoriously tricky on iOS.

## Council Agenda (feeds GENESIS.md Section 6)
Decisions for Council Session #1:
1. **Data persistence**: SwiftData vs Core Data vs SQLite for offline episode/podcast storage
2. **Audio engine**: AVPlayer vs AVAudioEngine vs custom AVFoundation stack
3. **Sync architecture**: CloudKit direct vs CKSyncEngine vs custom sync logic
4. **RSS parsing**: Build custom parser vs use FeedKit/existing library

## Team Composition (feeds TEAM.md Section 8)
- Visual QA needed? Yes — iOS UI with minimal chrome design
- Research Scientist needed? No (AI features deferred)
- Council seats: 2 project-specific seats:
  1. **iOS Platform Specialist** — AVFoundation, Background Modes, CloudKit expertise
  2. **UX Minimalism Advocate** — ensures every screen passes the "minimal taps" test

## Pillar Mapping (feeds GENESIS.md Section 11)
- Pillar 1: Reliable Playback — Backend: audio engine + RSS + downloads | UI: Now Playing + playback controls | Overall: episode plays reliably offline
- Pillar 2: Cross-device Sync — Backend: CloudKit sync engine | UI: sync status indicators | Overall: queue + position syncs seamlessly
- Pillar 3: AI Playlists (post-MVP) — Backend: AI service integration + recommendation engine | UI: playlist views + curation controls | Overall: AI generates useful playlists

## Portfolio Links
- Related projects: Shares AI/ML work with other active projects (AI playlist features will connect to broader AI ecosystem)
- Shared components: AI service integration layer may be reusable across projects
