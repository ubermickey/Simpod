import XCTest

/// Validates the inbox/queue debounce change introduced in commit `a1433c4`.
/// See plan: ~/.claude/plans/floating-beaming-dahl.md
final class RefreshDebounceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Stub harness self-check (must run first)

    /// Plan §F.6 — independent check that the URLProtocol stub is alive.
    /// If this fails, every other result in this file is meaningless.
    func test_stubHarness_isAlive() throws {
        let app = XCUIApplication()
        app.launchEnvironment = baseEnv(seedCount: 1, debounceMS: 50)
        app.launch()

        let triggerButton = app.buttons["debug.triggerRefresh"]
        XCTAssertTrue(triggerButton.waitForExistence(timeout: 30),
            "DebugOverlayView didn't render — env var not flowing or app failed to launch")

        let baselineCompletions = readInt(app, identifier: "debug.refreshCompletions")
        triggerButton.tap()

        try waitForRefreshAllCompletion(
            app: app,
            baselineCompletions: baselineCompletions,
            expectedSnapshotCount: 1
        )

        let saveCount = readInt(app, identifier: "debug.saveRefreshCount")
        XCTAssertEqual(saveCount, 1, "stub harness should have produced exactly 1 saveRefreshResult")

        app.buttons["debug.refreshDBCounts"].tap()
        let dbEpisodes = readInt(app, identifier: "debug.dbEpisodeCount")
        XCTAssertEqual(dbEpisodes, 5, "single stub feed should produce 5 episodes")
    }

    // MARK: - Coalescing: negative control vs active

    /// Plan §F + §G — paired runs prove the debounce window meaningfully
    /// coalesces sink deliveries, AND the trailing emission survives.
    func test_debounceCoalesces_negativeControlVsActive() throws {
        let (sink0, save0, payload0, badge0) = try runRefreshAndCapture(debounceMS: 0)
        let (sink50, save50, payload50, badge50) = try runRefreshAndCapture(debounceMS: 50)

        // §F.3 — both runs perform exactly 20 commits.
        XCTAssertEqual(save0, 20, "0ms run should commit exactly 20 times")
        XCTAssertEqual(save50, 20, "50ms run should commit exactly 20 times")

        // G-NEG-CONTROL — the 0ms run must produce a meaningful baseline.
        XCTAssertGreaterThanOrEqual(sink0, 18,
            "G-NEG-CONTROL: 0ms run delivered too few sinks (\(sink0)); test has no signal")

        // G-COALESCE — primary proof is relative; the hard ceiling is a
        // guardrail against total coalescing failure, not a tight prediction
        // (plan §G, revised after iPhone 15 Pro Max sim variance widened
        // observed sink50 to 7 in 1/2 G-FLAKE iterations on 2026-04-19).
        //
        // PRIMARY (relative):
        XCTAssertLessThanOrEqual(sink50, Int(ceil(Double(sink0) / 2.0)),
            "G-COALESCE primary: 50ms run (\(sink50)) must at least halve sink count vs 0ms run (\(sink0))")
        XCTAssertGreaterThanOrEqual(sink0 - sink50, 10,
            "G-COALESCE primary: absolute reduction (\(sink0 - sink50)) must be >= 10")
        // GUARDRAIL (absolute sanity ceiling — catches total coalescing failure):
        XCTAssertLessThanOrEqual(sink50, 8,
            "G-COALESCE guardrail: 50ms run delivered \(sink50) sinks (>8 sanity ceiling for sim)")

        // G-END-STATE — payload counts equal across runs (mechanism doesn't lose data).
        XCTAssertEqual(payload0, payload50,
            "G-END-STATE: trailing payload count must match across debounce windows")
        XCTAssertEqual(badge0, badge50,
            "G-END-STATE: badge value must match across debounce windows")
        XCTAssertEqual(payload0, 100, "expected exactly 20 feeds * 5 episodes")
    }

    // MARK: - Helpers

    private func baseEnv(seedCount: Int, debounceMS: Int) -> [String: String] {
        [
            "SIMPOD_STUB_NETWORK": "1",
            "SIMPOD_WIPE_ON_LAUNCH": "1",
            "SIMPOD_SEED_PODCAST_COUNT": "\(seedCount)",
            "SIMPOD_DEBUG_PANEL": "1",
            "SIMPOD_SUPPRESS_AUTOREFRESH": "1",
            "SIMPOD_DEBOUNCE_MS": "\(debounceMS)"
        ]
    }


    private func readInt(_ app: XCUIApplication, identifier: String) -> Int {
        let element = app.staticTexts[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: 5), "missing static text: \(identifier)")
        return Int(element.label) ?? -1
    }

    /// Wait for refreshAll() to complete one full run past its `isRefreshing`
    /// guard. Polling on `refreshTotal`/`refreshCompleted` is unreliable
    /// because their `defer` block resets them to 0 in the same Task that
    /// flips `isRefreshing` to false — there is no observable window in
    /// which all three reflect the completed run. Instead, we watch the
    /// monotonic `debugRefreshCompletions` counter, which is incremented
    /// just before refreshAll returns and never reset.
    private func waitForRefreshAllCompletion(
        app: XCUIApplication,
        baselineCompletions: Int,
        expectedSnapshotCount: Int
    ) throws {
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            let completions = readInt(app, identifier: "debug.refreshCompletions")
            let isRefreshing = app.staticTexts["debug.isRefreshing"].label
            if completions >= baselineCompletions + 1 && isRefreshing == "false" {
                let snapshotCount = readInt(app, identifier: "debug.refreshSnapshotCount")
                XCTAssertEqual(snapshotCount, expectedSnapshotCount,
                    "refreshAll snapshotted \(snapshotCount) podcasts; expected \(expectedSnapshotCount). " +
                    "If 0, the seed/observation race fired; if non-zero but wrong, the seed count is off.")
                return
            }
            usleep(250_000)
        }
        let finalSnapshot = readInt(app, identifier: "debug.refreshSnapshotCount")
        let finalCompletions = readInt(app, identifier: "debug.refreshCompletions")
        XCTFail("refreshAll did not complete within 30s. " +
            "completions=\(finalCompletions) (baseline=\(baselineCompletions)), " +
            "snapshotCount=\(finalSnapshot)")
    }

    /// Wait until the seeded podcast observation has propagated into
    /// `dataStore.podcasts`. Without this, `refreshAll()` snapshots an empty
    /// array and exits with refreshTotal == 0.
    private func waitForSeedToObserve(app: XCUIApplication, expectedCount: Int) throws {
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            app.buttons["debug.refreshDBCounts"].tap()
            let count = readInt(app, identifier: "debug.dbPodcastCount")
            if count == expectedCount { return }
            usleep(250_000)
        }
        XCTFail("seeded podcasts (\(expectedCount)) never appeared in dataStore within 15s")
    }

    /// Returns (inboxSinkCount, saveRefreshCount, lastInboxPayload, badgeCount) after
    /// burst + settle. Runs §F.5 settle policy: 200ms first; on three-way mismatch,
    /// the assertion fails — do not silently widen.
    private func runRefreshAndCapture(debounceMS: Int) throws
        -> (sink: Int, save: Int, payload: Int, badge: Int)
    {
        let app = XCUIApplication()
        app.launchEnvironment = baseEnv(seedCount: 20, debounceMS: debounceMS)
        app.launch()

        let resetButton = app.buttons["debug.resetCounters"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 30),
            "DebugOverlayView didn't render — env var not flowing or app failed to launch")
        resetButton.tap()

        // Capture baseline before tap so we can detect the post-tap completion
        // even though refreshTotal/refreshCompleted get reset in the defer.
        let baselineCompletions = readInt(app, identifier: "debug.refreshCompletions")

        // Trigger the burst.
        app.buttons["debug.triggerRefresh"].tap()

        // Wait for refreshAll completion (monotonic counter, ignores the
        // refreshTotal=0 reset in refreshAll's defer block).
        try waitForRefreshAllCompletion(
            app: app,
            baselineCompletions: baselineCompletions,
            expectedSnapshotCount: 20
        )

        // §F.5 settle: 4 × debounce window, minimum 200ms.
        let settleMS = max(200, 4 * debounceMS)
        usleep(useconds_t(settleMS) * 1000)

        // Capture counters.
        app.buttons["debug.refreshDBCounts"].tap()
        let sink = readInt(app, identifier: "debug.inboxSinkCount")
        let save = readInt(app, identifier: "debug.saveRefreshCount")
        let payload = readInt(app, identifier: "debug.lastInboxPayload")
        let inboxArray = readInt(app, identifier: "debug.inboxArrayCount")
        let dbEpisodes = readInt(app, identifier: "debug.dbEpisodeCount")
        let badge = readInt(app, identifier: "debug.inboxCount")

        // §H three-way exact match — payload, observable inbox, DB read all agree.
        XCTAssertEqual(payload, inboxArray,
            "G-END-STATE: lastInboxPayload (\(payload)) != inbox.count (\(inboxArray))")
        XCTAssertEqual(payload, dbEpisodes,
            "G-END-STATE: lastInboxPayload (\(payload)) != dbEpisodeCount (\(dbEpisodes))")
        XCTAssertEqual(badge, payload,
            "G-END-STATE: badge inboxCount (\(badge)) != lastInboxPayload (\(payload))")

        // Settle stability: counters do not drift.
        usleep(100_000)
        let sinkAfter = readInt(app, identifier: "debug.inboxSinkCount")
        XCTAssertEqual(sinkAfter, sink,
            "G-END-STATE: trailing sink fired after settle (was \(sink), now \(sinkAfter))")

        XCTAssertEqual(app.staticTexts["debug.isRefreshing"].label, "false")

        app.terminate()
        return (sink, save, payload, badge)
    }
}
