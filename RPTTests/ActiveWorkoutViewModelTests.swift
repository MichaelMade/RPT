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
}
