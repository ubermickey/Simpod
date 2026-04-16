import Foundation
import GRDB

/// A podcast feed subscription.
struct Podcast: Identifiable, Codable, Sendable, FetchableRecord, PersistableRecord {
    var id: UUID
    var feedURL: String
    var title: String
    var author: String
    var artworkURL: String?
    var podcastDescription: String
    var lastRefreshed: Date?
    var lastModified: Date

    static let episodes = hasMany(Episode.self)

    init(
        id: UUID = UUID(),
        feedURL: String,
        title: String,
        author: String = "",
        artworkURL: String? = nil,
        podcastDescription: String = "",
        lastRefreshed: Date? = nil,
        lastModified: Date = .now
    ) {
        self.id = id
        self.feedURL = feedURL
        self.title = title
        self.author = author
        self.artworkURL = artworkURL
        self.podcastDescription = podcastDescription
        self.lastRefreshed = lastRefreshed
        self.lastModified = lastModified
    }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let feedURL = Column(CodingKeys.feedURL)
        static let title = Column(CodingKeys.title)
        static let lastRefreshed = Column(CodingKeys.lastRefreshed)
        static let lastModified = Column(CodingKeys.lastModified)
    }
}
