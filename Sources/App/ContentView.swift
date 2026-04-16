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
    @Binding var showNowPlaying: Bool

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading) {
                Text("Now Playing")
                    .font(.caption.bold())
                Text(audioEngine.playbackState.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

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
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .onTapGesture { showNowPlaying = true }
    }
}
