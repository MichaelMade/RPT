import XCTest
@testable import RPT

final class HomeViewTests: XCTestCase {
    func testDiscardCurrentWorkoutAndStartFreshAlertCopy_fallsBackGracefully() {
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFreshAlertTitle(for: nil),
            "Discard Current Workout & Start New Workout?"
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFreshAlertMessage(for: nil),
            "Your in-progress workout will be lost before RPT starts a new workout. This action cannot be undone."
        )
    }

    func testDiscardCurrentWorkoutAndStartFollowUpAlertCopy_namesSpecificWorkout() {
        let workout = Workout(name: "  Upper   A  ", isCompleted: true)

        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: workout),
            "Discard Current Workout & Start Follow-Up from “Upper A”?"
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: workout),
            "Your in-progress workout will be lost and RPT will immediately start a follow-up from “Upper A”. This action cannot be undone."
        )
    }

    func testDiscardCurrentWorkoutAndStartFollowUpAlertCopy_fallsBackGracefully() {
        let blankWorkout = Workout(name: " \n ", isCompleted: true)

        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: blankWorkout),
            "Discard Current Workout & Start This Follow-Up?"
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: blankWorkout),
            "Your in-progress workout will be lost before RPT starts the selected follow-up. This action cannot be undone."
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: nil),
            "Discard Current Workout & Start This Follow-Up?"
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: nil),
            "Your in-progress workout will be lost before RPT starts the selected follow-up. This action cannot be undone."
        )
    }

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
