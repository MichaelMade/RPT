import XCTest
@testable import RPT

final class WorkoutDetailViewTests: XCTestCase {
    func testDiscardCurrentWorkoutAndStartFollowUpAlertCopy_namesSpecificWorkout() {
        let workout = Workout(name: "  Upper   A  ", isCompleted: true)

        XCTAssertEqual(
            WorkoutDetailView.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: workout),
            "Discard Current Workout & Start Follow-Up from “Upper A”?"
        )
        XCTAssertEqual(
            WorkoutDetailView.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: workout),
            "Your in-progress workout will be lost and RPT will immediately start a follow-up from “Upper A”. This action cannot be undone."
        )
    }

    func testDiscardCurrentWorkoutAndStartFollowUpAlertCopy_fallsBackGracefully() {
        let blankWorkout = Workout(name: " \n ", isCompleted: true)

        XCTAssertEqual(
            WorkoutDetailView.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: blankWorkout),
            "Discard Current Workout & Start This Follow-Up?"
        )
        XCTAssertEqual(
            WorkoutDetailView.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: blankWorkout),
            "Your in-progress workout will be lost before RPT starts the selected follow-up. This action cannot be undone."
        )
        XCTAssertEqual(
            WorkoutDetailView.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: nil),
            "Discard Current Workout & Start This Follow-Up?"
        )
        XCTAssertEqual(
            WorkoutDetailView.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: nil),
            "Your in-progress workout will be lost before RPT starts the selected follow-up. This action cannot be undone."
        )
    }
}
