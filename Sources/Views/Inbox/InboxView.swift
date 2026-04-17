import SwiftUI

/// Castro-style inbox: new episodes arrive here for triage (queue or skip).
struct InboxView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(AudioEngine.self) private var audioEngine
    @Environment(FeedEngine.self) private var feedEngine
    @State private var expandedEpisodeID: UUID?
    @State private var showInfoForEpisode: EpisodeWithPodcast?

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
                        VStack(spacing: 0) {
                            InboxEpisodeRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        if expandedEpisodeID == item.episode.id {
                                            expandedEpisodeID = nil
                                        } else {
                                            expandedEpisodeID = item.episode.id
                                        }
                                    }
                                }

                            if expandedEpisodeID == item.episode.id {
                                EpisodeOptionsDrawer(
                                    episode: item.episode,
                                    podcastTitle: item.podcast.title,
                                    context: .inbox,
                                    onCollapse: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            expandedEpisodeID = nil
                                        }
                                    },
                                    onShowInfo: {
                                        showInfoForEpisode = item
                                    }
                                )
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
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
            .refreshable {
                _ = await feedEngine.refreshAll()
            }
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    NavigationLink {
                        AddPodcastView()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    Spacer()
                }
            }
            .sheet(item: $showInfoForEpisode) { item in
                NavigationStack {
                    EpisodeInfoView(episode: item.episode, podcastTitle: item.podcast.title)
                }
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
                    .lineLimit(1)
                Text(item.episode.title)
                    .font(.headline)
                    .lineLimit(2)
                HStack {
                    Text(relativeTimestamp(for: item.episode.publishedDate))
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

    private func relativeTimestamp(for date: Date) -> String {
        let elapsed = Date.now.timeIntervalSince(date)

        if elapsed < 0 {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }

        switch elapsed {
        case ..<60:
            return "Just now"
        case ..<3600:
            return "\(Int(elapsed / 60))m ago"
        case ..<86400:
            return "\(Int(elapsed / 3600))h ago"
        default:
            let calendar = Calendar.current
            if calendar.isDateInYesterday(date) {
                return "Yesterday"
            }
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}
