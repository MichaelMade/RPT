import XCTest
@testable import RPT

@MainActor
final class ActiveWorkoutViewModelTests: XCTestCase {
    private var workoutManager: WorkoutManager!

    override func setUp() {
        super.setUp()
        workoutManager = WorkoutManager.shared
    }

    override func tearDown() {
        workoutManager = nil
        super.tearDown()
    }

    func testUpdateSet_clearingWeightResetsCompletionDate() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let set = workout.addSet(exercise: exercise, weight: 185, reps: 5)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.updateSet(set, weight: 0, reps: 5, rpe: nil)

        // Then
        XCTAssertEqual(set.completedAt, .distantPast)
    }

    func testUpdateSet_rejectsZeroRPE() {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let set = workout.addSet(exercise: exercise, weight: 185, reps: 5)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When / Then
        XCTAssertThrowsError(try viewModel.updateSet(set, weight: 185, reps: 5, rpe: 0))
    }

    func testUpdateSet_clearingRepsResetsCompletionDate() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let set = workout.addSet(exercise: exercise, weight: 185, reps: 5)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.updateSet(set, weight: 185, reps: 0, rpe: nil)

        // Then
        XCTAssertEqual(set.completedAt, .distantPast)
    }

    func testUpdateSet_marksTemplateAutofilledSetCompleteWhenSaved() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Template Workout", fromTemplate: "Push Day")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let set = workout.addSet(exercise: exercise, weight: 185, reps: 8)
        set.completedAt = .distantPast // Simulates prefilled-but-not-yet-logged template set
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.updateSet(set, weight: 185, reps: 8, rpe: nil)

        // Then
        XCTAssertNotEqual(set.completedAt, .distantPast, "Saving a valid autofilled set should mark it complete")
    }

    func testUpdateWorkoutName_trimsWhitespaceAndFallsBackWhenEmpty() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Original")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        viewModel.workoutName = "   \n\t  "
        try viewModel.updateWorkoutName()

        // Then
        XCTAssertEqual(workout.name, "Workout")
        XCTAssertEqual(viewModel.workoutName, "Workout")
    }

    func testUpdateWorkoutName_normalizesViewModelTextAfterSanitizing() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Original")
        let viewModel = ActiveWorkoutViewModel(workout: workout)
        let longMessyName = "  Upper   Body\nSession   " + String(repeating: "A", count: 100)

        // When
        viewModel.workoutName = longMessyName
        try viewModel.updateWorkoutName()

        // Then
        XCTAssertEqual(viewModel.workoutName, workout.name)
        XCTAssertEqual(viewModel.workoutName, workoutManager.sanitizedWorkoutName(longMessyName))
        XCTAssertEqual(viewModel.workoutName.count, 80)
        XCTAssertFalse(viewModel.workoutName.contains("\n"))
        XCTAssertFalse(viewModel.workoutName.contains("  "))
    }

    func testAddExerciseToWorkout_createsIncompleteStarterSet() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Overhead Press", category: .compound, primaryMuscleGroups: [.shoulders])
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.addExerciseToWorkout(exercise)

        // Then
        let createdSet = workout.sets.first { $0.exercise?.id == exercise.id }
        XCTAssertNotNil(createdSet)
        XCTAssertEqual(createdSet?.completedAt, .distantPast, "New starter set should begin incomplete")
    }

    func testAddExerciseToWorkout_rejectsDuplicateExerciseSelection() throws {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Overhead Press", category: .compound, primaryMuscleGroups: [.shoulders])
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        try viewModel.addExerciseToWorkout(exercise)

        XCTAssertThrowsError(try viewModel.addExerciseToWorkout(exercise)) { error in
            XCTAssertEqual(
                error as? ActiveWorkoutViewModel.WorkoutError,
                .duplicateExercise,
                "Selecting an exercise that is already in the workout should be rejected instead of silently adding a surprise extra set"
            )
        }
        XCTAssertEqual(
            workout.sets.filter { $0.exercise?.id == exercise.id }.count,
            1,
            "Duplicate exercise selection should leave the workout with its original starter set only"
        )
    }

    func testAddSetToExercise_keepsAutoSuggestedSetIncomplete() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let existingSet = workout.addSet(exercise: exercise, weight: 225, reps: 5)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.addSetToExercise(exercise)

        // Then
        let addedSet = workout.sets.first { $0.id != existingSet.id && $0.exercise?.id == exercise.id }
        XCTAssertNotNil(addedSet)
        XCTAssertEqual(addedSet?.completedAt, .distantPast, "Auto-suggested set should not be marked complete until user logs it")
    }

    func testAddSetToExercise_usesLastSetNumberNotLatestCompletionTimestamp() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        let firstSet = workout.addSet(exercise: exercise, weight: 225, reps: 8)
        let secondSet = workout.addSet(exercise: exercise, weight: 205, reps: 10)

        // Simulate out-of-order completion timestamps from edits.
        firstSet.completedAt = Date().addingTimeInterval(120)
        secondSet.completedAt = Date().addingTimeInterval(-120)

        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.addSetToExercise(exercise)

        // Then
        let addedSet = workout.sets.first {
            $0.id != firstSet.id && $0.id != secondSet.id && $0.exercise?.id == exercise.id
        }
        XCTAssertNotNil(addedSet)
        XCTAssertEqual(addedSet?.reps, 12, "Progression should use the most recently added set number, not completion time")
    }

    func testAddSetToExercise_warmupDoesNotShiftWorkingSetDropProgression() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: exercise, weight: 135, reps: 8, isWarmup: true)
        let workingSet = workout.addSet(exercise: exercise, weight: 200, reps: 6)

        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.addSetToExercise(exercise)

        // Then
        let addedSet = workout.sets.first {
            $0.id != workingSet.id && $0.exercise?.id == exercise.id && !$0.isWarmup
        }
        XCTAssertNotNil(addedSet)
        XCTAssertEqual(addedSet?.weight, 180, "Warmup sets should not shift working-set drop progression")
        XCTAssertEqual(addedSet?.reps, 8, "Working-set progression should build from the last completed working set")
    }

    func testAddSetToExercise_keepsDefaultRepsWhenLastSetRepsAreZero() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = workout.addSet(exercise: exercise, weight: 200, reps: 0)

        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.addSetToExercise(exercise)

        // Then
        let addedSet = workout.sets.last { $0.exercise?.id == exercise.id }
        XCTAssertEqual(addedSet?.reps, 8, "Zero-rep seed sets should keep default starter reps instead of dropping to 2 reps")
    }

    func testAddSetToExercise_keepsDefaultRepsWhenLastSetRepsAreCorruptedNegative() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let corruptedSet = workout.addSet(exercise: exercise, weight: 200, reps: 6)
        corruptedSet.reps = -4

        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.addSetToExercise(exercise)

        // Then
        let addedSet = workout.sets.last { $0.exercise?.id == exercise.id }
        XCTAssertEqual(addedSet?.reps, 8, "Corrupted negative reps should not collapse suggestions below default starter reps")
    }

    func testAddSetToExercise_clampsCorruptedNegativeLastWeightToSafeSuggestion() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let corruptedSet = workout.addSet(exercise: exercise, weight: 185, reps: 6)
        corruptedSet.weight = -185

        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.addSetToExercise(exercise)

        // Then
        let addedSet = workout.sets.last { $0.id != corruptedSet.id && $0.exercise?.id == exercise.id }
        XCTAssertEqual(addedSet?.weight, 0, "Corrupted negative previous weight should never produce negative auto-suggested weights")
    }

    func testViewModelPreservesExerciseInsertionOrderWhenTimestampsMatch() {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        let squatSet = workout.addSet(exercise: squat, weight: 0, reps: 8)
        let benchSet = workout.addSet(exercise: bench, weight: 0, reps: 8)
        squatSet.completedAt = .distantPast
        benchSet.completedAt = .distantPast

        // When
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // Then
        XCTAssertEqual(viewModel.exerciseOrder.map(\.name), ["Squat", "Bench Press"])
    }

    func testOrderedSetsForDisplay_prefersInsertionOrderOverCompletionTimestamp() {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        let firstSet = workout.addSet(exercise: exercise, weight: 225, reps: 8)
        let secondSet = workout.addSet(exercise: exercise, weight: 205, reps: 10)

        // Simulate out-of-order timestamps from edits.
        firstSet.completedAt = Date().addingTimeInterval(120)
        secondSet.completedAt = Date().addingTimeInterval(-120)

        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        let orderedSets = viewModel.orderedSetsForDisplay(in: exercise)

        // Then
        XCTAssertEqual(orderedSets.map(\.id), [firstSet.id, secondSet.id])
    }

    func testTemplateAutofill_usesCompletedWorkingSetNotWarmup() {
        // Given
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let priorWorkout = workoutManager.createWorkout(name: "Prior Workout")
        _ = priorWorkout.addSet(exercise: exercise, weight: 45, reps: 12, isWarmup: true)
        _ = priorWorkout.addSet(exercise: exercise, weight: 205, reps: 6)

        let templateWorkout = workoutManager.createWorkout(name: "Template Workout", fromTemplate: "Push Day")
        _ = templateWorkout.addSet(exercise: exercise, weight: 0, reps: 8)

        // When
        _ = ActiveWorkoutViewModel(workout: templateWorkout)

        // Then
        let autofilledSet = templateWorkout.sets.first { $0.exercise?.id == exercise.id }
        XCTAssertEqual(autofilledSet?.weight, 205, "Autofill should ignore warmups and use prior completed working sets")
        XCTAssertEqual(autofilledSet?.reps, 8, "Template-set target reps should remain unchanged when already configured")
    }

    func testTemplateAutofill_ignoresIncompleteRecentWorkout() {
        // Given
        let exercise = Exercise(name: "Incline Bench", category: .compound, primaryMuscleGroups: [.chest])

        let completedWorkout = workoutManager.createWorkout(name: "Completed Workout")
        _ = completedWorkout.addSet(exercise: exercise, weight: 200, reps: 6)
        completedWorkout.isCompleted = true

        let newerIncompleteWorkout = workoutManager.createWorkout(name: "In Progress")
        _ = newerIncompleteWorkout.addSet(exercise: exercise, weight: 235, reps: 4)

        let templateWorkout = workoutManager.createWorkout(name: "Template Workout", fromTemplate: "Push Day")
        _ = templateWorkout.addSet(exercise: exercise, weight: 0, reps: 8)

        // When
        _ = ActiveWorkoutViewModel(workout: templateWorkout)

        // Then
        let autofilledSet = templateWorkout.sets.first { $0.exercise?.id == exercise.id }
        XCTAssertEqual(autofilledSet?.weight, 200, "Autofill should ignore newer in-progress workouts and use the most recent completed workout")
    }

    func testShouldStartRestTimer_requiresCompletedWorkingSet() {
        XCTAssertTrue(ExerciseSetRowView.shouldStartRestTimer(weight: 225, reps: 5, isWarmup: false, wasCompletedWorkingSet: false))
        XCTAssertFalse(ExerciseSetRowView.shouldStartRestTimer(weight: 225, reps: 0, isWarmup: false, wasCompletedWorkingSet: false))
        XCTAssertFalse(ExerciseSetRowView.shouldStartRestTimer(weight: 0, reps: 5, isWarmup: false, wasCompletedWorkingSet: false))
        XCTAssertTrue(ExerciseSetRowView.shouldStartRestTimer(weight: 0, reps: 5, isWarmup: false, exerciseCategory: .bodyweight, wasCompletedWorkingSet: false))
        XCTAssertFalse(ExerciseSetRowView.shouldStartRestTimer(weight: 225, reps: 5, isWarmup: true, wasCompletedWorkingSet: false))
    }

    func testShouldStartRestTimer_doesNotRestartWhenSetWasAlreadyCompleted() {
        XCTAssertFalse(ExerciseSetRowView.shouldStartRestTimer(weight: 225, reps: 5, isWarmup: false, wasCompletedWorkingSet: true))
    }

    func testShouldUpdateDropSets_requiresCompletedNonWarmupFirstSet() {
        XCTAssertTrue(ExerciseSetRowView.shouldUpdateDropSets(weight: 225, reps: 5, isWarmup: false))
        XCTAssertFalse(ExerciseSetRowView.shouldUpdateDropSets(weight: 225, reps: 0, isWarmup: false))
        XCTAssertFalse(ExerciseSetRowView.shouldUpdateDropSets(weight: 0, reps: 5, isWarmup: false))
        XCTAssertTrue(ExerciseSetRowView.shouldUpdateDropSets(weight: 0, reps: 5, isWarmup: false, exerciseCategory: .bodyweight))
        XCTAssertFalse(ExerciseSetRowView.shouldUpdateDropSets(weight: 225, reps: 5, isWarmup: true))
    }

    func testExerciseSetDraftValidation_allowsBlankWeightAndRepsToClearSet() {
        XCTAssertEqual(
            ExerciseSetRowView.validateDraft(weightInput: "", repsInput: "  ", rpeInput: ""),
            .valid
        )
    }

    func testExerciseSetDraftValidation_rejectsInvalidNumericInputs() {
        XCTAssertEqual(
            ExerciseSetRowView.validateDraft(weightInput: "abc", repsInput: "5", rpeInput: ""),
            .invalidWeight
        )
        XCTAssertEqual(
            ExerciseSetRowView.validateDraft(weightInput: "185", repsInput: "five", rpeInput: ""),
            .invalidReps
        )
        XCTAssertEqual(
            ExerciseSetRowView.validateDraft(weightInput: "185", repsInput: "5", rpeInput: "11"),
            .invalidRPE
        )
    }

    func testExerciseSetSanitizedInteger_treatsBlankAsExplicitEmptyValue() {
        XCTAssertEqual(ExerciseSetRowView.sanitizedInteger(from: "   ", emptyValue: 0), 0)
        XCTAssertNil(ExerciseSetRowView.sanitizedInteger(from: "", emptyValue: nil))
        XCTAssertEqual(ExerciseSetRowView.sanitizedInteger(from: " 12 ", emptyValue: 0), 12)
        XCTAssertNil(ExerciseSetRowView.sanitizedInteger(from: "-3", emptyValue: 0))
    }

    func testFinishHelperText_whenAllExercisesCompleted_returnsNil() {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Row", category: .compound, primaryMuscleGroups: [.lats])
        _ = workout.addSet(exercise: bench, weight: 185, reps: 6)
        _ = workout.addSet(exercise: row, weight: 155, reps: 8)

        let viewModel = ActiveWorkoutViewModel(workout: workout)
        viewModel.toggleExerciseCompletion(bench)
        viewModel.toggleExerciseCompletion(row)

        XCTAssertNil(viewModel.finishHelperText)
    }

    func testFinishHelperText_whenOneExerciseRemains_mentionsExerciseName() {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Row", category: .compound, primaryMuscleGroups: [.lats])
        _ = workout.addSet(exercise: bench, weight: 185, reps: 6)
        _ = workout.addSet(exercise: row, weight: 155, reps: 8)

        let viewModel = ActiveWorkoutViewModel(workout: workout)
        viewModel.toggleExerciseCompletion(bench)

        XCTAssertEqual(
            viewModel.finishHelperText,
            "1 exercise left: Row. Tap the circle beside it when you're done to enable Finish."
        )
    }

    func testFinishHelperText_whenSeveralExercisesRemain_summarizesCountAndPreviewNames() {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Row", category: .compound, primaryMuscleGroups: [.lats])
        _ = workout.addSet(exercise: squat, weight: 225, reps: 5)
        _ = workout.addSet(exercise: bench, weight: 185, reps: 6)
        _ = workout.addSet(exercise: row, weight: 155, reps: 8)

        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(
            viewModel.finishHelperText,
            "3 exercises left: Squat, Bench Press, +1 more. Tap each circle when you're done to enable Finish."
        )
    }

    func testExitDialogHelperText_whenAllExercisesCompleted_usesCompletionMessaging() {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = workout.addSet(exercise: bench, weight: 185, reps: 6)

        let viewModel = ActiveWorkoutViewModel(workout: workout)
        viewModel.toggleExerciseCompletion(bench)

        XCTAssertEqual(
            viewModel.exitDialogHelperText,
            "Save for later keeps it as a draft. Complete marks it as finished."
        )
        XCTAssertTrue(viewModel.canCompleteWorkoutFromExitDialog)
    }

    func testExitDialogHelperText_whenExercisesRemain_explainsWhyCompleteIsUnavailable() {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Row", category: .compound, primaryMuscleGroups: [.lats])
        _ = workout.addSet(exercise: bench, weight: 185, reps: 6)
        _ = workout.addSet(exercise: row, weight: 155, reps: 8)

        let viewModel = ActiveWorkoutViewModel(workout: workout)
        viewModel.toggleExerciseCompletion(bench)

        XCTAssertEqual(
            viewModel.exitDialogHelperText,
            "1 exercise left: Row. Tap the circle beside it when you're done to enable Complete Workout."
        )
        XCTAssertFalse(viewModel.canCompleteWorkoutFromExitDialog)
    }

    func testDeleteSet_removesSetFromExerciseRelationship() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let set = workout.addSet(exercise: exercise, weight: 185, reps: 6)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.deleteSet(set)

        // Then
        XCTAssertFalse(workout.sets.contains(where: { $0.id == set.id }))
        XCTAssertFalse(exercise.sets.contains(where: { $0.id == set.id }), "Deleting from active workout should also remove the set from exercise history links")
    }

    func testDeleteExerciseFromWorkout_removesLinkedExerciseSets() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let targetExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let keepExercise = Exercise(name: "Row", category: .compound, primaryMuscleGroups: [.lats])

        let targetSet1 = workout.addSet(exercise: targetExercise, weight: 185, reps: 6)
        let targetSet2 = workout.addSet(exercise: targetExercise, weight: 170, reps: 8)
        _ = workout.addSet(exercise: keepExercise, weight: 155, reps: 10)

        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.deleteExerciseFromWorkout(targetExercise)

        // Then
        XCTAssertFalse(workout.sets.contains(where: { $0.exercise?.id == targetExercise.id }))
        XCTAssertFalse(targetExercise.sets.contains(where: { $0.id == targetSet1.id || $0.id == targetSet2.id }), "Deleting an exercise from workout should delete its linked ExerciseSet records")
        XCTAssertTrue(workout.sets.contains(where: { $0.exercise?.id == keepExercise.id }), "Deleting one exercise should not remove unrelated exercise sets")
    }
}
