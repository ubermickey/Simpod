import Foundation
import Testing
import MediaPlayer
@testable import Simpod

/// A1 gate from plan `floating-beaming-dahl.md` — verifies AudioEngine
/// publishes the required Now Playing dictionary, transitions playback rate
/// on pause, and clears on stop. Drives engine state directly rather than
/// running real audio playback because the iOS simulator unit-test process
/// cannot bring up an AVAudioEngine output chain (-10868). The publish
/// helper is the unit under test; the AVFoundation playback path is
/// validated by manual gates M1–M3.
@Suite("Now Playing Info")
struct NowPlayingInfoTests {

    @Test func publishMutateClear() async throws {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        let store = try DataStore.preview()
        let podcast = Podcast(
            feedURL: "https://nowplaying.test/feed",
            title: "Test Podcast",
            author: "Tester"
        )
        try store.savePodcast(podcast)
        let episode = Episode(
            podcastID: podcast.id,
            guid: "np-test",
            title: "Test Episode",
            audioURL: "https://nowplaying.test/ep.mp3",
            status: .inbox
        )
        try store.saveEpisode(episode)

        // Wait for GRDB observation to populate inbox.
        let deadline = Date().addingTimeInterval(2)
        while store.inbox.first(where: { $0.episode.id == episode.id }) == nil && Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        try #require(store.inbox.contains(where: { $0.episode.id == episode.id }))

        let engine = AudioEngine(dataStore: store)
        engine.currentEpisodeID = episode.id
        engine.duration = 600
        engine.currentPosition = 0
        engine.playbackRate = 1.0
        engine.playbackState = .playing
        engine.updateNowPlayingInfo(fullPublish: true)

        let info = try #require(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        #expect(info[MPMediaItemPropertyTitle] as? String == "Test Episode")
        #expect(info[MPMediaItemPropertyArtist] as? String == "Test Podcast")
        let duration = (info[MPMediaItemPropertyPlaybackDuration] as? NSNumber)?.doubleValue ?? 0
        #expect(duration == 600)
        #expect(info[MPNowPlayingInfoPropertyElapsedPlaybackTime] != nil)
        #expect((info[MPNowPlayingInfoPropertyPlaybackRate] as? NSNumber)?.floatValue == 1.0)
        #expect((info[MPMediaItemPropertyMediaType] as? NSNumber)?.uintValue == MPMediaType.podcast.rawValue)
        #expect(info[MPMediaItemPropertyArtwork] == nil)

        // Pause path — in-place rate mutation.
        engine.playbackState = .paused
        engine.updateNowPlayingInfo(fullPublish: false)
        let paused = try #require(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        #expect((paused[MPNowPlayingInfoPropertyPlaybackRate] as? NSNumber)?.floatValue == 0.0)
        // Title still present — only rate/elapsed are mutated.
        #expect(paused[MPMediaItemPropertyTitle] as? String == "Test Episode")

        // Stop path — full clear.
        engine.clearNowPlayingInfo()
        #expect(MPNowPlayingInfoCenter.default().nowPlayingInfo == nil)
    }
}
