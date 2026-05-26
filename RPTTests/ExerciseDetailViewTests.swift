import XCTest
@testable import RPT

final class ExerciseDetailViewTests: XCTestCase {
    func testDiscardCurrentWorkoutAndStartFollowUpAlertCopy_namesSpecificWorkout() {
        let workout = Workout(name: "  Upper   A  ", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back])
        workout.addSet(exercise: bench, weight: 185, reps: 8)
        workout.addSet(exercise: row, weight: 135, reps: 10)

        XCTAssertEqual(
            ExerciseDetailView.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: workout),
            "Discard Current Workout & Start Follow-Up from “Upper A”?"
        )
        XCTAssertEqual(
            ExerciseDetailView.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: workout),
            "Your in-progress workout will be lost and RPT will immediately start a follow-up from “Upper A”. Source session: 2 exercises • 2 sets. This action cannot be undone."
        )
    }

    func testDiscardCurrentWorkoutAndStartFollowUpAlertCopy_fallsBackGracefully() {
        let blankWorkout = Workout(name: " \n ", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = blankWorkout.addSet(exercise: bench, weight: 45, reps: 12, isWarmup: true)

        XCTAssertEqual(
            ExerciseDetailView.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: blankWorkout),
            "Discard Current Workout & Start This Follow-Up?"
        )
        XCTAssertEqual(
            ExerciseDetailView.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: blankWorkout),
            "Your in-progress workout will be lost before RPT starts the selected follow-up. Source session: Warm-up sets only. This action cannot be undone."
        )
        XCTAssertEqual(
            ExerciseDetailView.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: nil),
            "Discard Current Workout & Start This Follow-Up?"
        )
        XCTAssertEqual(
            ExerciseDetailView.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: nil),
            "Your in-progress workout will be lost before RPT starts the selected follow-up. This action cannot be undone."
        )
    }

    func testTemplateStartFailureAlertTitles_nameSpecificTemplate() {
        let template = WorkoutTemplate(name: "  Upper   A  ")

        XCTAssertEqual(
            ExerciseDetailView.templateStartFailureAlertTitle(for: template),
            "Couldn’t Start Template “Upper A”"
        )
        XCTAssertEqual(
            ExerciseDetailView.templateSaveAndStartFailureAlertTitle(for: template),
            "Couldn’t Save & Start Template “Upper A”"
        )
        XCTAssertEqual(
            ExerciseDetailView.templateDiscardAndStartFailureAlertTitle(for: template),
            "Couldn’t Discard & Start Template “Upper A”"
        )
    }

    func testTemplateStartFailureAlertTitles_fallBackGracefully() {
        let blankTemplate = WorkoutTemplate(name: " \n ")

        XCTAssertEqual(
            ExerciseDetailView.templateStartFailureAlertTitle(for: blankTemplate),
            "Couldn’t Start This Template"
        )
        XCTAssertEqual(
            ExerciseDetailView.templateSaveAndStartFailureAlertTitle(for: blankTemplate),
            "Couldn’t Save & Start This Template"
        )
        XCTAssertEqual(
            ExerciseDetailView.templateDiscardAndStartFailureAlertTitle(for: blankTemplate),
            "Couldn’t Discard & Start This Template"
        )
        XCTAssertEqual(
            ExerciseDetailView.templateStartFailureAlertTitle(for: nil),
            "Workout Action Failed"
        )
    }

    func testDiscardCurrentWorkoutAndStartTemplateAlertCopy_namesSpecificTemplate() {
        let template = WorkoutTemplate(name: "  Upper   A  ")

        XCTAssertEqual(
            ExerciseDetailView.discardCurrentWorkoutAndStartTemplateAlertTitle(for: template),
            "Discard Current Workout & Start Template “Upper A”?"
        )
        XCTAssertEqual(
            ExerciseDetailView.discardCurrentWorkoutAndStartTemplateAlertMessage(for: template),
            "Your in-progress workout will be lost and RPT will immediately start Template “Upper A”. Source template: 0 exercises and 0 planned sets. This action cannot be undone."
        )
    }

    func testDiscardCurrentWorkoutAndStartTemplateAlertCopy_namesSpecificCurrentWorkoutWhenAvailable() {
        let template = WorkoutTemplate(name: "  Upper   A  ")
        let currentWorkout = Workout(name: "  Push   Day  ")

        XCTAssertEqual(
            ExerciseDetailView.discardCurrentWorkoutAndStartTemplateAlertTitle(for: template, currentWorkout: currentWorkout),
            "Discard “Push Day” & Start Template “Upper A”?"
        )
        XCTAssertEqual(
            ExerciseDetailView.discardCurrentWorkoutAndStartTemplateAlertMessage(for: template, currentWorkout: currentWorkout),
            "“Push Day” will be lost and RPT will immediately start Template “Upper A”. Source template: 0 exercises and 0 planned sets. This action cannot be undone."
        )
    }

    func testDiscardCurrentWorkoutAndStartTemplateAlertCopy_fallsBackGracefully() {
        let blankTemplate = WorkoutTemplate(name: " \n ")

        XCTAssertEqual(
            ExerciseDetailView.discardCurrentWorkoutAndStartTemplateAlertTitle(for: blankTemplate),
            "Discard Current Workout & Start This Template?"
        )
        XCTAssertEqual(
            ExerciseDetailView.discardCurrentWorkoutAndStartTemplateAlertMessage(for: blankTemplate),
            "Your in-progress workout will be lost and RPT will immediately start this template. Source template: 0 exercises and 0 planned sets. This action cannot be undone."
        )
        XCTAssertEqual(
            ExerciseDetailView.discardCurrentWorkoutAndStartTemplateAlertTitle(for: nil),
            "Discard Current Workout & Start This Template?"
        )
        XCTAssertEqual(
            ExerciseDetailView.discardCurrentWorkoutAndStartTemplateAlertMessage(for: nil),
            "Your in-progress workout will be lost before RPT starts the selected template. This action cannot be undone."
        )
    }
}
