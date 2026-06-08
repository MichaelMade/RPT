import XCTest
@testable import RPT

final class HomeViewTests: XCTestCase {
    func testDiscardCurrentWorkoutAndStartFreshAlertCopy_fallsBackGracefully() {
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFreshAlertTitle(for: nil),
            "Discard This Workout & Start New Workout?"
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
            "Discard This Workout & Start Follow-Up from “Upper A”?"
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: workout),
            "Your in-progress workout will be lost and RPT will immediately start a follow-up from “Upper A”. Source session: 2 exercises • 2 sets. This action cannot be undone."
        )
    }

    func testDiscardCurrentWorkoutAndStartFollowUpAlertCopy_namesSpecificCurrentWorkoutWhenAvailable() {
        let workout = Workout(name: "  Upper   A  ", isCompleted: true)
        let currentWorkout = Workout(name: "  Push   Day  ")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back])
        workout.addSet(exercise: bench, weight: 185, reps: 8)
        workout.addSet(exercise: row, weight: 135, reps: 10)

        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: workout, currentWorkout: currentWorkout),
            "Discard “Push Day” & Start Follow-Up from “Upper A”?"
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: workout, currentWorkout: currentWorkout),
            "“Push Day” will be lost and RPT will immediately start a follow-up from “Upper A”. Source session: 2 exercises • 2 sets. This action cannot be undone."
        )
    }

    func testDiscardCurrentWorkoutAndStartFollowUpAlertCopy_keepsLegacyPlaceholderCurrentWorkoutGeneric() {
        let workout = Workout(name: "  Upper   A  ", isCompleted: true)
        let currentWorkout = Workout(name: "Current Workout")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back])
        workout.addSet(exercise: bench, weight: 185, reps: 8)
        workout.addSet(exercise: row, weight: 135, reps: 10)

        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: workout, currentWorkout: currentWorkout),
            "Discard This Workout & Start Follow-Up from “Upper A”?"
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: workout, currentWorkout: currentWorkout),
            "Your in-progress workout will be lost and RPT will immediately start a follow-up from “Upper A”. Source session: 2 exercises • 2 sets. This action cannot be undone."
        )
    }

    func testDiscardCurrentWorkoutAndStartFollowUpAlertCopy_fallsBackGracefully() {
        let blankWorkout = Workout(name: " \n ", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = blankWorkout.addSet(exercise: bench, weight: 45, reps: 12, isWarmup: true)

        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: blankWorkout),
            "Discard This Workout & Start This Follow-Up?"
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: blankWorkout),
            "Your in-progress workout will be lost and RPT will immediately start the selected follow-up. Source session: Warm-up sets only. This action cannot be undone."
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: nil),
            "Discard This Workout & Start This Follow-Up?"
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

    func testSourceTemplateBlockMessage_matchesEmptyDraftRecoveryState() {
        let template = WorkoutTemplate(name: "  Upper   A  ")
        let workout = Workout(name: "Current Workout")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = workout.addSet(exercise: bench, weight: 0, reps: 0)

        XCTAssertEqual(
            HomeView.sourceTemplateBlockMessage(for: template, activeWorkout: workout),
            "You already have a workout draft in progress: Started just now • 1 exercise • 1 set • Exercise not started yet. Open it, save it for later, or discard it before starting Template “Upper A”."
        )
    }

    func testSourceTemplateBlockMessage_matchesStartedDraftRecoveryState() {
        let template = WorkoutTemplate(name: "  Upper   A  ")
        let workout = Workout(name: "Push Day")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        workout.addSet(exercise: bench, weight: 185, reps: 8)

        XCTAssertEqual(
            HomeView.sourceTemplateBlockMessage(for: template, activeWorkout: workout),
            "You already have “Push Day” in progress: Started just now • 1 exercise • 1 set • Exercise started. Continue it, use Save “Push Day” for Later, or discard it before starting Template “Upper A”."
        )
    }

    func testSourceTemplateBlockAlertMessage_namesTemplateWhenWorkoutDetailsAreUnavailable() {
        XCTAssertEqual(
            HomeView.sourceTemplateBlockAlertMessage(for: WorkoutTemplate(name: "Upper A"), activeWorkout: nil),
            "You already have a workout in progress. Continue, save, or discard this workout before starting Template “Upper A”."
        )
    }

    func testSourceTemplateBlockAlertMessage_mentionsPartialTemplateWhenWorkoutDetailsAreUnavailable() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = WorkoutTemplate(
            name: "Upper A",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "Ghost Lift")
            ],
            notes: ""
        )

        XCTAssertEqual(
            HomeView.sourceTemplateBlockAlertMessage(for: template, activeWorkout: nil),
            "You already have a workout in progress. Continue, save, or discard this workout before starting the available part of Template “Upper A”."
        )
    }

    func testDiscardCurrentWorkoutAndStartTemplateAlertCopy_namesSpecificTemplate() {
        let template = WorkoutTemplate(name: "  Upper   A  ")

        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartTemplateAlertTitle(for: template),
            "Discard This Workout & Start Template “Upper A”?"
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartTemplateAlertMessage(for: template),
            "Your in-progress workout will be lost and RPT will immediately start Template “Upper A”. Source template: 0 exercises and 0 planned sets. This action cannot be undone."
        )
    }

    func testDiscardCurrentWorkoutAndStartTemplateAlertCopy_namesSpecificCurrentWorkoutWhenAvailable() {
        let template = WorkoutTemplate(name: "  Upper   A  ")
        let currentWorkout = Workout(name: "  Push   Day  ")

        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartTemplateAlertTitle(for: template, currentWorkout: currentWorkout),
            "Discard “Push Day” & Start Template “Upper A”?"
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartTemplateAlertMessage(for: template, currentWorkout: currentWorkout),
            "“Push Day” will be lost and RPT will immediately start Template “Upper A”. Source template: 0 exercises and 0 planned sets. This action cannot be undone."
        )
    }

    func testDiscardCurrentWorkoutAndStartTemplateAlertCopy_fallsBackGracefully() {
        let blankTemplate = WorkoutTemplate(name: " \n ")

        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartTemplateAlertTitle(for: blankTemplate),
            "Discard This Workout & Start This Template?"
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartTemplateAlertMessage(for: blankTemplate),
            "Your in-progress workout will be lost and RPT will immediately start this template. Source template: 0 exercises and 0 planned sets. This action cannot be undone."
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartTemplateAlertTitle(for: nil),
            "Discard This Workout & Start This Template?"
        )
        XCTAssertEqual(
            HomeView.discardCurrentWorkoutAndStartTemplateAlertMessage(for: nil),
            "Your in-progress workout will be lost before RPT starts the selected template. This action cannot be undone."
        )
    }
}
