import SwiftUI
import UIKit
import os

private let logger = Logger(subsystem: "com.simpod", category: "App")

@main
struct SimpodApp: App {
    @State private var container: AppContainer?
    @State private var loadError: String?

    @ViewBuilder
    private func rootView(container: AppContainer) -> some View {
        #if DEBUG
        if ProcessInfo.processInfo.environment["SIMPOD_DEBUG_PANEL"] == "1" {
            DebugOverlayView()
        } else {
            ContentView()
        }
        #else
        ContentView()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                rootView(container: container)
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
                        #if DEBUG
                        if DataStore.suppressInitialAutoRefresh { return }
                        #endif
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

                        // Debug-only test launch hooks. In RELEASE the entire
                        // block is stripped — see plan §B hard invariant.
                        #if DEBUG
                        let env = ProcessInfo.processInfo.environment
                        if env["SIMPOD_SUPPRESS_AUTOREFRESH"] == "1" {
                            DataStore.suppressInitialAutoRefresh = true
                        }
                        if env["SIMPOD_STUB_NETWORK"] == "1" {
                            URLProtocol.registerClass(StubFeedURLProtocol.self)
                            logger.info("StubFeedURLProtocol registered")
                        }
                        #endif

                        logger.info("Starting AppContainer init")
                        do {
                            let c = try AppContainer()
                            logger.info("AppContainer created OK")
                            c.backgroundRefresh.register()
                            logger.info("BGTask registered, setting container")

                            #if DEBUG
                            if env["SIMPOD_WIPE_ON_LAUNCH"] == "1" {
                                try c.dataStore.wipeAll()
                                logger.info("DataStore wiped (DEBUG hook)")
                            }
                            if let raw = env["SIMPOD_SEED_PODCAST_COUNT"],
                               let n = Int(raw), n > 0 {
                                try c.dataStore.seedPodcasts(count: n)
                                logger.info("Seeded \(n) stub podcasts (DEBUG hook)")
                            }
                            #endif

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
