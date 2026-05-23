import XCTest
@testable import RPT

@MainActor
final class ExerciseManagerTests: XCTestCase {
    func testValidateDraft_requiresNonEmptyName() {
        let result = ExerciseManager.shared.validateDraft(
            name: "   \n  ",
            primaryMuscleGroups: [.chest]
        )

        XCTAssertEqual(result, .missingName)
    }

    func testValidateDraft_requiresAtLeastOnePrimaryMuscle() {
        let result = ExerciseManager.shared.validateDraft(
            name: "Bench Press",
            primaryMuscleGroups: []
        )

        XCTAssertEqual(result, .noPrimaryMuscles)
    }

    func testValidateDraft_acceptsEditableExistingExerciseName() {
        guard let exercise = ExerciseManager.shared.fetchAllExercises().first else {
            XCTFail("Expected seeded exercise data")
            return
        }

        let result = ExerciseManager.shared.validateDraft(
            name: " \(exercise.name) ",
            primaryMuscleGroups: exercise.primaryMuscleGroups,
            excludingExerciseId: exercise.id
        )

        XCTAssertEqual(result, .valid)
    }

    func testValidateDraft_rejectsDuplicateNormalizedName() {
        let result = ExerciseManager.shared.validateDraft(
            name: "  Ｂｅｎｃｈ   Ｐｒｅｓｓ  ",
            primaryMuscleGroups: [.chest]
        )

        XCTAssertEqual(result, .duplicateName)
    }

    func testMutationResult_missingNameUsesSpecificAlertCopy() {
        XCTAssertEqual(ExerciseManager.MutationResult.missingName.alertTitle, "Exercise Name Required")
        XCTAssertEqual(
            ExerciseManager.MutationResult.missingName.alertMessage,
            "Enter an exercise name before saving it to your library."
        )
    }

    func testMutationResult_noPrimaryMusclesUsesSpecificAlertCopy() {
        XCTAssertEqual(ExerciseManager.MutationResult.noPrimaryMuscles.alertTitle, "Primary Muscle Required")
        XCTAssertEqual(
            ExerciseManager.MutationResult.noPrimaryMuscles.alertMessage,
            "Select at least one primary muscle group before saving this exercise."
        )
    }

    func testMutationResult_duplicateNameUsesSpecificAlertCopy() {
        XCTAssertEqual(ExerciseManager.MutationResult.duplicateName.alertTitle, "Exercise Already Exists")
        XCTAssertEqual(
            ExerciseManager.MutationResult.duplicateName.alertMessage,
            "An exercise with this name already exists. Please choose a different name."
        )
    }

    func testAddExercise_returnsValidationSpecificFailureForMissingName() {
        let result = ExerciseManager.shared.addExercise(
            name: "   ",
            category: .compound,
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [],
            instructions: ""
        )

        XCTAssertEqual(result, .missingName)
    }

    func testAddExercise_returnsValidationSpecificFailureForMissingPrimaryMuscles() {
        let result = ExerciseManager.shared.addExercise(
            name: "Bench Press",
            category: .compound,
            primaryMuscleGroups: [],
            secondaryMuscleGroups: [],
            instructions: ""
        )

        XCTAssertEqual(result, .noPrimaryMuscles)
    }

    func testMutationResult_persistenceFailureUsesRetryAlertCopy() {
        XCTAssertEqual(ExerciseManager.MutationResult.persistenceFailure.alertTitle, "Unable to Save Exercise")
        XCTAssertEqual(
            ExerciseManager.MutationResult.persistenceFailure.alertMessage,
            "Your changes could not be saved right now. Please try again."
        )
    }

    func testDeletionResult_persistenceFailureUsesRetryAlertCopy() {
        XCTAssertEqual(ExerciseManager.DeletionResult.persistenceFailure.alertTitle, "Unable to Delete Exercise")
        XCTAssertEqual(
            ExerciseManager.DeletionResult.persistenceFailure.alertMessage,
            "This exercise could not be deleted right now. Please try again."
        )
    }

    func testUpdateExercise_renamesMatchingTemplateReferences() throws {
        let context = DataManager.shared.getModelContext()
        let exercise = Exercise(
            name: "Garage Dip",
            category: .bodyweight,
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest],
            instructions: ""
        )
        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [
                TemplateExercise(
                    exerciseName: "  garage\n dip  ",
                    suggestedSets: 3,
                    repRanges: [],
                    notes: ""
                )
            ],
            notes: ""
        )

        context.insert(exercise)
        context.insert(template)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(template)
            context.delete(exercise)
            try? context.save()
        }

        let result = ExerciseManager.shared.updateExercise(
            exercise,
            name: "Ring Dip",
            category: .bodyweight,
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest],
            instructions: ""
        )

        XCTAssertEqual(result, .success)
        XCTAssertEqual(template.exercises.map(\.exerciseName), ["Ring Dip"])
        XCTAssertEqual(
            TemplateManager.shared.unavailableExerciseNames(in: template),
            [],
            "Renaming a custom exercise should not leave existing templates pointing at the stale name"
        )
    }

    func testDeletionImpact_countsLoggedDraftAndTemplateUsageSeparately() throws {
        let context = DataManager.shared.getModelContext()
        let exercise = Exercise(
            name: "Garage Dip",
            category: .bodyweight,
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest],
            instructions: "",
            isCustom: true
        )
        let loggedWorkout = Workout(name: "Logged Push", isCompleted: true)
        let draftWorkout = Workout(name: "Draft Push")
        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [
                TemplateExercise(
                    exerciseName: "Garage Dip",
                    suggestedSets: 3,
                    repRanges: [],
                    notes: ""
                )
            ],
            notes: ""
        )

        context.insert(exercise)
        context.insert(loggedWorkout)
        context.insert(draftWorkout)
        context.insert(template)
        _ = loggedWorkout.addSet(exercise: exercise, weight: 0, reps: 12, isWarmup: true)
        _ = loggedWorkout.addSet(exercise: exercise, weight: 45, reps: 8)
        _ = draftWorkout.addSet(exercise: exercise, weight: 0, reps: 0)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(template)
            context.delete(draftWorkout)
            context.delete(loggedWorkout)
            context.delete(exercise)
            try? context.save()
        }

        let impact = ExerciseManager.shared.deletionImpact(for: exercise)

        XCTAssertEqual(
            impact,
            .init(loggedSetCount: 2, loggedWorkingSetCount: 1, loggedWarmupSetCount: 1, loggedWorkoutCount: 1, draftSetCount: 1, draftWorkoutCount: 1, templateCount: 1)
        )
    }
}
