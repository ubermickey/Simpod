import Foundation

struct PodcastSearchResult: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let author: String
    let feedURL: String
    let artworkURL: String?
}

@Observable
final class PodcastSearchService: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String) async throws -> [PodcastSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return try await searchApple(query: trimmed)
    }

    private func searchApple(query: String) async throws -> [PodcastSearchResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&media=podcast&limit=25")
        else { return [] }

        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(AppleSearchResponse.self, from: data)
        return response.results.compactMap { item in
            guard let feedURL = item.feedUrl, !feedURL.isEmpty else { return nil }
            return PodcastSearchResult(
                id: String(item.trackId),
                title: item.trackName,
                author: item.artistName,
                feedURL: feedURL,
                artworkURL: item.artworkUrl600
            )
        }
    }
}

private struct AppleSearchResponse: Codable, Sendable {
    let resultCount: Int
    let results: [AppleSearchItem]
}

private struct AppleSearchItem: Codable, Sendable {
    let trackId: Int
    let trackName: String
    let artistName: String
    let feedUrl: String?
    let artworkUrl600: String?
}
