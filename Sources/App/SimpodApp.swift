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
            } else if let loadError {
                Text("Failed to start: \(loadError)")
                    .foregroundStyle(.red)
                    .onAppear { logger.error("Load error: \(loadError)") }
            } else {
                ProgressView("Loading...")
                    .task {
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
