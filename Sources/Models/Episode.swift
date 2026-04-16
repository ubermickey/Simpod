import Foundation
import GRDB

/// A single podcast episode.
struct Episode: Identifiable, Codable, Sendable, FetchableRecord, PersistableRecord {
    var id: UUID
    var podcastID: UUID
    var guid: String
    var title: String
    var audioURL: String
    var localFilePath: String?
    var duration: TimeInterval
    var playbackPosition: TimeInterval
    var publishedDate: Date
    var episodeDescription: String
    var status: EpisodeStatus
    var downloadProgress: Double
    var lastModified: Date

    static let podcast = belongsTo(Podcast.self)

    init(
        id: UUID = UUID(),
        podcastID: UUID,
        guid: String = "",
        title: String,
        audioURL: String,
        localFilePath: String? = nil,
        duration: TimeInterval = 0,
        playbackPosition: TimeInterval = 0,
        publishedDate: Date = .now,
        episodeDescription: String = "",
        status: EpisodeStatus = .inbox,
        downloadProgress: Double = 0,
        lastModified: Date = .now
    ) {
        self.id = id
        self.podcastID = podcastID
        self.guid = guid
        self.title = title
        self.audioURL = audioURL
        self.localFilePath = localFilePath
        self.duration = duration
        self.playbackPosition = playbackPosition
        self.publishedDate = publishedDate
        self.episodeDescription = episodeDescription
        self.status = status
        self.downloadProgress = downloadProgress
        self.lastModified = lastModified
    }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let podcastID = Column(CodingKeys.podcastID)
        static let guid = Column(CodingKeys.guid)
        static let status = Column(CodingKeys.status)
        static let playbackPosition = Column(CodingKeys.playbackPosition)
        static let publishedDate = Column(CodingKeys.publishedDate)
        static let lastModified = Column(CodingKeys.lastModified)
    }
}

enum EpisodeStatus: String, Codable, Sendable {
    case inbox
    case queued
    case skipped
    case playing
    case played
}
