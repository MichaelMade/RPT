//
//  RPTUITests.swift
//  RPTUITests
//
//  Smoke coverage for the most important user journey: first launch,
//  onboarding activation, starting a workout, and resuming it.
//

import XCTest

final class RPTUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// First launch → onboarding → empty-workout activation → save for
    /// later → resumable workout visible on Home.
    @MainActor
    func testFirstRunOnboardingIntoFirstWorkout() throws {
        let app = XCUIApplication()
        // Registration-domain override forces the first-run experience.
        app.launchArguments += ["-hasCompletedOnboarding", "NO"]
        app.launch()

        // Onboarding pager.
        XCTAssertTrue(
            app.staticTexts["Welcome to RPT"].waitForExistence(timeout: 10),
            "First launch should show onboarding"
        )

        app.buttons["Continue"].tap()
        app.buttons["Continue"].tap()
        app.buttons["Choose Your First Step"].tap()

        // Activation handoff.
        let emptyWorkoutChoice = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "Start Empty Workout")
        ).firstMatch
        XCTAssertTrue(
            emptyWorkoutChoice.waitForExistence(timeout: 5),
            "Onboarding should offer the empty-workout activation path"
        )
        emptyWorkoutChoice.tap()

        // Live workout screen.
        XCTAssertTrue(
            app.staticTexts["No Exercises Yet"].waitForExistence(timeout: 10),
            "Empty-workout activation should land on the live workout screen"
        )

        // Keep the draft and return to the app.
        app.buttons["Save for Later"].tap()

        // Home should now offer to resume the draft.
        let continueButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "Continue Workout")
        ).firstMatch
        XCTAssertTrue(
            continueButton.waitForExistence(timeout: 10),
            "A saved draft should be resumable from Home"
        )
    }

    /// Returning-user launch shows the main tab bar.
    @MainActor
    func testReturningUserLandsOnTabs() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        app.launch()

        XCTAssertTrue(
            app.tabBars.buttons["Home"].waitForExistence(timeout: 10),
            "Returning users should land on the tab bar"
        )
        XCTAssertTrue(app.tabBars.buttons["Stats"].exists)
        XCTAssertTrue(app.tabBars.buttons["Templates"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
