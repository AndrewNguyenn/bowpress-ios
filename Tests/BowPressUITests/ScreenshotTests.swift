import XCTest

/// Launches the app, visits each tab, and captures an App Store screenshot per tab.
/// Attachments are exported from the xcresult bundle via scripts/asc/extract_screenshots.py.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testCaptureTabScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITests", "-AppleInterfaceStyle", "Light"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "tab bar never appeared (hydration splash stuck?)")

        let tabs = [
            (order: "01", name: "analytics", label: "Analytics"),
            (order: "02", name: "log", label: "Log"),
            (order: "03", name: "session", label: "Session"),
            (order: "04", name: "equipment", label: "Equipment"),
            (order: "05", name: "settings", label: "Settings"),
        ]

        for tab in tabs {
            let button = tabBar.buttons[tab.label]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "tab '\(tab.label)' not found")
            button.tap()
            usleep(900_000) // 0.9s for view settle + animations
            capture(name: "\(tab.order)_\(tab.name)")
        }
    }

    private func capture(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
