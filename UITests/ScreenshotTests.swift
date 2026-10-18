import XCTest

/// Takes the App Store screenshots. Run by the "Screenshots" workflow, once per language.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testTakeScreenshots() {
        let app = XCUIApplication()
        app.launchArguments += ["-screenshotMode"]
        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            for label in ["Allow While Using App", "Allow", "OK"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
        app.launch()
        app.tap()

        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 20))
        let buttons = tabs.buttons

        sleep(4)
        shot("1-home")

        buttons.element(boundBy: 1).tap()
        sleep(2)
        shot("2-alarms")

        buttons.element(boundBy: 2).tap()
        sleep(12)   // the times come from the network
        shot("3-times")

        buttons.element(boundBy: 3).tap()
        sleep(2)
        shot("4-settings")
    }
}
