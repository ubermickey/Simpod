import SwiftUI

/// Read-only detail sheet showing full metadata, file details, and show notes
/// for a single episode. Presented from the options drawer's "Info" action.
struct EpisodeInfoView: View {
    let episode: Episode
    let podcastTitle: String

    var body: some View {
        List {
            episodeDetailsSection
            audioFileSection
            showNotesSection
        }
        .navigationTitle("Episode Info")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var episodeDetailsSection: some View {
        Section("Episode Details") {
            infoRow("Podcast", value: podcastTitle)
            infoRow("Title", value: episode.title)
            infoRow("Published", value: episode.publishedDate.formatted(date: .abbreviated, time: .omitted))
            infoRow("Duration", value: formatDuration(episode.duration))
            infoRow("Progress", value: playbackProgressLabel)
            infoRow("Status", value: statusLabel(for: episode))
            infoRow("Last Updated", value: episode.lastModified.formatted(date: .abbreviated, time: .omitted))
            infoRowWithHelp("Feed ID", value: episode.guid, help: "Unique identifier assigned by the podcast creator")
        }
    }

    private var audioFileSection: some View {
        Section("Audio File") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Stream Link")
                    .foregroundStyle(.secondary)
                Text(episode.audioURL)
                    .font(.caption)
                    .monospaced()
                    .lineLimit(2)
                Text("Direct link to the audio file on the podcast's server")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            infoRow("Download Status", value: downloadStatusLabel)
            if let localPath = episode.localFilePath {
                infoRow("File Size", value: fileSize(at: localPath))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Saved File")
                        .foregroundStyle(.secondary)
                    Text(localPath)
                        .font(.caption)
                        .monospaced()
                        .lineLimit(2)
                    Text("Location of the downloaded file on your device")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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
            } else if let attr = showNotesAttributedString {
                Text(attr)
            } else {
                let stripped = strippedHTML(episode.episodeDescription)
                if stripped.isEmpty {
                    Text("Show notes may contain formatting errors.")
                        .foregroundStyle(.secondary)
                } else {
                    Text(stripped)
                }
            }
        }
    }

    // MARK: - Helpers

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }

    private func infoRowWithHelp(_ label: String, value: String, help: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text(value).multilineTextAlignment(.trailing)
            }
            Text(help).font(.caption2).foregroundStyle(.tertiary)
        }
    }

    // MARK: - Computed Labels

    private var playbackProgressLabel: String {
        if episode.playbackPosition == 0 {
            return "Not started"
        }
        return "\(formatDuration(episode.playbackPosition)) of \(formatDuration(episode.duration)) listened"
    }

    private func statusLabel(for episode: Episode) -> String {
        switch episode.status {
        case .inbox: return "In your inbox"
        case .queued: return "Queued"
        case .playing: return "Now playing"
        case .played: return "Listened"
        case .skipped: return "Archived"
        case .hidden:
            if let until = episode.hiddenUntil {
                let hours = max(1, Int(until.timeIntervalSinceNow / 3600))
                return "Hidden (returns in \(hours)h)"
            }
            return "Hidden"
        }
    }

    private var downloadStatusLabel: String {
        if episode.localFilePath != nil {
            return "Downloaded"
        }
        if episode.downloadProgress > 0 {
            return "Downloading (\(Int(episode.downloadProgress * 100))%)"
        }
        return "Not downloaded"
    }

    // MARK: - File Helpers

    private func fileSize(at path: String) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let bytes = attrs[.size] as? Int64 else {
            return "Unable to read"
        }
        let mb = Double(bytes) / (1024 * 1024)
        return String(format: "%.1f MB", mb)
    }

    // MARK: - Show Notes Rendering

    private var showNotesAttributedString: AttributedString? {
        guard let data = episode.episodeDescription.data(using: .utf8) else { return nil }
        guard let nsAttr = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        ) else { return nil }
        return try? AttributedString(nsAttr, including: \.uiKit)
    }

    private func strippedHTML(_ html: String) -> String {
        var result = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Duration / Format

    func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return "\(hours)h \(minutes)m"
        }
        return "\(totalMinutes)m"
    }

    private func audioFormat(from urlString: String) -> String {
        let pathPart = urlString.components(separatedBy: "?").first ?? urlString
        let ext = (pathPart as NSString).pathExtension.lowercased()
        return ext.isEmpty ? "Unknown" : ext
    }
}
