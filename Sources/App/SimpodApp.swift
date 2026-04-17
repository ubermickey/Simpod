import SwiftUI
import UIKit
import os

private let logger = Logger(subsystem: "com.simpod", category: "App")

@main
struct SimpodApp: App {
    @State private var container: AppContainer?
    @State private var loadError: String?

    var body: some Scene {
        WindowGroup {
            if let container {
                ContentView()
                    .environment(container.dataStore)
                    .environment(container.feedEngine)
                    .environment(container.audioEngine)
                    .environment(container.downloadManager)
                    .onReceive(
                        NotificationCenter.default.publisher(
                            for: UIApplication.didEnterBackgroundNotification
                        )
                    ) { _ in
                        container.backgroundRefresh.scheduleRefresh()
                    }
                    .onAppear {
                        logger.info("ContentView appeared")
                        #if DEBUG
                        UIApplication.shared.isIdleTimerDisabled = true
                        #endif
                    }
                    .task {
                        guard !container.dataStore.podcasts.isEmpty else { return }
                        _ = await container.feedEngine.refreshAll()
                    }
            } else if let loadError {
                Text("Failed to start: \(loadError)")
                    .foregroundStyle(.red)
                    .onAppear { logger.error("Load error: \(loadError)") }
            } else {
                ProgressView("Loading...")
                    .task {
                        if let breadcrumb = UserDefaults.standard.string(forKey: "com.simpod.crashBreadcrumb") {
                            logger.warning("Previous run interrupted during feed refresh: \(breadcrumb, privacy: .public)")
                            UserDefaults.standard.removeObject(forKey: "com.simpod.crashBreadcrumb")
                        }
                        logger.info("Starting AppContainer init")
                        do {
                            let c = try AppContainer()
                            logger.info("AppContainer created OK")
                            c.backgroundRefresh.register()
                            logger.info("BGTask registered, setting container")
                            container = c
                        } catch {
                            logger.error("AppContainer failed: \(error)")
                            loadError = error.localizedDescription
                        }
                    }
            }
        }
    }
}
