import SwiftUI

/// Full-screen Now Playing with playback controls, artwork, and episode info.
struct NowPlayingView: View {
    @Environment(AudioEngine.self) private var audioEngine

    var body: some View {
        VStack(spacing: 24) {
            // Top third: Artwork (decorative, no tap targets)
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary)
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 48)

            // Middle third: Episode info + Progress
            VStack(spacing: 4) {
                Text("Now Playing")
                    .font(.title3.bold())
                Text(audioEngine.playbackState.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                ProgressView(value: audioEngine.currentPosition, total: max(audioEngine.duration, 1))
                HStack {
                    Text(formatTime(audioEngine.currentPosition))
                    Spacer()
                    Text("-\(formatTime(audioEngine.duration - audioEngine.currentPosition))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            .padding(.horizontal, 32)

            Spacer()

            // Bottom third: Playback controls (in thumb zone)
            HStack(spacing: 40) {
                Button { try? audioEngine.skipBackward() } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                }

                Button {
                    switch audioEngine.playbackState {
                    case .playing: audioEngine.pause()
                    case .paused: audioEngine.resume()
                    default: break
                    }
                } label: {
                    Image(systemName: audioEngine.playbackState == .playing ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                }

                Button { try? audioEngine.skipForward() } label: {
                    Image(systemName: "goforward.30")
                        .font(.title)
                }
            }
            .foregroundStyle(.primary)

            // Speed control
            HStack {
                Text("Speed: \(String(format: "%.1fx", audioEngine.playbackRate))")
                    .font(.caption)
                Slider(value: Binding(
                    get: { audioEngine.playbackRate },
                    set: { audioEngine.setSpeed($0) }
                ), in: 0.5...3.0, step: 0.1)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(max(seconds, 0))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
