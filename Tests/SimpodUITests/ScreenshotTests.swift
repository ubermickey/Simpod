import XCTest

@MainActor
final class ScreenshotTests: XCTestCase {

    override func setUp() {
        continueAfterFailure = true
    }

    func testCaptureAllTabs() {
        let app = XCUIApplication()
        app.launch()

        // 1. Inbox (default tab)
        sleep(2)
        saveScreenshot("01-inbox")

        // 2. Queue tab
        app.tabBars.buttons["Queue"].tap()
        sleep(1)
        saveScreenshot("02-queue")

        // 3. Search tab
        app.tabBars.buttons["Search"].tap()
        sleep(1)
        saveScreenshot("03-search")

        // 4. Settings tab
        app.tabBars.buttons["Settings"].tap()
        sleep(1)
        saveScreenshot("04-settings")
    }

    func testImportOPMLButtonExists() {
        let app = XCUIApplication()
        app.launch()

        // Navigate to Settings
        app.tabBars.buttons["Settings"].tap()
        sleep(1)

        // Verify Import OPML button exists
        let importButton = app.buttons["Import OPML"]
        XCTAssertTrue(importButton.exists, "Import OPML button should exist in Settings")
        saveScreenshot("05-settings-import-opml")

        // Tap the button — this should present the file importer
        importButton.tap()
        sleep(2)
        saveScreenshot("06-file-importer-presented")

        // Verify the file importer sheet appeared (system file picker)
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5),
                      "File importer should present with a Cancel button")

        // Dismiss the file picker
        cancelButton.tap()
        sleep(1)
    }

    private func saveScreenshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let data = screenshot.pngRepresentation
        let path = "/tmp/simpod-screenshots/\(name).png"
        try? data.write(to: URL(fileURLWithPath: path))
    }
}
