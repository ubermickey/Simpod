import SwiftUI

/// Ordered playback queue. Episodes triaged from Inbox land here.
struct QueueView: View {
    @Environment(DataStore.self) private var dataStore
    @State private var selectedItem: QueueItemWithEpisodeAndPodcast?

    var body: some View {
        NavigationStack {
            List {
                if dataStore.queue.isEmpty {
                    ContentUnavailableView(
                        "Queue Empty",
                        systemImage: "list.bullet",
                        description: Text("Swipe episodes right in the Inbox to add them here.")
                    )
                } else {
                    ForEach(dataStore.queue, id: \.queueItem.id) { item in
                        QueueEpisodeRow(item: item)
                            .onTapGesture {
                                selectedItem = item
                            }
                    }
                    .onMove { from, to in
                        moveItems(from: from, to: to)
                    }
                    .onDelete { offsets in
                        deleteItems(at: offsets)
                    }
                }
            }
            .navigationTitle("Queue")
            .sheet(item: $selectedItem) {
                EpisodeOptionsDrawer(
                    episode: $0.episode,
                    podcastTitle: $0.podcast.title,
                    context: .queue
                )
            }
        }
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var ids = dataStore.queue.map(\.queueItem.id)
        ids.move(fromOffsets: source, toOffset: destination)
        try? dataStore.reorderQueue(itemIDs: ids)
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = dataStore.queue[index]
            try? dataStore.removeFromQueue(episodeID: item.episode.id)
        }
    }
}

struct QueueEpisodeRow: View {
    let item: QueueItemWithEpisodeAndPodcast
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
                    if item.episode.playbackPosition > 0 {
                        ProgressView(value: item.episode.playbackPosition, total: max(item.episode.duration, 1))
                            .frame(width: 60)
                    }
                    Text(item.episode.publishedDate, style: .date)
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
                let episode = item.episode
                Task {
                    do {
                        let url = try await downloadManager.download(episode: episode)
                        try dataStore.updateLocalFilePath(episode.id, path: url.path)
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
}
