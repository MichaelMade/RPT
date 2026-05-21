import XCTest
@testable import RPT

final class HomeViewTests: XCTestCase {
    func testDiscardCurrentWorkoutAndStartTemplateAlertCopy_namesSpecificTemplate() {
        let template = WorkoutTemplate(name: "  Upper   A  ")

        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartTemplateAlertTitle(for: template),
            "Discard Current Workout & Start Template “Upper A”?"
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartTemplateAlertMessage(for: template),
            "Your in-progress workout will be lost and RPT will immediately start Template “Upper A”. This action cannot be undone."
        )
    }

    func testDiscardCurrentWorkoutAndStartTemplateAlertCopy_fallsBackGracefully() {
        let blankTemplate = WorkoutTemplate(name: " \n ")

        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartTemplateAlertTitle(for: blankTemplate),
            "Discard Current Workout & Start This Template?"
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartTemplateAlertMessage(for: blankTemplate),
            "Your in-progress workout will be lost and RPT will immediately start this template. This action cannot be undone."
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartTemplateAlertTitle(for: nil),
            "Discard Current Workout & Start This Template?"
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartTemplateAlertMessage(for: nil),
            "Your in-progress workout will be lost before RPT starts the selected template. This action cannot be undone."
        )
    }
}
