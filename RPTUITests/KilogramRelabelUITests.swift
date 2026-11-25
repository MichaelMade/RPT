//
//  KilogramRelabelUITests.swift
//  RPTUITests
//
//  Drives the one path that rewrites logged history in bulk: switch to
//  kilograms in Settings, answer the question, see the relabeled loads on
//  another tab, and undo. Unit tests cover what the relabel does to the
//  store; only this proves the alerts are raised and the screens follow.
//

import XCTest

final class KilogramRelabelUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The app is launched with one finished workout stored the way every
    /// set was before RPT had a unit: 100 x 5 and 90 x 5, 950 in total. As
    /// pounds that is 431 kg. Relabeled, it is 950 kg.
    @MainActor
    func testSwitchingToKilogramsAsksOnceRelabelsAndUndoes() throws {
        #if !targetEnvironment(simulator)
        // The seeded history comes from a hook that only exists in
        // simulator builds, so that it can never reset the unit choice on a
        // phone with real workouts on it.
        throw XCTSkip("Runs on the simulator only: it needs the seeded, launch-only store.")
        #endif

        let app = XCUIApplication()
        // The history lives in a store made for this launch only, and the
        // unit starts on pounds whatever an earlier test left behind.
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "--uiTestPoundHistory"]
        app.launch()

        let homeTab = app.tabBars.buttons["Home"]
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10))

        homeTab.tap()
        XCTAssertTrue(anyElement(in: app, showing: "950 lb").waitForExistence(timeout: 10), "The seeded workout reads in pounds")

        // In pounds there is nothing to decide, so there is no row.
        settingsTab.tap()
        let kilograms = app.buttons["kg"]
        XCTAssertTrue(kilograms.waitForExistence(timeout: 10))
        bringIntoReach(kilograms, in: app)
        XCTAssertFalse(app.buttons["earlierWorkoutsRelabelRow"].exists)
        XCTAssertFalse(app.buttons["earlierWorkoutsUndoRow"].exists)

        // Switching asks, quoting the most recent set.
        kilograms.tap()
        let question = app.alerts["Were your earlier workouts logged in kilograms?"]
        XCTAssertTrue(question.waitForExistence(timeout: 10), "Switching to kilograms should raise the question")
        XCTAssertTrue(
            anyElement(in: question, showing: "entered as 90").exists,
            "The question should be about the lifter's own most recent set"
        )
        question.buttons["They Were Kilograms"].tap()

        let undoRow = app.buttons["earlierWorkoutsUndoRow"]
        XCTAssertTrue(undoRow.waitForExistence(timeout: 10), "After a relabel, Settings offers the way back")

        // The relabeled load is what another tab shows.
        homeTab.tap()
        XCTAssertTrue(anyElement(in: app, showing: "950 kg").waitForExistence(timeout: 10), "950 now reads as 950 kg")

        // Undo puts the earlier sets back to pounds.
        settingsTab.tap()
        XCTAssertTrue(undoRow.waitForExistence(timeout: 10))
        bringIntoReach(undoRow, in: app)
        undoRow.tap()
        let undoQuestion = app.alerts["Undo the kilogram relabel?"]
        XCTAssertTrue(undoQuestion.waitForExistence(timeout: 10))
        undoQuestion.buttons["Undo Relabel"].tap()

        let relabelRow = app.buttons["earlierWorkoutsRelabelRow"]
        XCTAssertTrue(relabelRow.waitForExistence(timeout: 10), "After an undo the relabel is on offer again")
        XCTAssertFalse(undoRow.exists)

        homeTab.tap()
        XCTAssertTrue(anyElement(in: app, showing: "431 kg").waitForExistence(timeout: 10), "950 lb shown converted again")

        // The row brings the question back; declining it changes nothing.
        settingsTab.tap()
        XCTAssertTrue(relabelRow.waitForExistence(timeout: 10))
        bringIntoReach(relabelRow, in: app)
        relabelRow.tap()
        XCTAssertTrue(question.waitForExistence(timeout: 10))
        question.buttons["They Were Pounds"].tap()
        XCTAssertTrue(relabelRow.waitForExistence(timeout: 10))

        // Asked once: switching away and back does not raise it again,
        // and the row is still there for a lifter who changes their mind.
        let pounds = app.buttons["lb"]
        bringIntoReach(pounds, in: app)
        pounds.tap()
        XCTAssertTrue(waitForDisappearance(of: relabelRow), "In pounds there is nothing to decide")
        kilograms.tap()
        XCTAssertTrue(relabelRow.waitForExistence(timeout: 10))
        XCTAssertFalse(question.waitForExistence(timeout: 3), "The question is only raised unprompted once")

        // Leave the simulator on pounds for whatever runs next.
        pounds.tap()
        homeTab.tap()
        XCTAssertTrue(anyElement(in: app, showing: "950 lb").waitForExistence(timeout: 10))
    }

    @MainActor
    private func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter.wait(for: [gone], timeout: timeout) == .completed
    }

    /// Any element whose label contains `text`. The workout card combines
    /// its texts into one element, so this is not tied to how it is built.
    @MainActor
    private func anyElement(in container: XCUIElement, showing text: String) -> XCUIElement {
        container.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    @MainActor
    private func bringIntoReach(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<3 where !element.isHittable {
            app.swipeDown()
        }
        XCTAssertTrue(element.isHittable, "\(element) should be on screen")
    }
}
