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
        // Dedicated reset flag: the app clears first-run state in the
        // persistent domain. (A `-hasCompletedOnboarding NO` argument would
        // pin the value process-wide and block the onboarding handoff.)
        app.launchArguments += ["--uiTestFreshOnboarding"]
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

        // Live workout screen. Generous timeout: CI simulators are slow and
        // the cover presents just after the onboarding → tabs root swap.
        let workoutVisible = app.staticTexts["No Exercises Yet"].waitForExistence(timeout: 30)
        if !workoutVisible {
            let tabsVisible = app.tabBars.buttons["Home"].exists
            XCTFail(
                "Empty-workout activation should land on the live workout screen. "
                    + "Tab bar visible: \(tabsVisible) — true means the workout cover failed to present; "
                    + "false means onboarding never handed off to the tab shell."
            )
        }

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

    /// Appearance selection updates the effective SwiftUI environment and
    /// survives a relaunch. This protects the root observation path rather
    /// than checking only whether the segmented control changed selection.
    @MainActor
    func testAppearanceSelectionChangesEffectiveColorScheme() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 10))
        let appearanceProbe = app.descendants(matching: .any)["appearance-probe"]
        XCTAssertTrue(appearanceProbe.waitForExistence(timeout: 5))

        app.tabBars.buttons["Settings"].tap()
        let darkSegment = app.buttons["Dark"]
        for _ in 0..<3 where !darkSegment.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(darkSegment.isHittable)

        darkSegment.tap()
        waitForAppearance("dark", using: appearanceProbe)

        let lightSegment = app.buttons["Light"]
        XCTAssertTrue(lightSegment.isHittable)
        lightSegment.tap()
        waitForAppearance("light", using: appearanceProbe)

        app.terminate()
        app.launch()

        let relaunchedProbe = app.descendants(matching: .any)["appearance-probe"]
        XCTAssertTrue(relaunchedProbe.waitForExistence(timeout: 10))
        waitForAppearance("light", using: relaunchedProbe)

        // Leave shared simulator state following the device preference for
        // other UI tests that may run in the same app container.
        app.tabBars.buttons["Settings"].tap()
        let systemSegment = app.buttons["System"]
        for _ in 0..<3 where !systemSegment.isHittable {
            app.swipeUp()
        }
        if systemSegment.isHittable {
            systemSegment.tap()
        }
    }

    @MainActor
    private func waitForAppearance(
        _ expectedValue: String,
        using probe: XCUIElement,
        timeout: TimeInterval = 5
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expectedValue),
            object: probe
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected effective appearance to become \(expectedValue)"
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
