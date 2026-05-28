import XCTest
import SwiftData
@testable import RPT

final class WorkoutDetailViewTests: XCTestCase {
    func testDiscardCurrentWorkoutAndStartFollowUpAlertCopy_namesSpecificWorkout() {
        let workout = Workout(name: "  Upper   A  ", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back])
        workout.addSet(exercise: bench, weight: 185, reps: 8)
        workout.addSet(exercise: row, weight: 135, reps: 10)

        XCTAssertEqual(
            WorkoutDetailView.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: workout),
            "Discard Current Workout & Start Follow-Up from “Upper A”?"
        )
        XCTAssertEqual(
            WorkoutDetailView.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: workout),
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
            WorkoutDetailView.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: workout, currentWorkout: currentWorkout),
            "Discard “Push Day” & Start Follow-Up from “Upper A”?"
        )
        XCTAssertEqual(
            WorkoutDetailView.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: workout, currentWorkout: currentWorkout),
            "“Push Day” will be lost and RPT will immediately start a follow-up from “Upper A”. Source session: 2 exercises • 2 sets. This action cannot be undone."
        )
    }

    func testDiscardCurrentWorkoutAndStartFollowUpAlertCopy_fallsBackGracefully() {
        let blankWorkout = Workout(name: " \n ", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = blankWorkout.addSet(exercise: bench, weight: 45, reps: 12, isWarmup: true)

        XCTAssertEqual(
            WorkoutDetailView.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: blankWorkout),
            "Discard Current Workout & Start This Follow-Up?"
        )
        XCTAssertEqual(
            WorkoutDetailView.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: blankWorkout),
            "Your in-progress workout will be lost and RPT will immediately start the selected follow-up. Source session: Warm-up sets only. This action cannot be undone."
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

    func testTemplateStartFailureAlertTitles_nameSpecificTemplate() {
        let template = WorkoutTemplate(name: "  Upper   A  ")

        XCTAssertEqual(
            WorkoutDetailView.templateStartFailureAlertTitle(for: template),
            "Couldn’t Start Template “Upper A”"
        )
        XCTAssertEqual(
            WorkoutDetailView.templateSaveAndStartFailureAlertTitle(for: template),
            "Couldn’t Save & Start Template “Upper A”"
        )
        XCTAssertEqual(
            WorkoutDetailView.templateDiscardAndStartFailureAlertTitle(for: template),
            "Couldn’t Discard & Start Template “Upper A”"
        )
    }

    func testTemplateStartFailureAlertTitles_fallBackGracefully() {
        let blankTemplate = WorkoutTemplate(name: " \n ")

        XCTAssertEqual(
            WorkoutDetailView.templateStartFailureAlertTitle(for: blankTemplate),
            "Couldn’t Start This Template"
        )
        XCTAssertEqual(
            WorkoutDetailView.templateSaveAndStartFailureAlertTitle(for: blankTemplate),
            "Couldn’t Save & Start This Template"
        )
        XCTAssertEqual(
            WorkoutDetailView.templateDiscardAndStartFailureAlertTitle(for: blankTemplate),
            "Couldn’t Discard & Start This Template"
        )
        XCTAssertEqual(
            WorkoutDetailView.templateStartFailureAlertTitle(for: nil),
            "Couldn’t Start This Template"
        )
        XCTAssertEqual(
            WorkoutDetailView.templateSaveAndStartFailureAlertTitle(for: nil),
            "Couldn’t Save & Start This Template"
        )
        XCTAssertEqual(
            WorkoutDetailView.templateDiscardAndStartFailureAlertTitle(for: nil),
            "Couldn’t Discard & Start This Template"
        )
    }

    func testSourceTemplateDescription_namesSpecificTemplateForFreshRestarts() {
        let template = WorkoutTemplate(name: "  Upper   A  ")

        XCTAssertEqual(
            WorkoutDetailView.sourceTemplateDescription(for: template),
            "This workout started from “Upper A”. Review the original plan or jump straight back into a fresh run from here."
        )
    }

    func testSourceTemplateDescription_mentionsPartialTemplateRestartsWhenExercisesAreMissing() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(
            name: "Workout Detail Partial Template Available \(UUID().uuidString)",
            category: .compound,
            primaryMuscleGroups: [.chest]
        )
        context.insert(availableExercise)
        try context.save()
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let partialTemplate = WorkoutTemplate(
            name: "  Upper   A  ",
            exercises: [
                TemplateExercise(exerciseName: availableExercise.name, suggestedSets: 3),
                TemplateExercise(exerciseName: "Missing Exercise \(UUID().uuidString)", suggestedSets: 3)
            ]
        )

        XCTAssertEqual(
            WorkoutDetailView.sourceTemplateDescription(for: partialTemplate),
            "This workout started from “Upper A”. Review the original plan or jump straight back into the available part of that template from here."
        )
    }

    func testSourceTemplateBlockMessage_mentionsPartialTemplateWhenExercisesAreMissing() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(
            name: "Workout Detail Block Message Available \(UUID().uuidString)",
            category: .compound,
            primaryMuscleGroups: [.chest]
        )
        context.insert(availableExercise)
        try context.save()
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let partialTemplate = WorkoutTemplate(
            name: "  Upper   A  ",
            exercises: [
                TemplateExercise(exerciseName: availableExercise.name, suggestedSets: 3),
                TemplateExercise(exerciseName: "Missing Exercise \(UUID().uuidString)", suggestedSets: 3)
            ]
        )
        let activeWorkout = Workout(name: "Push Day")

        XCTAssertEqual(
            WorkoutDetailView.sourceTemplateBlockMessage(for: partialTemplate, activeWorkout: activeWorkout),
            "You already have “Push Day” in progress. Continue it before starting the available part of Template “Upper A”."
        )
    }

    func testSourceTemplateBlockMessage_fallsBackGracefullyForUnnamedTemplateAndWorkout() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(
            name: "Workout Detail Generic Block Message Available \(UUID().uuidString)",
            category: .compound,
            primaryMuscleGroups: [.back]
        )
        context.insert(availableExercise)
        try context.save()
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let partialTemplate = WorkoutTemplate(
            name: " \n ",
            exercises: [
                TemplateExercise(exerciseName: availableExercise.name, suggestedSets: 3),
                TemplateExercise(exerciseName: "Missing Exercise \(UUID().uuidString)", suggestedSets: 3)
            ]
        )
        let activeWorkout = Workout(name: " \n ")

        XCTAssertEqual(
            WorkoutDetailView.sourceTemplateBlockMessage(for: partialTemplate, activeWorkout: activeWorkout),
            "You already have a workout in progress. Continue it before starting the available part of this template."
        )
        XCTAssertNil(WorkoutDetailView.sourceTemplateBlockMessage(for: nil, activeWorkout: activeWorkout))
        XCTAssertNil(WorkoutDetailView.sourceTemplateBlockMessage(for: partialTemplate, activeWorkout: nil))
    }
}
