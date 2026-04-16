# Council Session #1: Architecture
**Date:** 2026-04-14
**Project:** Simpod
**Attendees:** Aria (THINK), Mike (stakeholder)

## Context
- **Name**: Simpod — offline-first podcast player
- **User**: Mike — power listener, commuter, privacy-conscious
- **Core flow**: Open → inbox (Castro-style triage) → queue → play
- **Constraints**: iOS 17+, offline mandatory, no paid services, no ads/tracking
- **Probe result**: PASSED — parsed 687 episodes from ATP feed in 1.7s

## Decisions

### ADR-001: Data Persistence → GRDB (SQLite)
- **Options**: SwiftData (40), Core Data (58), GRDB (60)
- **Decision**: GRDB
- **Rationale**: Best performance, full SQL escape hatch, clean CKSyncEngine pairing, no framework lock-in
- **Dissent**: None. SwiftData's CloudKit sync bugs made it unviable. Core Data viable but heavier.
- **Fallback**: Core Data if GRDB community support declines

### ADR-002: Audio Engine → AVAudioEngine (from start)
- **Options**: AVPlayer (MVP) → AVAudioEngine (later), AVAudioEngine from start, AVPlayer only
- **Decision**: AVAudioEngine from start
- **Rationale**: Smart Speed and Voice Boost are core features, not nice-to-haves. Avoids migration tax.
- **Dissent**: Research recommended hybrid for lower initial complexity. User overrode: prefers upfront investment.
- **Fallback**: Fall back to AVPlayer for streaming-only playback if AVAudioEngine streaming proves too complex

### ADR-003: RSS Parser → FeedKit v10
- **Options**: FeedKit v10 (58), Custom XMLParser (58), SWXMLHash (55)
- **Decision**: FeedKit v10
- **Rationale**: Podcast-native, async/await, handles iTunes namespace. Add pre-parse sanitizer for malformed feeds.
- **Dissent**: None
- **Fallback**: Custom XMLParser if FeedKit can't handle critical edge cases

### ADR-004: Sync Strategy → CKSyncEngine in MVP
- **Options**: CKSyncEngine post-MVP, CKSyncEngine in MVP, No sync
- **Decision**: CKSyncEngine in MVP
- **Rationale**: Cross-device sync is a core feature (user story #2). Building sync-aware data model from start is better architecture.
- **Dissent**: Research recommended post-MVP to reduce scope. User overrode: sync is not optional.
- **Fallback**: Defer sync if it blocks MVP timeline

## Architecture Diagram

```
┌─────────────────────────────────────────────┐
│                  SwiftUI Views              │
│  Inbox │ Queue │ NowPlaying │ Search │ Settings │
├─────────────────────────────────────────────┤
│              InboxManager                   │
├──────────┬──────────┬───────────────────────┤
│FeedEngine│AudioEngine│   DownloadManager    │
│(FeedKit) │(AVAudio  │   (URLSession bg)    │
│          │ Engine)  │                       │
├──────────┴──────────┴───────────────────────┤
│              DataStore (GRDB/SQLite)        │
├─────────────────────────────────────────────┤
│          SyncEngine (CKSyncEngine)          │
└─────────────────────────────────────────────┘
```

## Swim Lane DAG (ratified)
- Lane 1 (Feed + Audio) ∥ Lane 2 (UI) ∥ Lane 3 (Sync) → Lane 4 (Integration)
- Lane 5 (AI Playlists) — post-MVP, depends on Lane 1

## Action Items
1. Add GRDB + FeedKit as SPM dependencies ✓
2. Update CLAUDE.md with all decisions ✓
3. Begin Lane 1, 2, 3 in parallel
