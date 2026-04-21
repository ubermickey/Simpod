import Foundation
import GRDB

/// An episode's position in the playback queue.
struct QueueItem: Identifiable, Codable, Sendable, FetchableRecord, PersistableRecord {
    var id: UUID
    var episodeID: UUID
    var order: Int
    var addedDate: Date
    var lastModified: Date
    var cloudKitSystemFields: Data?

    static let episode = belongsTo(Episode.self)

    init(
        id: UUID = UUID(),
        episodeID: UUID,
        order: Int,
        addedDate: Date = .now,
        lastModified: Date = .now,
        cloudKitSystemFields: Data? = nil
    ) {
        self.id = id
        self.episodeID = episodeID
        self.order = order
        self.addedDate = addedDate
        self.lastModified = lastModified
        self.cloudKitSystemFields = cloudKitSystemFields
    }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let episodeID = Column(CodingKeys.episodeID)
        static let order = Column(CodingKeys.order)
        static let lastModified = Column(CodingKeys.lastModified)
        static let cloudKitSystemFields = Column(CodingKeys.cloudKitSystemFields)
    }
}
