import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(AudioEngine.self) private var audioEngine
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(FeedEngine.self) private var feedEngine

    @State private var showClearConfirmation = false
    @State private var showFileImporter = false
    @State private var importResult: String?
    @State private var showImportResult = false
    @State private var isImporting = false

    /// Playback speed options from 0.5x to 3.0x in 0.1 increments.
    private let speedOptions: [Float] = stride(from: 0.5, through: 3.0, by: 0.1).map { Float($0) }

    var body: some View {
        NavigationStack {
            List {
                playbackSection
                storageSection
                subscriptionsSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Sections

    private var playbackSection: some View {
        Section("Playback") {
            @Bindable var engine = audioEngine
            Picker("Playback Speed", selection: $engine.playbackRate) {
                ForEach(speedOptions, id: \.self) { speed in
                    Text(formatSpeed(speed))
                        .tag(speed)
                }
            }
            .onChange(of: audioEngine.playbackRate) { _, newValue in
                audioEngine.setSpeed(newValue)
            }
        }
    }

    private var storageSection: some View {
        Section("Storage") {
            HStack {
                Text("Downloaded")
                Spacer()
                Text(formatBytes(downloadManager.totalDownloadedBytes))
                    .foregroundStyle(.secondary)
            }

            Button("Clear All Downloads", role: .destructive) {
                showClearConfirmation = true
            }
            .confirmationDialog(
                "Clear All Downloads?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    try? downloadManager.clearAllDownloads()
                }
            } message: {
                Text("This will remove all downloaded episodes from your device. You can re-download them later.")
            }
        }
    }

    private var subscriptionsSection: some View {
        Section("Subscriptions") {
            Button {
                showFileImporter = true
            } label: {
                Label(isImporting ? "Importing..." : "Import OPML",
                      systemImage: "square.and.arrow.down")
            }
            .disabled(isImporting)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.xml, UTType(filenameExtension: "opml") ?? .xml]
            ) { result in
                Task { await handleOPMLImport(result) }
            }

            if dataStore.podcasts.isEmpty {
                Text("No subscriptions")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(dataStore.podcasts) { podcast in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(podcast.title)
                            if !podcast.author.isEmpty {
                                Text(podcast.author)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    deletePodcasts(at: indexSet)
                }
            }
        }
        .alert("OPML Import", isPresented: $showImportResult) {
            Button("OK") { }
        } message: {
            Text(importResult ?? "")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            Text("Simpod v0.1.0")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func handleOPMLImport(_ result: Result<URL, any Error>) async {
        isImporting = true
        defer { isImporting = false }

        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else {
                importResult = "Permission denied to access file."
                showImportResult = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            let (subscribed, skipped, failed) = try await feedEngine.importOPML(data: data)

            var parts: [String] = []
            if subscribed > 0 { parts.append("\(subscribed) imported") }
            if skipped > 0 { parts.append("\(skipped) already subscribed") }
            if failed > 0 { parts.append("\(failed) failed") }
            importResult = parts.isEmpty ? "No feeds found." : parts.joined(separator: ", ")
        } catch {
            importResult = error.localizedDescription
        }
        showImportResult = true
    }

    private func deletePodcasts(at offsets: IndexSet) {
        for index in offsets {
            let podcast = dataStore.podcasts[index]
            try? dataStore.deletePodcast(podcast)
        }
    }

    private func formatSpeed(_ speed: Float) -> String {
        if speed == Float(Int(speed)) {
            return String(format: "%.1fx", speed)
        }
        return String(format: "%.1fx", speed)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    SettingsView()
}
