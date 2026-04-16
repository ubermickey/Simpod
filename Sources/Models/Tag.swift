import Foundation
import GRDB

/// User-defined tag for organizing podcasts and episodes.
struct Tag: Identifiable, Codable, Hashable, Sendable, FetchableRecord, PersistableRecord {
    var id: UUID
    var name: String
    var color: String

    init(id: UUID = UUID(), name: String, color: String = "#007AFF") {
        self.id = id
        self.name = name
        self.color = color
    }
}

/// Join table: many-to-many between episodes and tags.
struct EpisodeTag: Codable, Sendable, FetchableRecord, PersistableRecord {
    var episodeID: UUID
    var tagID: UUID
}

/// Join table: many-to-many between podcasts and tags.
struct PodcastTag: Codable, Sendable, FetchableRecord, PersistableRecord {
    var podcastID: UUID
    var tagID: UUID
}
