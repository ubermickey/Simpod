import AVFoundation
import Foundation
import Observation

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

    init() {
        setupAudioSession()
        setupEngine()
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
    }

    func resume() {
        if isStreamingRemote {
            avPlayer?.play()
        } else {
            playerNode.play()
        }
        playbackState = .playing
        startPositionTracking()
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
    }

    func seek(to position: TimeInterval) throws {
        if isStreamingRemote {
            avPlayer?.seek(to: CMTime(seconds: position, preferredTimescale: 600))
            currentPosition = position
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
    }

    func setSpeed(_ rate: Float) {
        playbackRate = rate.clamped(to: 0.5...3.0)
        if isStreamingRemote {
            avPlayer?.rate = playbackRate
        } else {
            timePitchNode.rate = playbackRate
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
