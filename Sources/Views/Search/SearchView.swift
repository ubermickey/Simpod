import SwiftUI

struct SearchView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(FeedEngine.self) private var feedEngine

    @State private var query = ""
    @State private var localPodcasts: [Podcast] = []
    @State private var localEpisodes: [EpisodeWithPodcast] = []
    @State private var remoteResults: [PodcastSearchResult] = []
    @State private var isSearchingRemote = false
    @State private var errorMessage: String?
    @State private var searchService = PodcastSearchService()

    var body: some View {
        NavigationStack {
            List {
                if !localPodcasts.isEmpty {
                    Section("Subscribed Shows") {
                        ForEach(localPodcasts) { podcast in
                            HStack(spacing: 12) {
                                AsyncImage(url: podcast.artworkURL.flatMap(URL.init)) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(podcast.title)
                                        .font(.body)
                                        .lineLimit(1)
                                    if !podcast.author.isEmpty {
                                        Text(podcast.author)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }

                if !localEpisodes.isEmpty {
                    Section("Episodes") {
                        ForEach(localEpisodes, id: \.episode.id) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.podcast.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(item.episode.title)
                                    .font(.body)
                                    .lineLimit(2)
                                Text(item.episode.publishedDate, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        Button {
                            Task { await searchOnline() }
                        } label: {
                            HStack {
                                Spacer()
                                if isSearchingRemote {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                }
                                Text("Search Online")
                                Spacer()
                            }
                        }
                        .disabled(isSearchingRemote)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if !remoteResults.isEmpty {
                    Section("Online Results") {
                        ForEach(remoteResults) { result in
                            SearchResultRow(result: result) {
                                await subscribe(to: result)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Search podcasts & episodes")
            .task(id: query) {
                await performLocalSearch()
            }
        }
    }

    private func performLocalSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            localPodcasts = []
            localEpisodes = []
            return
        }

        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        do {
            let results = try dataStore.searchLocal(query: trimmed)
            localPodcasts = results.podcasts
            localEpisodes = results.episodes
        } catch {
            localPodcasts = []
            localEpisodes = []
        }
    }

    private func searchOnline() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearchingRemote = true
        errorMessage = nil

        do {
            remoteResults = try await searchService.search(query: trimmed)
        } catch is CancellationError {
            // cancelled
        } catch {
            errorMessage = error.localizedDescription
        }

        isSearchingRemote = false
    }

    private func subscribe(to result: PodcastSearchResult) async {
        do {
            _ = try await feedEngine.subscribe(feedURL: result.feedURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SearchResultRow: View {
    let result: PodcastSearchResult
    let onSubscribe: () async -> Void

    @State private var isSubscribing = false

    var body: some View {
        Button {
            guard !isSubscribing else { return }
            isSubscribing = true
            Task {
                await onSubscribe()
                isSubscribing = false
            }
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: result.artworkURL.flatMap(URL.init)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.quaternary)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.body)
                        .lineLimit(2)
                    Text(result.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSubscribing {
                    ProgressView()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
