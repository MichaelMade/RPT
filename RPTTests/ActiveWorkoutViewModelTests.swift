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

    func testShouldStartRestTimer_requiresCompletedWorkingSet() {
        XCTAssertTrue(ExerciseSetRowView.shouldStartRestTimer(weight: 225, reps: 5, isWarmup: false, wasCompletedWorkingSet: false))
        XCTAssertFalse(ExerciseSetRowView.shouldStartRestTimer(weight: 225, reps: 0, isWarmup: false, wasCompletedWorkingSet: false))
        XCTAssertFalse(ExerciseSetRowView.shouldStartRestTimer(weight: 0, reps: 5, isWarmup: false, wasCompletedWorkingSet: false))
        XCTAssertFalse(ExerciseSetRowView.shouldStartRestTimer(weight: 225, reps: 5, isWarmup: true, wasCompletedWorkingSet: false))
    }

    func testShouldStartRestTimer_doesNotRestartWhenSetWasAlreadyCompleted() {
        XCTAssertFalse(ExerciseSetRowView.shouldStartRestTimer(weight: 225, reps: 5, isWarmup: false, wasCompletedWorkingSet: true))
    }
}
