import BackgroundTasks
import Foundation

/// Manages BGTaskScheduler registration and scheduling for periodic feed refresh.
/// Invariant: register() must be called once at app launch before the app finishes launching.
final class BackgroundRefreshManager: Sendable {
    static let taskIdentifier = "com.simpod.feedRefresh"

    private let feedEngine: FeedEngine

    init(feedEngine: FeedEngine) {
        self.feedEngine = feedEngine
    }

    /// Register the background task with the system. Call once at app launch.
    func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [self] task in
            self.handleRefresh(task: task as! BGAppRefreshTask)
        }
    }

    /// Schedule the next background refresh (earliest begin: 15 minutes from now).
    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[BackgroundRefresh] Failed to schedule: \(error)")
        }
    }

    // MARK: - Private

    private func handleRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh before consuming this task slot.
        scheduleRefresh()

        // BGAppRefreshTask is not Sendable — rebind to opt out of sending check.
        // Safe because this method completes synchronously; `task` param goes out of scope.
        nonisolated(unsafe) let task = task

        let engine = self.feedEngine
        let refreshTask = Task { await engine.refreshAll() }

        task.expirationHandler = { refreshTask.cancel() }

        Task {
            _ = await refreshTask.value
            task.setTaskCompleted(success: true)
        }
    }
}
