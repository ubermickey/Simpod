# Simpod Research Report

> **Phase:** 15-Minute Research (GENESIS.md kickoff ritual)
> **Date:** 2026-04-14
> **Target:** Native iOS (Swift/SwiftUI, iOS 17+) offline-first podcast player

---

## 1. RSS Parsing Libraries (Swift)

### FeedKit (nmdias/FeedKit)
- **Stars:** ~1,300 | **License:** MIT | **Last release:** v10 (2025) with new parsing engine, async/await support
- Handles RSS 2.0, Atom, and JSON Feed formats; supports iTunes podcast namespace tags (`itunes:author`, `itunes:category`, `itunes:duration`, etc.)
- v10 rewrote the parsing engine with improved type safety and modern Swift concurrency
- **Malformed feed handling:** Moderate -- relies on Foundation's XMLParser under the hood, which is strict; badly malformed XML will throw rather than recover gracefully
- Known issue: syndication namespace child elements were historically nil if parent namespace not initialized (fixed in later versions)

### SWXMLHash (drmohundro/SWXMLHash)
- **Stars:** ~1,500 | **License:** MIT | **Last release:** July 2025 (memory leak fix)
- Generic XML parser, not podcast-specific -- you must manually map all RSS/iTunes/Podcast namespace elements
- Lazy parsing mode is memory-efficient for large feeds
- Better tolerance of slightly malformed XML than Foundation XMLParser, but still not a forgiving HTML-style parser
- Significantly more boilerplate required to get podcast-equivalent functionality vs FeedKit

### Custom (Foundation XMLParser / swift-xml)
- Zero dependencies; full control over error recovery and namespace handling
- Can implement lenient parsing (recover from encoding errors, missing closing tags)
- High development cost: 2-4 weeks to match FeedKit's podcast namespace coverage
- Viable only if FeedKit proves inadequate for edge-case feeds

### Recommendation
**FeedKit v10** for MVP. It covers 95% of podcast feeds out of the box. If malformed-feed issues surface, wrap it with a pre-processing sanitizer (fix encoding, strip invalid XML chars) before parsing. SWXMLHash is overkill for structured podcast RSS.

---

## 2. Podcast APIs

### Apple iTunes Search / Podcast Lookup API
- **Free, no auth required** -- just HTTP GET to `https://itunes.apple.com/search?term=...&media=podcast`
- Returns podcast metadata, artwork URLs, feed URLs, genre IDs
- **Rate limits:** Officially ~20 requests/minute (historically enforced at ~10-20 req/min; was briefly higher). No published SLA
- **Limitations:** Episode-level search is weak; data freshness lags 24-48 hours; no transcript/chapter support
- Best for: initial podcast discovery and artwork retrieval

### Podcast Index API (podcastindex.org)
- **Free, open-source index** -- requires API key + secret (free registration)
- 4.5M+ podcasts indexed; supports Podcasting 2.0 namespace (chapters, transcripts, value tags, soundbites)
- Endpoints: search, recent, trending, episodes by feed ID, categories, value (Lightning payments)
- **Rate limits:** Not explicitly documented; community reports suggest generous limits (~300+ req/min for normal use)
- **Auth:** HMAC-SHA1 header with epoch timestamp + API key + secret
- Best for: comprehensive search, Podcasting 2.0 features, feed URL resolution

### Other Notable APIs
- **Taddy API:** GraphQL-based, 4M+ podcasts, free tier (1000 req/month), paid tiers available
- **Podchaser API:** Rich metadata + credits/reviews, rate limit 100 req/min, requires auth

### Recommendation
Use **Podcast Index** as primary search/discovery backend (free, open, Podcasting 2.0 native). Fall back to **Apple iTunes Lookup** for artwork and Apple-specific metadata. No need for paid APIs at MVP.

---

## 3. Audio Playback on iOS

### AVPlayer vs AVAudioEngine

| Aspect | AVPlayer | AVAudioEngine |
|--------|----------|---------------|
| Streaming | Built-in HLS/progressive | Manual buffer management required |
| Background audio | Native support via audio session | Native support via audio session |
| Playback speed | `rate` property (0.5x-2.0x) | `AVAudioUnitTimePitch` (unlimited range) |
| Silence trimming | Not possible | Yes, via tap + vDSP RMS analysis |
| Voice boost | Not possible | Yes, via `AVAudioUnitEQ` / compressor nodes |
| AirPlay/CarPlay | Built-in | Built-in |
| Now Playing info | MPNowPlayingInfoCenter | MPNowPlayingInfoCenter |
| Complexity | Low | High |

### Background Audio + Downloads
- **Audio session:** Set category `.playback` with `AVAudioSession` -- mandatory for background play
- **Background downloads:** Use `URLSession` with `background(withIdentifier:)` configuration -- survives app suspension/termination
- **BGTaskScheduler:** Use `BGAppRefreshTask` for periodic feed checking (limited to ~100 KB data per refresh); use `BGProcessingTask` for heavier work (requires power + Wi-Fi by default)
- **Gotcha:** Only one background URLSession per identifier; creating multiple sessions triggers system rate limiting

### Smart Speed / Voice Boost Implementation
- **Smart Speed (silence trimming):** Install a tap on AVAudioEngine's player node, compute RMS via `vDSP_rmsqv` on each buffer, skip buffers below threshold. Alternatively, dynamically adjust playback rate during silent sections
- **Voice Boost:** Chain `AVAudioUnitEQ` (high-pass filter + presence boost) and `AVAudioUnitEffect` (dynamics compressor) in the AVAudioEngine graph. Compresses dynamic range so quiet speech is louder
- Both features require AVAudioEngine -- cannot be done with AVPlayer alone

### Recommendation
**Hybrid approach:** Start with **AVPlayer** for MVP (simple streaming + local playback, background audio, AirPlay). Migrate to **AVAudioEngine** in a later pass when Smart Speed / Voice Boost features are prioritized. The migration path is clean: swap the playback backend behind a protocol.

---

## 4. iCloud / CloudKit Sync

### CKSyncEngine (iOS 17+)
- Apple's recommended sync engine introduced at WWDC 2023; replaces the old NSPersistentCloudKitContainer approach for custom stores
- Handles conflict resolution, retry logic, rate limiting, batch scheduling automatically
- You map your model objects to/from `CKRecord` manually -- full control over what syncs
- Apple provides a complete sample project (`sample-cloudkit-sync-engine`)
- **Pros:** Works with any persistence layer (SwiftData, GRDB, raw SQLite); no Core Data dependency
- **Cons:** More boilerplate than automatic SwiftData+CloudKit; you own the record mapping

### SwiftData + CloudKit (automatic)
- Add CloudKit capability + set `cloudKitContainerIdentifier` on `ModelConfiguration` -- sync "just works"
- **Hard requirements:** All properties must be optional or have defaults; all relationships must be optional
- **Known pitfalls (2025-2026):**
  - Schema must be manually deployed to CloudKit Production via Dashboard before App Store release -- silent failure otherwise
  - macOS builds may silently fail to link CloudKit.framework in release mode
  - Initial sync after fresh install often requires two app launches to surface data
  - Relationships and new fields may not sync until schema is re-deployed
  - Several developers report converting to Core Data + CloudKit after hitting SwiftData sync limitations
- No support for shared databases (CloudKit Sharing) via SwiftData alone

### Recommendation
Use **CKSyncEngine** with whatever persistence layer we choose. It avoids SwiftData's CloudKit sync pitfalls while giving full control. For podcast data (subscriptions, playback positions, episode states), the record mapping is straightforward. Defer CloudKit sync to a post-MVP pass -- local-first is the priority.

---

## 5. Prior Art (Open Source Swift Podcast Players)

### Notable Projects
- **cuappdev/podcast-ios** -- Cornell AppDev's podcast app; clean MVVM architecture, uses AVPlayer, FeedKit for RSS, URLSession for downloads. Good reference for architecture patterns
- **rafaelclaycon/PodcastApp** -- SwiftUI-based, demonstrates modern declarative UI for podcast browsing. Simpler architecture, good for UI patterns
- **tanhakabir/SwiftAudioPlayer** -- Not a full podcast app but a streaming audio engine built on AVAudioEngine with real-time manipulation (speed, pitch). 500+ stars. Direct reference for Smart Speed implementation
- **Audiobookshelf iOS player** -- 294 stars (Dec 2025), SwiftUI, most actively maintained. Server-dependent (not standalone)

### Architecture Lessons
- All successful projects separate feed parsing, audio playback, and download management into distinct layers
- MVVM or MVVM+Coordinator is the dominant pattern; none use VIPER or TCA for a podcast player
- Episode download management is consistently the most complex module (queue management, disk space, background sessions)
- Most projects underinvest in offline state management -- this is Simpod's opportunity to differentiate

---

## 6. Pitfalls and Gotchas

### RSS Feed Issues
- **Encoding chaos:** Feeds claim UTF-8 but contain Windows-1252 characters; always sanitize input before parsing
- **Massive feeds:** Some podcasts have 1000+ episodes in a single feed; parse incrementally or paginate. Apple truncates display to ~300 episodes
- **Date format variance:** `pubDate` uses at least 5 different RFC-822 variations in the wild; use a lenient date parser
- **GUID instability:** Some hosts change GUIDs when migrating platforms, causing duplicate episodes

### Background Download Limits
- `BGAppRefreshTask` data budget is ~100 KB -- enough for feed XML, not episode audio
- Background URLSession downloads have no explicit size limit but the system may defer large downloads to Wi-Fi + charging
- Creating multiple background URLSession instances triggers rate limiting; use one session with multiple tasks

### Audio Session Gotchas
- Failing to handle `AVAudioSession.interruptionNotification` causes silent playback failures after phone calls
- CarPlay requires `com.apple.developer.carplay-audio` entitlement -- must be requested from Apple
- AirPlay 2 multi-room requires `AVAudioSession.RouteSharingPolicy.longFormAudio`

### App Store Review
- Apps that download large amounts of data must provide user controls for download quality and Wi-Fi-only options
- Background download without user-visible controls has caused rejections

---

## Technology Evaluation Scorecards

### RSS Parser

| Criterion (weight) | FeedKit v10 | SWXMLHash | Custom (XMLParser) |
|--------------------|:-----------:|:---------:|:------------------:|
| Maturity (3x)      | 4           | 4         | 5                  |
| Community (3x)     | 4           | 4         | 3                  |
| Performance (2x)   | 4           | 4         | 5                  |
| AI-friendly (2x)   | 5           | 3         | 3                  |
| Footprint (1x)     | 4           | 4         | 5                  |
| Escape hatch (3x)  | 4           | 5         | 5                  |
| **Weighted Total** | **58**      | **55**    | **58**             |

> FeedKit wins on AI-friendliness (well-documented, Codable-like API, widely referenced in training data) and podcast-specific features. Custom ties on raw score but costs 2-4 weeks of development. **Pick: FeedKit v10.**

### Data Persistence

| Criterion (weight) | SwiftData | Core Data | GRDB (SQLite) |
|--------------------|:---------:|:---------:|:-------------:|
| Maturity (3x)      | 2         | 5         | 4             |
| Community (3x)     | 3         | 5         | 4             |
| Performance (2x)   | 3         | 4         | 5             |
| AI-friendly (2x)   | 4         | 4         | 3             |
| Footprint (1x)     | 4         | 3         | 5             |
| Escape hatch (3x)  | 2         | 3         | 5             |
| **Weighted Total** | **40**    | **58**    | **60**        |

> GRDB edges out Core Data on escape hatch (pure SQL, no framework lock-in) and performance. SwiftData scores low due to CloudKit sync immaturity and limited escape hatch (opaque store). **Pick: GRDB** -- pairs cleanly with CKSyncEngine for sync, gives full SQLite control, MIT licensed, 8.3k stars, actively maintained.

### Audio Engine

| Criterion (weight) | AVPlayer | AVAudioEngine | Hybrid (AVPlayer then AVAudioEngine) |
|--------------------|:--------:|:-------------:|:------------------------------------:|
| Maturity (3x)      | 5        | 4             | 5                                    |
| Community (3x)     | 5        | 3             | 4                                    |
| Performance (2x)   | 4        | 5             | 4                                    |
| AI-friendly (2x)   | 5        | 3             | 4                                    |
| Footprint (1x)     | 5        | 3             | 4                                    |
| Escape hatch (3x)  | 3        | 5             | 5                                    |
| **Weighted Total** | **63**   | **53**        | **62**                               |

> AVPlayer wins for MVP (streaming, background audio, AirPlay all built-in). Hybrid approach scores nearly as high and provides the escape hatch to AVAudioEngine for Smart Speed / Voice Boost later. **Pick: Hybrid** -- AVPlayer for MVP, protocol-abstracted swap to AVAudioEngine when audio processing features ship.

---

## Recommended Stack Summary

| Layer | Choice | Rationale |
|-------|--------|-----------|
| RSS Parsing | FeedKit v10 | Podcast-native, async/await, MIT, minimal boilerplate |
| Podcast Search | Podcast Index API + Apple iTunes Lookup | Free, open, Podcasting 2.0, comprehensive |
| Audio Playback | AVPlayer (MVP) -> AVAudioEngine (Smart Speed pass) | Ship fast, migrate cleanly |
| Persistence | GRDB | Full SQLite control, best performance, clean CKSyncEngine pairing |
| Cloud Sync | CKSyncEngine (post-MVP) | iOS 17+, works with any store, avoids SwiftData sync pitfalls |
| Background Downloads | URLSession background configuration | Survives app termination, system-managed |
| Feed Refresh | BGTaskScheduler (BGAppRefreshTask) | System-scheduled, battery-friendly |

---

## Sources

- [FeedKit GitHub](https://github.com/nmdias/FeedKit)
- [SWXMLHash GitHub](https://github.com/drmohundro/SWXMLHash)
- [GRDB.swift GitHub](https://github.com/groue/GRDB.swift)
- [Podcast Index API Docs](https://podcastindex-org.github.io/docs-api/)
- [Apple iTunes Search API](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/index.html)
- [CKSyncEngine Sample (Apple)](https://github.com/apple/sample-cloudkit-sync-engine)
- [SwiftData + CKSyncEngine Integration Guide](https://yingjiezhao.com/en/articles/Implementing-iCloud-Sync-by-Combining-SwiftData-with-CKSyncEngine/)
- [SwiftData CloudKit Pitfalls (fatbobman)](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/)
- [Silence Trimming Implementation (Forasoft)](https://www.forasoft.com/blog/article/how-to-implement-silence-trimming-feature-to-your-ios-app-1720)
- [SwiftAudioPlayer (AVAudioEngine streaming)](https://github.com/tanhakabir/SwiftAudioPlayer)
- [Background Tasks iOS Complete Guide](https://medium.com/@chandra.welim/background-tasks-in-ios-the-complete-guide-2a46b793084b)
- [iOS Background URLSession Guide](https://medium.com/@melissazm/ios-18-background-survival-guide-part-3-unstoppable-networking-with-background-urlsession-f9c8f01f665b)
- [cuappdev/podcast-ios](https://github.com/cuappdev/podcast-ios)
- [Core Data vs SwiftData 2025](https://distantjob.com/blog/core-data-vs-swiftdata/)
