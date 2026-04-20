import AVFoundation
import Foundation
import MediaPlayer
import Observation
import UIKit
import os

/// Podcast audio playback engine built on AVAudioEngine.
/// Supports streaming, local playback, speed control, and will support
/// Smart Speed (silence trimming) and Voice Boost (dynamic compression).
@Observable
final class AudioEngine: @unchecked Sendable {
    // MARK: - Observable State

    var playbackState: PlaybackState = .stopped
    var currentPosition: TimeInterval = 0
    var duration: TimeInterval = 0
    var playbackRate: Float = 1.0
    var currentEpisodeID: UUID?

    // MARK: - Audio Components

    // Local playback (AVAudioEngine — for downloaded files, future DSP)
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitchNode = AVAudioUnitTimePitch()
    private var audioFile: AVAudioFile?

    // Remote streaming (AVPlayer — for non-downloaded episodes)
    private var avPlayer: AVPlayer?
    private var playerObserver: Any?

    private var positionTask: Task<Void, Never>?
    private var isStreamingRemote = false

    // Position persistence callback
    var onPositionUpdate: ((UUID, TimeInterval) -> Void)?

    // MARK: - Now Playing infrastructure

    /// Weak ref so AudioEngine never extends DataStore's lifetime.
    /// AppContainer owns both strongly for the app's lifetime.
    private weak var dataStore: DataStore?

    /// Bounded in-memory artwork cache (FIFO eviction). 8 entries are
    /// plenty for the active set; podcast artwork is small.
    private var artworkCache: [String: UIImage] = [:]
    private var artworkCacheOrder: [String] = []
    private let artworkCacheLimit = 8

    private let nowPlayingLogger = Logger(subsystem: "com.simpod", category: "NowPlaying")

    init(dataStore: DataStore? = nil) {
        self.dataStore = dataStore
        setupAudioSession()
        setupEngine()
        setupRemoteCommands()
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }

        // Handle interruptions (phone calls, Siri, etc.)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }

        // Handle output route changes — only old-device-unavailable
        // (headphone unplug, AirPods removed, BT speaker off) pauses.
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
    }

    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(timePitchNode)
        engine.connect(playerNode, to: timePitchNode, format: nil)
        engine.connect(timePitchNode, to: engine.mainMixerNode, format: nil)
    }

    // MARK: - Playback Controls

    /// Play an episode from a local file URL.
    func play(fileURL: URL, episodeID: UUID, startPosition: TimeInterval = 0) throws {
        stop()

        let file = try AVAudioFile(forReading: fileURL)
        self.audioFile = file
        self.currentEpisodeID = episodeID
        self.duration = Double(file.length) / file.processingFormat.sampleRate

        engine.connect(playerNode, to: timePitchNode, format: file.processingFormat)
        engine.connect(timePitchNode, to: engine.mainMixerNode, format: nil)

        try engine.start()

        // Schedule playback from the start position
        if startPosition > 0 {
            let framePosition = AVAudioFramePosition(startPosition * file.processingFormat.sampleRate)
            let frameCount = AVAudioFrameCount(file.length - framePosition)
            if frameCount > 0 {
                playerNode.scheduleSegment(file, startingFrame: framePosition, frameCount: frameCount, at: nil)
            }
        } else {
            playerNode.scheduleFile(file, at: nil)
        }

        playerNode.play()
        playbackState = .playing
        currentPosition = startPosition
        startPositionTracking()
        updateNowPlayingInfo(fullPublish: true)
    }

    /// Stream an episode from a remote URL via AVPlayer.
    func playStream(url: URL, episodeID: UUID, startPosition: TimeInterval = 0) {
        stop()

        isStreamingRemote = true
        currentEpisodeID = episodeID
        playbackState = .loading

        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        self.avPlayer = player

        // Observe when the item is ready to play
        playerObserver = playerItem.observe(\.status) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
                    if startPosition > 0 {
                        player.seek(to: CMTime(seconds: startPosition, preferredTimescale: 600)) { _ in
                            player.play()
                            player.rate = self.playbackRate
                        }
                    } else {
                        player.play()
                        player.rate = self.playbackRate
                    }
                    self.currentPosition = startPosition
                    self.playbackState = .playing
                    self.startPositionTracking()
                    self.updateNowPlayingInfo(fullPublish: true)
                case .failed:
                    self.playbackState = .error
                default:
                    break
                }
            }
        }
    }

    func pause() {
        if isStreamingRemote {
            avPlayer?.pause()
        } else {
            playerNode.pause()
        }
        playbackState = .paused
        stopPositionTracking()
        persistPosition()
        updateNowPlayingInfo(fullPublish: false)
    }

    func resume() {
        if isStreamingRemote {
            avPlayer?.play()
        } else {
            playerNode.play()
        }
        playbackState = .playing
        startPositionTracking()
        updateNowPlayingInfo(fullPublish: false)
    }

    func stop() {
        if isStreamingRemote {
            avPlayer?.pause()
            if let observer = playerObserver as? NSKeyValueObservation {
                observer.invalidate()
            }
            playerObserver = nil
            avPlayer = nil
        } else {
            playerNode.stop()
            engine.stop()
        }
        isStreamingRemote = false
        playbackState = .stopped
        stopPositionTracking()
        persistPosition()
        currentEpisodeID = nil
        currentPosition = 0
        duration = 0
        clearNowPlayingInfo()
    }

    func seek(to position: TimeInterval) throws {
        if isStreamingRemote {
            avPlayer?.seek(to: CMTime(seconds: position, preferredTimescale: 600))
            currentPosition = position
            updateNowPlayingInfo(fullPublish: false)
            return
        }

        guard let file = audioFile else { return }

        let wasPlaying = playbackState == .playing
        playerNode.stop()

        let framePosition = AVAudioFramePosition(position * file.processingFormat.sampleRate)
        let frameCount = AVAudioFrameCount(file.length - framePosition)
        guard frameCount > 0 else { return }

        playerNode.scheduleSegment(file, startingFrame: framePosition, frameCount: frameCount, at: nil)
        currentPosition = position

        if wasPlaying {
            playerNode.play()
        }
        updateNowPlayingInfo(fullPublish: false)
    }

    func setSpeed(_ rate: Float) {
        playbackRate = rate.clamped(to: 0.5...3.0)
        if isStreamingRemote {
            avPlayer?.rate = playbackRate
        } else {
            timePitchNode.rate = playbackRate
        }
        if playbackState == .playing {
            updateNowPlayingInfo(fullPublish: false)
        }
    }

    func skipForward(_ seconds: TimeInterval = 30) throws {
        try seek(to: min(currentPosition + seconds, duration))
    }

    func skipBackward(_ seconds: TimeInterval = 15) throws {
        try seek(to: max(currentPosition - seconds, 0))
    }

    // MARK: - Position Tracking

    private func startPositionTracking() {
        positionTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                self?.updatePosition()
            }
        }
    }

    private func stopPositionTracking() {
        positionTask?.cancel()
        positionTask = nil
    }

    private func updatePosition() {
        if isStreamingRemote {
            guard let player = avPlayer else { return }
            let time = player.currentTime().seconds
            if time.isFinite { currentPosition = time }
            if let item = player.currentItem, item.duration.seconds.isFinite {
                duration = item.duration.seconds
            }
        } else {
            guard let nodeTime = playerNode.lastRenderTime,
                  let playerTime = playerNode.playerTime(forNodeTime: nodeTime),
                  let file = audioFile else { return }
            let sampleRate = file.processingFormat.sampleRate
            currentPosition = Double(playerTime.sampleTime) / sampleRate
        }

        // Persist every 5 seconds
        if Int(currentPosition) % 5 == 0 {
            persistPosition()
        }
    }

    private func persistPosition() {
        guard let episodeID = currentEpisodeID else { return }
        onPositionUpdate?(episodeID, currentPosition)
    }

    // MARK: - Interruption Handling

    // MARK: - Route Change

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else { return }
        guard reason == .oldDeviceUnavailable else { return }
        guard playbackState == .playing else { return }
        pause()
    }

    // MARK: - Remote Commands (lock screen / Control Center / AirPods)

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            guard self.playbackState == .paused else { return .commandFailed }
            self.resume()
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            guard self.playbackState == .playing else { return .commandFailed }
            self.pause()
            return .success
        }

        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            switch self.playbackState {
            case .playing:
                self.pause()
                return .success
            case .paused:
                self.resume()
                return .success
            default:
                return .commandFailed
            }
        }

        center.skipForwardCommand.preferredIntervals = [30]
        center.skipForwardCommand.addTarget { [weak self] _ in
            guard let self, self.currentEpisodeID != nil else {
                return .noActionableNowPlayingItem
            }
            try? self.skipForward(30)
            return .success
        }

        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            guard let self, self.currentEpisodeID != nil else {
                return .noActionableNowPlayingItem
            }
            try? self.skipBackward(15)
            return .success
        }

        center.nextTrackCommand.addTarget { [weak self] _ in
            guard let self, let store = self.dataStore else { return .noSuchContent }
            let snapshot = store.queue
            guard !snapshot.isEmpty else { return .noSuchContent }
            guard let currentID = self.currentEpisodeID,
                  let idx = snapshot.firstIndex(where: { $0.episode.id == currentID }),
                  idx + 1 < snapshot.count
            else { return .noSuchContent }
            let nextID = snapshot[idx + 1].episode.id
            do {
                try store.moveEpisodeToTopAndPlay(nextID, audioEngine: self)
                return .success
            } catch {
                return .commandFailed
            }
        }

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self else { return .commandFailed }
            guard self.duration > 0 else { return .commandFailed }
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let clamped = min(max(positionEvent.positionTime, 0), self.duration)
            try? self.seek(to: clamped)
            return .success
        }

        // Disable defaults the system might otherwise auto-enable.
        let disabled: [MPRemoteCommand] = [
            center.previousTrackCommand,
            center.seekForwardCommand,
            center.seekBackwardCommand,
            center.changeRepeatModeCommand,
            center.changeShuffleModeCommand,
            center.changePlaybackRateCommand,
            center.ratingCommand,
            center.likeCommand,
            center.dislikeCommand,
            center.bookmarkCommand
        ]
        for cmd in disabled { cmd.isEnabled = false }
    }

    // MARK: - Now Playing Info

    /// Publish or update `MPNowPlayingInfoCenter.default().nowPlayingInfo`.
    /// `fullPublish: true` rebuilds the dictionary from scratch (new episode);
    /// `false` mutates the existing dictionary in place (rate/elapsed only).
    /// Internal (not private) so the A1 unit test can drive the publish path
    /// without bringing up an AVAudioEngine output chain in the simulator.
    func updateNowPlayingInfo(fullPublish: Bool) {
        guard let episodeID = currentEpisodeID else { return }
        let center = MPNowPlayingInfoCenter.default()

        if fullPublish {
            // Clear first so no field bleeds from the previous episode.
            center.nowPlayingInfo = nil

            let podcast = dataStore?.currentPlayingPodcast(episodeID: episodeID)
            let episodeTitle = dataStore?.inbox.first(where: { $0.episode.id == episodeID })?.episode.title
                ?? dataStore?.queue.first(where: { $0.episode.id == episodeID })?.episode.title
                ?? ""

            var info: [String: Any] = [
                MPMediaItemPropertyTitle: episodeTitle,
                MPMediaItemPropertyArtist: podcast?.title ?? "",
                MPMediaItemPropertyPlaybackDuration: duration as NSNumber,
                MPNowPlayingInfoPropertyElapsedPlaybackTime: currentPosition as NSNumber,
                MPNowPlayingInfoPropertyPlaybackRate: (playbackState == .playing ? playbackRate : 0.0) as NSNumber,
                MPMediaItemPropertyMediaType: MPMediaType.podcast.rawValue as NSNumber
            ]

            // Synchronous artwork from cache if available.
            if let urlString = podcast?.artworkURL, let cached = artworkCache[urlString] {
                let size = cached.size
                let artwork = MPMediaItemArtwork(boundsSize: size) { _ in cached }
                info[MPMediaItemPropertyArtwork] = artwork
            }

            center.nowPlayingInfo = info

            // Kick off async artwork load if cache missed.
            if let urlString = podcast?.artworkURL,
               artworkCache[urlString] == nil,
               let url = URL(string: urlString) {
                loadArtwork(url: url, episodeID: episodeID)
            }
        } else {
            var info = center.nowPlayingInfo ?? [:]
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentPosition as NSNumber
            info[MPNowPlayingInfoPropertyPlaybackRate] = (playbackState == .playing ? playbackRate : 0.0) as NSNumber
            center.nowPlayingInfo = info
        }
    }

    func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func loadArtwork(url: URL, episodeID: UUID) {
        let urlString = url.absoluteString
        Task.detached { [weak self] in
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    self?.nowPlayingLogger.info("artwork HTTP \(http.statusCode) for \(urlString, privacy: .public)")
                    return
                }
                guard let image = UIImage(data: data) else {
                    self?.nowPlayingLogger.info("artwork decode failed for \(urlString, privacy: .public)")
                    return
                }
                await MainActor.run {
                    guard let self else { return }
                    self.cacheArtwork(image, for: urlString)
                    // Drop stale result if the episode changed mid-flight.
                    guard self.currentEpisodeID == episodeID else { return }
                    let center = MPNowPlayingInfoCenter.default()
                    var info = center.nowPlayingInfo ?? [:]
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    info[MPMediaItemPropertyArtwork] = artwork
                    center.nowPlayingInfo = info
                }
            } catch {
                self?.nowPlayingLogger.info("artwork fetch failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func cacheArtwork(_ image: UIImage, for urlString: String) {
        if artworkCache[urlString] != nil { return }
        artworkCache[urlString] = image
        artworkCacheOrder.append(urlString)
        while artworkCacheOrder.count > artworkCacheLimit {
            let evict = artworkCacheOrder.removeFirst()
            artworkCache.removeValue(forKey: evict)
        }
    }

    // MARK: - Interruption Handling

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            pause()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                resume()
            }
        @unknown default:
            break
        }
    }
}

enum PlaybackState: String, Sendable {
    case stopped
    case loading
    case playing
    case paused
    case error
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
