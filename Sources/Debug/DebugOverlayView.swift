#if DEBUG
import SwiftUI

/// Dedicated debug overlay that replaces the entire UI when launched with
/// `SIMPOD_DEBUG_PANEL=1`. Avoids List/lazy-rendering issues that hide
/// off-screen elements from the XCUITest accessibility tree.
///
/// Compiled only in DEBUG. Released binaries do not contain this view.
struct DebugOverlayView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(FeedEngine.self) private var feedEngine

    @State private var debugDBPodcastCount: Int = 0
    @State private var debugDBEpisodeCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Simpod Debug Panel")
                .font(.headline)

            HStack(spacing: 8) {
                Button("Trigger Refresh") {
                    Task {
                        // Wait up to 2s for the podcast observation to settle so
                        // refreshAll's snapshot of dataStore.podcasts is non-empty.
                        var attempts = 0
                        while dataStore.podcasts.isEmpty && attempts < 20 {
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            attempts += 1
                        }
                        _ = await feedEngine.refreshAll()
                    }
                }
                .accessibilityIdentifier("debug.triggerRefresh")
                .buttonStyle(.bordered)

                Button("Reset") {
                    dataStore.resetDebugCounters()
                }
                .accessibilityIdentifier("debug.resetCounters")
                .buttonStyle(.bordered)

                Button("DB Counts") {
                    debugDBPodcastCount = (try? dataStore.debugPodcastCount()) ?? -1
                    debugDBEpisodeCount = (try? dataStore.debugInboxEpisodeCount()) ?? -1
                }
                .accessibilityIdentifier("debug.refreshDBCounts")
                .buttonStyle(.bordered)
            }

            Group {
                row("inboxSinkCount", "\(dataStore.inboxSinkCount)", id: "debug.inboxSinkCount")
                row("saveRefreshCount", "\(dataStore.saveRefreshCount)", id: "debug.saveRefreshCount")
                row("lastInboxPayload", "\(dataStore.lastInboxPayloadCount)", id: "debug.lastInboxPayload")
                row("inbox.count", "\(dataStore.inbox.count)", id: "debug.inboxArrayCount")
                row("refreshTotal", "\(feedEngine.refreshTotal)", id: "debug.refreshTotal")
                row("refreshCompleted", "\(feedEngine.refreshCompleted)", id: "debug.refreshCompleted")
                row("isRefreshing", feedEngine.isRefreshing ? "true" : "false", id: "debug.isRefreshing")
                row("refreshSnapshotCount", "\(feedEngine.debugRefreshSnapshotCount)", id: "debug.refreshSnapshotCount")
                row("refreshCompletions", "\(feedEngine.debugRefreshCompletions)", id: "debug.refreshCompletions")
                row("dbPodcastCount", "\(debugDBPodcastCount)", id: "debug.dbPodcastCount")
                row("dbEpisodeCount", "\(debugDBEpisodeCount)", id: "debug.dbEpisodeCount")
            }
            .font(.system(.body, design: .monospaced))

            // Inbox badge integer is exposed by the tab bar, but we also expose
            // the underlying inboxCount value here for redundancy.
            row("inboxCount (badge)", "\(dataStore.inboxCount)", id: "debug.inboxCount")

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemBackground))
    }

    private func row(_ label: String, _ value: String, id: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .accessibilityIdentifier(id)
        }
    }
}
#endif
