import XCTest
@testable import RPT

final class ExerciseProgressViewTests: XCTestCase {
    func testMetricDisplayName_usesTopRepsForBodyweightTopSet() {
        XCTAssertEqual(
            ExerciseProgressView.metricDisplayName(for: .topSet, exerciseCategory: .bodyweight),
            "Top Reps"
        )
        XCTAssertEqual(
            ExerciseProgressView.metricDisplayName(for: .topSet, exerciseCategory: .compound),
            "Top Weight"
        )
    }

    func testTopSetMetricValue_forBodyweightUsesHighestReps() {
        let exercise = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])
        let sets = [
            ExerciseSet(weight: 0, reps: 8, exercise: exercise),
            ExerciseSet(weight: 0, reps: 12, exercise: exercise),
            ExerciseSet(weight: 0, reps: 10, exercise: exercise)
        ]

        XCTAssertEqual(
            ExerciseProgressView.topSetMetricValue(from: sets, exerciseCategory: .bodyweight),
            12
        )
    }

    func testTopSetMetricValue_forWeightedUsesHighestWeight() {
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let sets = [
            ExerciseSet(weight: 185, reps: 10, exercise: exercise),
            ExerciseSet(weight: 225, reps: 6, exercise: exercise),
            ExerciseSet(weight: 205, reps: 8, exercise: exercise)
        ]

        XCTAssertEqual(
            ExerciseProgressView.topSetMetricValue(from: sets, exerciseCategory: .compound),
            225
        )
    }

    func testFormatMetricValue_forBodyweightTopSetUsesRepUnits() {
        XCTAssertEqual(
            ExerciseProgressView.formatMetricValue(1, metric: .topSet, exerciseCategory: .bodyweight),
            "1 rep"
        )
        XCTAssertEqual(
            ExerciseProgressView.formatMetricValue(12, metric: .topSet, exerciseCategory: .bodyweight),
            "12 reps"
        )
    }
}
