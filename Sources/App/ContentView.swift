import SwiftUI

struct ContentView: View {
    @Environment(AudioEngine.self) private var audioEngine
    @Environment(DataStore.self) private var dataStore
    @State private var showNowPlaying = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                InboxView()
                    .tabItem {
                        Label("Inbox", systemImage: "tray")
                    }
                    .badge(dataStore.inboxCount)

                QueueView()
                    .tabItem {
                        Label("Queue", systemImage: "list.bullet")
                    }

                RemindersView()
                    .tabItem {
                        Label("Reminders", systemImage: "clock.arrow.circlepath")
                    }
                    .badge(dataStore.reminders.count)

                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }

            // Mini player above tab bar
            if audioEngine.playbackState != .stopped {
                MiniPlayerView(showNowPlaying: $showNowPlaying)
                    .padding(.bottom, 49) // Tab bar height
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView()
        }
    }
}

/// Persistent mini player shown above the tab bar during playback.
struct MiniPlayerView: View {
    @Environment(AudioEngine.self) private var audioEngine
    @Environment(DataStore.self) private var dataStore
    @Binding var showNowPlaying: Bool

    var body: some View {
        HStack(spacing: 16) {
            Spacer()

            // Controls cluster (CENTERED for both-hand accessibility)
            HStack(spacing: 12) {
                Button { try? audioEngine.skipBackward() } label: {
                    Image(systemName: "gobackward.15")
                        .font(.body)
                }
                .buttonStyle(.borderless)

                Button {
                    switch audioEngine.playbackState {
                    case .playing: audioEngine.pause()
                    case .paused: audioEngine.resume()
                    default: break
                    }
                } label: {
                    Image(systemName: audioEngine.playbackState == .playing ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderless)

                Button { try? audioEngine.skipForward() } label: {
                    Image(systemName: "goforward.30")
                        .font(.body)
                }
                .buttonStyle(.borderless)

                Button { playNextInQueue() } label: {
                    Image(systemName: "forward.fill")
                        .font(.body)
                }
                .buttonStyle(.borderless)
            }
            .foregroundStyle(.primary)

            Spacer()

            // Episode info (trailing)
            VStack(alignment: .trailing) {
                Text(currentEpisodeTitle)
                    .font(.caption.bold())
                    .lineLimit(1)
                Text(currentPodcastTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .onTapGesture { showNowPlaying = true }
    }

    private var currentEpisodeTitle: String {
        guard let episodeID = audioEngine.currentEpisodeID else { return "Not Playing" }
        if let found = dataStore.inbox.first(where: { $0.episode.id == episodeID }) {
            return found.episode.title
        }
        if let found = dataStore.queue.first(where: { $0.episode.id == episodeID }) {
            return found.episode.title
        }
        return "Now Playing"
    }

    private var currentPodcastTitle: String {
        guard let episodeID = audioEngine.currentEpisodeID else { return "" }
        if let found = dataStore.inbox.first(where: { $0.episode.id == episodeID }) {
            return found.podcast.title
        }
        if let found = dataStore.queue.first(where: { $0.episode.id == episodeID }) {
            return found.podcast.title
        }
        return ""
    }

    private func playNextInQueue() {
        let queue = dataStore.queue
        guard !queue.isEmpty else { return }

        if let currentID = audioEngine.currentEpisodeID,
           let currentIndex = queue.firstIndex(where: { $0.episode.id == currentID }),
           currentIndex + 1 < queue.count {
            let nextEpisode = queue[currentIndex + 1].episode
            playEpisode(nextEpisode)
        } else {
            let firstEpisode = queue[0].episode
            playEpisode(firstEpisode)
        }
    }

    private func playEpisode(_ episode: Episode) {
        if let localPath = episode.localFilePath,
           let fileURL = URL(string: localPath) ?? URL(fileURLWithPath: localPath) as URL? {
            try? audioEngine.play(fileURL: fileURL, episodeID: episode.id, startPosition: episode.playbackPosition)
        } else if let remoteURL = URL(string: episode.audioURL) {
            audioEngine.playStream(url: remoteURL, episodeID: episode.id, startPosition: episode.playbackPosition)
        }
    }
}
