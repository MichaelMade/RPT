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
}
