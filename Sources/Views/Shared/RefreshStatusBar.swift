import SwiftUI

struct RefreshStatusBar: View {
    @Environment(FeedEngine.self) private var feedEngine

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Refreshing \(feedEngine.refreshCompleted)/\(feedEngine.refreshTotal)")
                .font(.caption)
            if !feedEngine.refreshingFeedTitle.isEmpty {
                Text("· \(feedEngine.refreshingFeedTitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
