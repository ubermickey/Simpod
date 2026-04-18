import SwiftUI

struct ContentView: View {
    @Environment(AudioEngine.self) private var audioEngine
    @Environment(DataStore.self) private var dataStore
    @Environment(FeedEngine.self) private var feedEngine
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
        .overlay(alignment: .top) {
            if feedEngine.isRefreshing {
                RefreshStatusBar()
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: feedEngine.isRefreshing)
            }
        }
    }
}

/// Persistent mini player shown above the tab bar during playback.
struct MiniPlayerView: View {
    @Environment(AudioEngine.self) private var audioEngine
    @Environment(DataStore.self) private var dataStore
    @Binding var showNowPlaying: Bool

    var body: some View {
        let info = currentInfo
        HStack(spacing: 12) {
            // Play/Pause — leftmost, largest, pink accent when playing
            Button {
                switch audioEngine.playbackState {
                case .playing: audioEngine.pause()
                case .paused: audioEngine.resume()
                default: break
                }
            } label: {
                Image(systemName: audioEngine.playbackState == .playing ? "pause.fill" : "play.fill")
                    .font(.title2.bold())
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(audioEngine.playbackState == .playing ? Color(hex: "#FF6B8A") : .primary)

            Button { try? audioEngine.skipBackward() } label: {
                Image(systemName: "gobackward.15")
                    .font(.title3)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderless)

            Button { try? audioEngine.skipForward() } label: {
                Image(systemName: "goforward.30")
                    .font(.title3)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderless)

            Button { playNextInQueue() } label: {
                Image(systemName: "forward.fill")
                    .font(.body)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)

            Spacer()

            // Episode info (trailing)
            VStack(alignment: .trailing, spacing: 2) {
                Text(info.episodeTitle)
                    .font(.caption.bold())
                    .lineLimit(1)
                Text(info.podcastTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Podcast artwork
            AsyncImage(url: info.podcast?.artworkURL.flatMap(URL.init)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 6).fill(.quaternary)
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .onTapGesture { showNowPlaying = true }
    }

    /// Single lookup into inbox + queue; called once per render via the
    /// `let info = currentInfo` binding in body. Replaces three separate
    /// computed properties that each scanned both arrays.
    private var currentInfo: (episodeTitle: String, podcastTitle: String, podcast: Podcast?) {
        guard let episodeID = audioEngine.currentEpisodeID else {
            return ("Not Playing", "", nil)
        }
        if let match = dataStore.inbox.first(where: { $0.episode.id == episodeID }) {
            return (match.episode.title, match.podcast.title, match.podcast)
        }
        if let match = dataStore.queue.first(where: { $0.episode.id == episodeID }) {
            return (match.episode.title, match.podcast.title, match.podcast)
        }
        return ("Now Playing", "", nil)
    }

    private func playNextInQueue() {
        let queue = dataStore.queue
        guard !queue.isEmpty else { return }

        if let currentID = audioEngine.currentEpisodeID,
           let currentIndex = queue.firstIndex(where: { $0.episode.id == currentID }),
           currentIndex + 1 < queue.count {
            let nextEpisode = queue[currentIndex + 1].episode
            try? dataStore.moveEpisodeToTopAndPlay(nextEpisode.id, audioEngine: audioEngine)
        } else {
            let firstEpisode = queue[0].episode
            try? dataStore.moveEpisodeToTopAndPlay(firstEpisode.id, audioEngine: audioEngine)
        }

        // Auto-refill if queue runs low
        try? dataStore.appendRandomRecentUnplayedEpisodeIfNeeded(currentlyPlayingID: audioEngine.currentEpisodeID)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        self.init(
            red: Double((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgbValue & 0x0000FF) / 255.0
        )
    }
}
