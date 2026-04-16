import SwiftUI

/// Simple view to subscribe to a podcast by entering its RSS feed URL.
struct AddPodcastView: View {
    @Environment(FeedEngine.self) private var feedEngine
    @Environment(\.dismiss) private var dismiss

    @State private var feedURL = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Feed URL") {
                TextField("https://example.com/feed.xml", text: $feedURL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await subscribe() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Subscribe")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(feedURL.isEmpty || isLoading)
            }
        }
        .navigationTitle("Add Podcast")
    }

    private func subscribe() async {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await feedEngine.subscribe(feedURL: feedURL)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
