import SwiftUI

/// Castro-style inbox: new episodes arrive here for triage (queue or skip).
struct InboxView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(AudioEngine.self) private var audioEngine
    @State private var selectedEpisode: EpisodeWithPodcast?

    var body: some View {
        NavigationStack {
            List {
                if dataStore.inbox.isEmpty {
                    ContentUnavailableView(
                        "Inbox Empty",
                        systemImage: "tray",
                        description: Text("Subscribe to a podcast to see new episodes here.")
                    )
                } else {
                    ForEach(dataStore.inbox, id: \.episode.id) { item in
                        InboxEpisodeRow(item: item)
                            .onTapGesture { selectedEpisode = item }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    try? dataStore.triageToQueue(episodeID: item.episode.id)
                                } label: {
                                    Label("Queue", systemImage: "plus")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    try? dataStore.triageToSkip(episodeID: item.episode.id)
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                .tint(.orange)
                            }
                    }
                }
            }
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AddPodcastView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $selectedEpisode) {
                EpisodeOptionsDrawer(
                    episode: $0.episode,
                    podcastTitle: $0.podcast.title,
                    context: .inbox
                )
            }
        }
    }
}

struct InboxEpisodeRow: View {
    let item: EpisodeWithPodcast
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(DataStore.self) private var dataStore

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.podcast.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.episode.title)
                    .font(.headline)
                    .lineLimit(2)
                HStack {
                    Text(item.episode.publishedDate, style: .date)
                    if item.episode.duration > 0 {
                        Text("·")
                        Text(formatDuration(item.episode.duration))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            downloadControl
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var downloadControl: some View {
        if item.episode.localFilePath != nil {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .imageScale(.large)
        } else if let progress = downloadManager.activeDownloads[item.episode.id] {
            ProgressView(value: progress)
                .frame(width: 32)
        } else {
            Button {
                let ep = item.episode
                Task {
                    do {
                        let url = try await downloadManager.download(episode: ep)
                        try dataStore.updateLocalFilePath(ep.id, path: url.path)
                    } catch {
                        print("Download error: \(error)")
                    }
                }
            } label: {
                Image(systemName: "cloud.arrow.down")
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        if mins >= 60 {
            return "\(mins / 60)h \(mins % 60)m"
        }
        return "\(mins)m"
    }
}
