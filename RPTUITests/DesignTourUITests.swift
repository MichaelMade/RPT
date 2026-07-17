//
//  DesignTourUITests.swift
//  RPTUITests
//
//  Walks the app's key screens end-to-end, capturing a named screenshot
//  at each stop, and verifies the set log/unlog flow along the way.
//

import XCTest

final class DesignTourUITests: XCTestCase {
    @MainActor
    func testDesignTour() throws {
        let app = XCUIApplication()
        app.launch()

        // Onboarding appears on a fresh install — capture it, then exit via
        // the activation screen's browse path.
        let skipIntro = app.buttons["Skip Intro"]
        if skipIntro.waitForExistence(timeout: 4) {
            snap(app, "01-onboarding")
            skipIntro.tap()

            let browse = app.buttons["Browse the App First"]
            XCTAssertTrue(browse.waitForExistence(timeout: 4), "Skipping the intro should land on activation choices")
            browse.tap()
        }

        snap(app, "02-home-empty")

        // MARK: Templates → start the seeded routine
        app.tabBars.buttons["Templates"].tap()
        snap(app, "03-templates")

        let start = app.buttons["Start"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 4), "Seeded template should offer a Start button")
        start.tap()

        // Unit tests run first on this simulator and share the app container,
        // so a resumable draft can be left behind — Start then asks what to do
        // with it. Discard it and continue the tour.
        let discardAndStart = app.buttons["Discard Current & Start Template"]
        if discardAndStart.waitForExistence(timeout: 3) {
            discardAndStart.tap()
        }

        let finish = app.buttons["Finish"]
        XCTAssertTrue(
            finish.waitForExistence(timeout: 10),
            "Active workout should present (alert: \(app.alerts.firstMatch.exists ? app.alerts.firstMatch.label : "none"))"
        )
        snap(app, "04-active-workout")

        // MARK: Log flow — empty set must route to the editor
        let logButton = app.buttons["Log set"].firstMatch
        XCTAssertTrue(logButton.waitForExistence(timeout: 4))
        logButton.tap()

        let saveSet = app.buttons["Save Set"]
        XCTAssertTrue(saveSet.waitForExistence(timeout: 4), "Logging an empty set should open the value editor")
        snap(app, "05-set-editor")

        app.typeText("200") // weight field is auto-focused
        let repsField = app.textFields.element(boundBy: 1)
        repsField.tap()
        app.typeText("5")

        // Dismiss the number pad via the keyboard toolbar so Save is hittable.
        let keyboardDone = app.buttons["Done"]
        if keyboardDone.exists {
            keyboardDone.tap()
        }
        saveSet.tap()

        // Auto rest timer is on by default and should fire on the logged set.
        let restTimerTitle = app.staticTexts["Rest Timer"]
        if restTimerTitle.waitForExistence(timeout: 4) {
            snap(app, "06-rest-timer")
            app.buttons["Skip Rest"].tap()
        }

        let unlogButton = app.buttons["Unlog set"].firstMatch
        XCTAssertTrue(unlogButton.waitForExistence(timeout: 4), "Set should be logged after saving values")
        snap(app, "07-active-workout-logged")

        // MARK: Toggle round-trip — unlog, then tap-to-log with values present
        unlogButton.tap()
        let logAgain = app.buttons["Log set"].firstMatch
        XCTAssertTrue(logAgain.waitForExistence(timeout: 4), "Unlogging should revert the check-off")
        logAgain.tap()
        if app.buttons["Skip Rest"].waitForExistence(timeout: 3) {
            app.buttons["Skip Rest"].tap()
        }
        XCTAssertTrue(app.buttons["Unlog set"].firstMatch.waitForExistence(timeout: 4),
                      "Tapping log on a set with values should log it without opening the editor")

        // MARK: Finish the workout
        finish.tap()
        let complete = app.buttons["Complete & Save"]
        XCTAssertTrue(complete.waitForExistence(timeout: 4))
        complete.tap()

        // MARK: Exercises
        app.tabBars.buttons["Exercises"].tap()
        snap(app, "08-exercises")

        let firstRow = app.cells.firstMatch
        if firstRow.waitForExistence(timeout: 3) {
            firstRow.tap()
            snap(app, "09-exercise-detail")
            let back = app.navigationBars.buttons.element(boundBy: 0)
            if back.exists { back.tap() }
        }

        // MARK: Stats — now has one completed workout
        app.tabBars.buttons["Stats"].tap()
        snap(app, "10-stats")

        // MARK: Settings + dark mode
        app.tabBars.buttons["Settings"].tap()
        snap(app, "11-settings")

        let darkSegment = app.buttons["Dark"]
        if darkSegment.waitForExistence(timeout: 3) {
            darkSegment.tap()
            snap(app, "12-settings-dark")

            app.tabBars.buttons["Home"].tap()
            snap(app, "13-home-dark")

            app.tabBars.buttons["Stats"].tap()
            snap(app, "14-stats-dark")
        }
    }

    @MainActor
    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
