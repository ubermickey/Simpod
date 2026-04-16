import SwiftUI

struct SearchView: View {
    @Environment(FeedEngine.self) private var feedEngine
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [PodcastSearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchService = PodcastSearchService()

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if !isLoading && results.isEmpty && !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                }

                ForEach(results) { result in
                    SearchResultRow(result: result) {
                        await subscribe(to: result)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Search podcasts")
            .task(id: query) {
                await performSearch()
            }
        }
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            errorMessage = nil
            return
        }

        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }

        isLoading = true
        errorMessage = nil

        do {
            results = try await searchService.search(query: trimmed)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
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

#Preview {
    SearchView()
}
