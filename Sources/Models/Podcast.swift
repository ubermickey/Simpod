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
    var httpETag: String?
    var httpLastModified: String?
    var feedBodyHash: String?
    var cloudKitSystemFields: Data?

    static let episodes = hasMany(Episode.self)

    init(
        id: UUID = UUID(),
        feedURL: String,
        title: String,
        author: String = "",
        artworkURL: String? = nil,
        podcastDescription: String = "",
        lastRefreshed: Date? = nil,
        lastModified: Date = .now,
        httpETag: String? = nil,
        httpLastModified: String? = nil,
        feedBodyHash: String? = nil,
        cloudKitSystemFields: Data? = nil
    ) {
        self.id = id
        self.feedURL = feedURL
        self.title = title
        self.author = author
        self.artworkURL = artworkURL
        self.podcastDescription = podcastDescription
        self.lastRefreshed = lastRefreshed
        self.lastModified = lastModified
        self.httpETag = httpETag
        self.httpLastModified = httpLastModified
        self.feedBodyHash = feedBodyHash
        self.cloudKitSystemFields = cloudKitSystemFields
    }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let feedURL = Column(CodingKeys.feedURL)
        static let title = Column(CodingKeys.title)
        static let lastRefreshed = Column(CodingKeys.lastRefreshed)
        static let lastModified = Column(CodingKeys.lastModified)
        static let httpETag = Column(CodingKeys.httpETag)
        static let httpLastModified = Column(CodingKeys.httpLastModified)
        static let feedBodyHash = Column(CodingKeys.feedBodyHash)
        static let cloudKitSystemFields = Column(CodingKeys.cloudKitSystemFields)
    }
}

extension Podcast {
    /// Returns a copy with `httpETag` / `httpLastModified` updated only when
    /// the server actually sent a new value. Preserves stored validators
    /// when headers are absent (Cloudflare ETag-stripping defense).
    func merging(etag newETag: String?, lastModified newLastModified: String?) -> Podcast {
        var copy = self
        copy.httpETag = newETag ?? self.httpETag
        copy.httpLastModified = newLastModified ?? self.httpLastModified
        return copy
    }

    /// Returns a copy with parse-derived metadata fields replaced by those of
    /// `parsed`. Identity, validators, and timestamps are preserved.
    func applyingParsed(_ parsed: Podcast) -> Podcast {
        var copy = self
        copy.title = parsed.title
        copy.author = parsed.author
        copy.artworkURL = parsed.artworkURL
        copy.podcastDescription = parsed.podcastDescription
        return copy
    }

    /// True iff parse-derived metadata is byte-equal between self and other.
    /// Excludes identity, validators, hash, and timestamps by design — see
    /// plan §"`contentEquals(_:)` Contract".
    func contentEquals(_ other: Podcast) -> Bool {
        title == other.title
            && author == other.author
            && artworkURL == other.artworkURL
            && podcastDescription == other.podcastDescription
    }

    /// True iff every field that `saveRefreshResult` could write is equal.
    /// Used to short-circuit the refresh write transaction.
    func refreshFieldsEqual(_ other: Podcast) -> Bool {
        feedBodyHash == other.feedBodyHash
            && httpETag == other.httpETag
            && httpLastModified == other.httpLastModified
            && title == other.title
            && author == other.author
            && podcastDescription == other.podcastDescription
            && artworkURL == other.artworkURL
            && lastModified == other.lastModified
    }
}
