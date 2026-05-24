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
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back])
        workout.addSet(exercise: bench, weight: 185, reps: 8)
        workout.addSet(exercise: row, weight: 135, reps: 10)

        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: workout),
            "Discard Current Workout & Start Follow-Up from “Upper A”?"
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: workout),
            "Your in-progress workout will be lost and RPT will immediately start a follow-up from “Upper A”. Source session: 2 exercises • 2 sets. This action cannot be undone."
        )
    }

    func testDiscardCurrentWorkoutAndStartFollowUpAlertCopy_fallsBackGracefully() {
        let blankWorkout = Workout(name: " \n ", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = blankWorkout.addSet(exercise: bench, weight: 45, reps: 12, isWarmup: true)

        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: blankWorkout),
            "Discard Current Workout & Start This Follow-Up?"
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: blankWorkout),
            "Your in-progress workout will be lost before RPT starts the selected follow-up. Source session: Warm-up sets only. This action cannot be undone."
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

    func testStartFollowUpButtonTitle_fallsBackGracefully() {
        let namedWorkout = Workout(name: "  Upper   A  ", isCompleted: true)
        XCTAssertEqual(
            HomeView.startFollowUpButtonTitle(for: namedWorkout),
            "Start Follow-Up from “Upper A”"
        )

        let blankWorkout = Workout(name: " \n ", isCompleted: true)
        XCTAssertEqual(
            HomeView.startFollowUpButtonTitle(for: blankWorkout),
            "Start This Follow-Up"
        )
        XCTAssertEqual(
            HomeView.startFollowUpButtonTitle(for: nil),
            "Start This Follow-Up"
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
            "Your in-progress workout will be lost and RPT will immediately start Template “Upper A”. Source template: 0 exercises and 0 planned sets. This action cannot be undone."
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
            "Your in-progress workout will be lost and RPT will immediately start this template. Source template: 0 exercises and 0 planned sets. This action cannot be undone."
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
