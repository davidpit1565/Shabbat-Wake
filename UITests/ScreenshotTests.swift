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

        // Shabbat times first, so the home screen already knows the candle-lighting time when it is shown.
        buttons.element(boundBy: 2).tap()
        sleep(14)   // the times come from the network
        shot("3-times")

        buttons.element(boundBy: 0).tap()
        sleep(3)
        shot("1-home")

        buttons.element(boundBy: 1).tap()
        sleep(2)
        shot("2-alarms")

        // The editor for the first alarm.
        let firstAlarm = app.cells.firstMatch
        if firstAlarm.waitForExistence(timeout: 5) {
            firstAlarm.tap()
            sleep(2)
            shot("5-editor")
            app.swipeDown(velocity: .fast)
            sleep(1)
        }

        buttons.element(boundBy: 3).tap()
        sleep(2)
        shot("4-settings")

        // The Pro screen: the first row of Settings.
        let proRow = app.cells.firstMatch
        if proRow.waitForExistence(timeout: 5) {
            proRow.tap()
            sleep(3)
            shot("6-pro")
        }
    }
}
