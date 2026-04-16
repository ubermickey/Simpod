import SwiftUI

/// The context from which the action bar was opened — drives which actions are shown.
enum EpisodeContext {
    case inbox
    case queue
}

/// An inline action bar presenting context-appropriate actions for a single episode.
/// Embed directly in the parent view; the parent provides layout context.
struct EpisodeOptionsDrawer: View {
    let episode: Episode
    let podcastTitle: String
    let context: EpisodeContext
    var onCollapse: () -> Void
    var onShowInfo: () -> Void

    @Environment(DataStore.self) private var dataStore
    @Environment(AudioEngine.self) private var audioEngine
    @Environment(DownloadManager.self) private var downloadManager

    var body: some View {
        HStack(spacing: 12) {
            switch context {
            case .inbox:
                inboxActions
            case .queue:
                queueActions
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Inbox Actions
    // Order: Queue | Play Next | Play Now | Info | Archive

    @ViewBuilder
    private var inboxActions: some View {
        actionButton("text.line.last.and.arrowhead.forward", "Queue") {
            try? dataStore.triageToQueue(episodeID: episode.id)
            onCollapse()
        }
        actionButton("text.line.first.and.arrowhead.forward", "Play Next") {
            try? dataStore.addToQueueAtTop(episodeID: episode.id)
            onCollapse()
        }
        actionButton("play.fill", "Play Now") {
            playEpisode(episode)
        }
        if episode.localFilePath == nil {
            downloadButton
        }
        actionButton("info.circle", "Info") {
            onShowInfo()
        }
        actionButton("archivebox", "Archive") {
            try? dataStore.triageToSkip(episodeID: episode.id)
            onCollapse()
        }
    }

    // MARK: - Queue Actions
    // Order: Play Now | Play Next | Play Last | Hide | Info | Remove

    @ViewBuilder
    private var queueActions: some View {
        actionButton("play.fill", "Play Now") {
            playEpisode(episode)
        }
        actionButton("text.line.first.and.arrowhead.forward", "Play Next") {
            try? dataStore.moveToTop(episodeID: episode.id)
        }
        actionButton("text.line.last.and.arrowhead.forward", "Play Last") {
            try? dataStore.moveToBottom(episodeID: episode.id)
        }
        actionButton("eye.slash", "Hide") {
            try? dataStore.hideEpisode(episode.id)
            onCollapse()
        }
        actionButton("info.circle", "Info") {
            onShowInfo()
        }
        if episode.localFilePath == nil {
            downloadButton
        }
        actionButton("xmark.circle", "Remove") {
            try? dataStore.removeFromQueue(episodeID: episode.id)
            onCollapse()
        }
    }

    // MARK: - Special Buttons

    /// Download button — wraps async download in a Task; does not collapse until done.
    private var downloadButton: some View {
        Button {
            let ep = episode
            Task {
                do {
                    let url = try await downloadManager.download(episode: ep)
                    try dataStore.updateLocalFilePath(ep.id, path: url.path)
                } catch {
                    print("Download error: \(error)")
                }
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "arrow.down.circle")
                    .font(.title2)
                    .frame(width: 48, height: 48)
                Text("Download")
                    .font(.caption2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    /// Generic icon-above-label action button.
    private func actionButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.title2)
                    .frame(width: 48, height: 48)
                Text(label)
                    .font(.caption2)
            }
        }
        .buttonStyle(.plain)
    }

    /// Play an episode, preferring a local file over remote streaming.
    private func playEpisode(_ ep: Episode) {
        if let localPath = ep.localFilePath,
           let fileURL = URL(string: localPath) ?? URL(fileURLWithPath: localPath) as URL? {
            try? audioEngine.play(fileURL: fileURL, episodeID: ep.id, startPosition: ep.playbackPosition)
        } else if let remoteURL = URL(string: ep.audioURL) {
            audioEngine.playStream(url: remoteURL, episodeID: ep.id, startPosition: ep.playbackPosition)
        }
    }
}
