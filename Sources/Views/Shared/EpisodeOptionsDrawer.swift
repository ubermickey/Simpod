import SwiftUI

/// The context from which the drawer was opened — drives which actions are shown.
enum EpisodeContext {
    case inbox
    case queue
}

/// A bottom-sheet drawer presenting context-appropriate actions for a single episode.
/// Present with `.sheet` and auto-dismisses after every action.
struct EpisodeOptionsDrawer: View {
    let episode: Episode
    let podcastTitle: String
    let context: EpisodeContext

    @Environment(\.dismiss) private var dismiss
    @Environment(DataStore.self) private var dataStore
    @Environment(AudioEngine.self) private var audioEngine
    @Environment(DownloadManager.self) private var downloadManager

    @State private var showHideOptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // MARK: Header
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(podcastTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Divider()

            // MARK: Action Buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    switch context {
                    case .inbox:
                        inboxActions
                    case .queue:
                        queueActions
                    }
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .confirmationDialog("Remind me?", isPresented: $showHideOptions, titleVisibility: .visible) {
            Button("In 1 Hour") {
                try? dataStore.hideEpisode(episode.id, remindAt: Date.now + 3600)
                dismiss()
            }
            Button("Tomorrow Morning") {
                try? dataStore.hideEpisode(episode.id, remindAt: tomorrowMorning)
                dismiss()
            }
            Button("Next Week") {
                try? dataStore.hideEpisode(episode.id, remindAt: Date.now + 604800)
                dismiss()
            }
            Button("Hide Indefinitely") {
                try? dataStore.hideEpisode(episode.id, remindAt: nil)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Inbox Actions

    @ViewBuilder
    private var inboxActions: some View {
        actionButton("text.line.last.and.arrowhead.forward", "Queue") {
            try? dataStore.triageToQueue(episodeID: episode.id)
        }
        actionButton("text.line.first.and.arrowhead.forward", "Play Next") {
            try? dataStore.addToQueueAtTop(episodeID: episode.id)
        }
        actionButton("play.fill", "Play Now") {
            playEpisode(episode)
        }
        if episode.localFilePath == nil {
            downloadButton
        }
        actionButton("archivebox", "Archive") {
            try? dataStore.triageToSkip(episodeID: episode.id)
        }
    }

    // MARK: - Queue Actions

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
        hideButton
        if episode.localFilePath == nil {
            downloadButton
        }
        actionButton("xmark.circle", "Remove") {
            try? dataStore.removeFromQueue(episodeID: episode.id)
        }
    }

    // MARK: - Special Buttons

    /// Download button — wraps async download in a Task; does not auto-dismiss until done.
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
            dismiss()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "arrow.down.circle")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                Text("Download")
                    .font(.caption2)
            }
        }
        .buttonStyle(.plain)
    }

    /// Hide button — triggers the reminder confirmation dialog instead of dismissing immediately.
    private var hideButton: some View {
        Button {
            showHideOptions = true
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "eye.slash")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                Text("Hide")
                    .font(.caption2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    /// Generic icon-above-label action button. Auto-dismisses after action.
    private func actionButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.title2)
                    .frame(width: 44, height: 44)
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

    /// Tomorrow at 08:00 in the user's local calendar.
    private var tomorrowMorning: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date.now)
        components.day = (components.day ?? 0) + 1
        components.hour = 8
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components) ?? Date.now + 86400
    }
}
