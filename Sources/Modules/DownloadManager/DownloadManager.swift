import Foundation
import Observation

/// Manages episode audio downloads using URLSession.
/// Stores downloaded files as {episodeID}.mp3 in a Downloads/ subdirectory
/// of the app's documents directory.
@Observable
final class DownloadManager: @unchecked Sendable {
    // MARK: - Observable State

    /// Active downloads mapped by episode ID to progress (0.0 - 1.0).
    var activeDownloads: [UUID: Double] = [:]

    // MARK: - Private State

    private let session: URLSession
    private var tasks: [UUID: URLSessionDownloadTask] = [:]
    private var continuations: [UUID: CheckedContinuation<URL, any Error>] = [:]
    private let delegateHandler: DownloadDelegate

    // MARK: - Directories

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static var downloadsDirectory: URL {
        documentsDirectory.appendingPathComponent("Downloads", isDirectory: true)
    }

    // MARK: - Init

    init() {
        let delegate = DownloadDelegate()
        self.delegateHandler = delegate
        self.session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        // Ensure Downloads/ directory exists
        try? FileManager.default.createDirectory(
            at: Self.downloadsDirectory,
            withIntermediateDirectories: true
        )

        // Wire delegate callbacks back to this manager
        delegate.onProgress = { [weak self] episodeID, progress in
            Task { @MainActor [weak self] in
                self?.activeDownloads[episodeID] = progress
            }
        }
        delegate.onComplete = { [weak self] episodeID, tempURL, error in
            self?.handleDownloadComplete(episodeID: episodeID, tempURL: tempURL, error: error)
        }
    }

    // MARK: - Public API

    /// Download the audio file for an episode and return the local file URL.
    func download(episode: Episode) async throws -> URL {
        guard let remoteURL = URL(string: episode.audioURL) else {
            throw DownloadError.invalidURL(episode.audioURL)
        }

        let destination = localFileURL(for: episode.id)

        // If already downloaded, return immediately
        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }

        // If already downloading, wait for the existing download
        if tasks[episode.id] != nil {
            return try await withCheckedThrowingContinuation { continuation in
                continuations[episode.id] = continuation
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuations[episode.id] = continuation

            let task = session.downloadTask(with: remoteURL)
            task.taskDescription = episode.id.uuidString
            self.tasks[episode.id] = task
            self.activeDownloads[episode.id] = 0.0

            task.resume()
        }
    }

    /// Cancel an active download for the given episode ID.
    func cancelDownload(episodeID: UUID) {
        tasks[episodeID]?.cancel()
        tasks.removeValue(forKey: episodeID)
        activeDownloads.removeValue(forKey: episodeID)

        if let continuation = continuations.removeValue(forKey: episodeID) {
            continuation.resume(throwing: DownloadError.cancelled)
        }
    }

    /// Delete the locally downloaded file for an episode.
    func deleteDownload(episode: Episode) throws {
        let fileURL = localFileURL(for: episode.id)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Check whether a local file exists for the given episode.
    func localFileExists(episode: Episode) -> Bool {
        FileManager.default.fileExists(atPath: localFileURL(for: episode.id).path)
    }

    /// Total bytes used by all downloaded files in the Downloads/ directory.
    var totalDownloadedBytes: Int64 {
        let fm = FileManager.default
        let dir = Self.downloadsDirectory

        guard let enumerator = fm.enumerator(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    /// Delete all downloaded files.
    func clearAllDownloads() throws {
        let fm = FileManager.default
        let dir = Self.downloadsDirectory

        if fm.fileExists(atPath: dir.path) {
            try fm.removeItem(at: dir)
        }
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // MARK: - Private Helpers

    private func localFileURL(for episodeID: UUID) -> URL {
        Self.downloadsDirectory.appendingPathComponent("\(episodeID.uuidString).mp3")
    }

    private func handleDownloadComplete(episodeID: UUID, tempURL: URL?, error: (any Error)?) {
        defer {
            tasks.removeValue(forKey: episodeID)
            Task { @MainActor [weak self] in
                self?.activeDownloads.removeValue(forKey: episodeID)
            }
        }

        guard let continuation = continuations.removeValue(forKey: episodeID) else { return }

        if let error {
            continuation.resume(throwing: error)
            return
        }

        guard let tempURL else {
            continuation.resume(throwing: DownloadError.noFileReceived)
            return
        }

        let destination = localFileURL(for: episodeID)

        do {
            // Remove any existing file at destination
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: tempURL, to: destination)
            continuation.resume(returning: destination)
        } catch {
            continuation.resume(throwing: error)
        }
    }
}

// MARK: - Download Delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    var onProgress: ((UUID, Double) -> Void)?
    var onComplete: ((UUID, URL?, (any Error)?) -> Void)?

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let episodeID = episodeID(from: downloadTask) else { return }
        onComplete?(episodeID, location, nil)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let episodeID = episodeID(from: downloadTask) else { return }
        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0.0
        onProgress?(episodeID, progress)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        guard let error,
              let downloadTask = task as? URLSessionDownloadTask,
              let episodeID = episodeID(from: downloadTask) else { return }
        onComplete?(episodeID, nil, error)
    }

    private func episodeID(from task: URLSessionDownloadTask) -> UUID? {
        guard let description = task.taskDescription else { return nil }
        return UUID(uuidString: description)
    }
}

// MARK: - Errors

enum DownloadError: LocalizedError {
    case invalidURL(String)
    case cancelled
    case noFileReceived

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): "Invalid download URL: \(url)"
        case .cancelled: "Download was cancelled"
        case .noFileReceived: "No file received from download"
        }
    }
}
