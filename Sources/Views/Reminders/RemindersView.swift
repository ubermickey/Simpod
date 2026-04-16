import SwiftUI

/// Displays episodes that have been hidden ("snoozed") and will return to the
/// inbox when their 24-hour reminder window expires.
struct RemindersView: View {
    @Environment(DataStore.self) private var dataStore

    var body: some View {
        NavigationStack {
            List {
                if dataStore.reminders.isEmpty {
                    ContentUnavailableView(
                        "No Reminders",
                        systemImage: "clock",
                        description: Text("Hidden episodes will appear here for 24 hours.")
                    )
                } else {
                    ForEach(dataStore.reminders, id: \.episode.id) { item in
                        reminderRow(for: item)
                            .swipeActions(edge: .trailing) {
                                Button {
                                    try? dataStore.unhideEpisode(item.episode.id)
                                } label: {
                                    Label("Unhide Now", systemImage: "tray.and.arrow.down")
                                }
                                .tint(.green)
                            }
                    }
                }
            }
            .navigationTitle("Reminders")
        }
    }

    // MARK: - Row

    private func reminderRow(for item: EpisodeWithPodcast) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.podcast.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(item.episode.title)
                .font(.headline)
                .lineLimit(2)
            Text(timeRemainingLabel(for: item.episode))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Display Contract

    /// Returns a human-readable label for how long until the episode returns to inbox.
    ///
    /// Contract:
    ///   - >= 1 hour remaining  → "Returns in Xh"
    ///   - > 0 but < 1 hour     → "Returns in <1h"
    ///   - <= 0 (defensive)     → "Returning..."
    func timeRemainingLabel(for episode: Episode) -> String {
        guard let hiddenUntil = episode.hiddenUntil else { return "Returning..." }
        let remaining = hiddenUntil.timeIntervalSinceNow
        let hours = Int(floor(remaining / 3600))
        if hours >= 1 {
            return "Returns in \(hours)h"
        } else if remaining > 0 {
            return "Returns in <1h"
        } else {
            return "Returning..."
        }
    }
}
