import SwiftUI

/// Read-only detail sheet showing full metadata, file details, and show notes
/// for a single episode. Presented from the options drawer's "Info" action.
struct EpisodeInfoView: View {
    let episode: Episode
    let podcastTitle: String

    var body: some View {
        List {
            metadataSection
            fileDetailsSection
            showNotesSection
        }
        .navigationTitle("Episode Info")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var metadataSection: some View {
        Section("Metadata") {
            infoRow("Podcast", value: podcastTitle)
            infoRow("Title", value: episode.title)
            infoRow("Published", value: episode.publishedDate.formatted(date: .abbreviated, time: .omitted))
            infoRow("Duration", value: formatDuration(episode.duration))
            VStack(alignment: .leading, spacing: 4) {
                Text("GUID")
                    .foregroundStyle(.secondary)
                Text(episode.guid)
                    .font(.caption)
                    .monospaced()
            }
        }
    }

    private var fileDetailsSection: some View {
        Section("File Details") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Audio URL")
                    .foregroundStyle(.secondary)
                Text(episode.audioURL)
                    .font(.caption)
                    .monospaced()
                    .lineLimit(2)
            }
            infoRow("Downloaded", value: episode.localFilePath != nil ? "Yes" : "No")
            if let localPath = episode.localFilePath {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local Path")
                        .foregroundStyle(.secondary)
                    Text(localPath)
                        .font(.caption)
                        .monospaced()
                        .lineLimit(2)
                }
            }
            infoRow("Format", value: audioFormat(from: episode.audioURL))
        }
    }

    private var showNotesSection: some View {
        Section("Show Notes") {
            if episode.episodeDescription.isEmpty {
                Text("No show notes available.")
                    .foregroundStyle(.secondary)
            } else {
                Text(episode.episodeDescription)
            }
        }
    }

    // MARK: - Helpers

    /// Renders a label/value pair as a single row.
    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }

    /// Formats a duration in seconds as "Xh Xm" when >= 1 hour, or "Xm" otherwise.
    func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return "\(hours)h \(minutes)m"
        }
        return "\(totalMinutes)m"
    }

    /// Extracts the file extension from a URL string (e.g. "mp3", "m4a").
    /// Static string parsing only — never performs I/O or async work.
    private func audioFormat(from urlString: String) -> String {
        // Strip any query string before looking at the path extension.
        let pathPart = urlString.components(separatedBy: "?").first ?? urlString
        let ext = (pathPart as NSString).pathExtension.lowercased()
        return ext.isEmpty ? "Unknown" : ext
    }
}
