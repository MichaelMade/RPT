import XCTest
@testable import RPT

final class ExerciseProgressViewTests: XCTestCase {
    func testAvailableMetrics_forBodyweightHidesEstimatedOneRM() {
        XCTAssertEqual(
            ExerciseProgressView.availableMetrics(for: .bodyweight),
            [.topSet, .volume]
        )
        XCTAssertEqual(
            ExerciseProgressView.availableMetrics(for: .compound),
            ExerciseProgressView.Metric.allCases
        )
    }

    func testMetricDisplayName_usesBodyweightSpecificMetricNames() {
        XCTAssertEqual(
            ExerciseProgressView.metricDisplayName(for: .topSet, exerciseCategory: .bodyweight),
            "Top Reps"
        )
        XCTAssertEqual(
            ExerciseProgressView.metricDisplayName(for: .volume, exerciseCategory: .bodyweight),
            "Total Reps"
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

    func testVolumeMetricValue_forBodyweightUsesTotalReps() {
        let exercise = Exercise(name: "Push-up", category: .bodyweight, primaryMuscleGroups: [.chest])
        let sets = [
            ExerciseSet(weight: 0, reps: 12, exercise: exercise),
            ExerciseSet(weight: 0, reps: 10, exercise: exercise),
            ExerciseSet(weight: 0, reps: 8, exercise: exercise)
        ]

        XCTAssertEqual(
            ExerciseProgressView.volumeMetricValue(from: sets, exerciseCategory: .bodyweight),
            30
        )
    }

    func testFormatMetricValue_forBodyweightUsesRepUnitsForTopSetAndVolume() {
        XCTAssertEqual(
            ExerciseProgressView.formatMetricValue(1, metric: .topSet, exerciseCategory: .bodyweight),
            "1 rep"
        )
        XCTAssertEqual(
            ExerciseProgressView.formatMetricValue(12, metric: .topSet, exerciseCategory: .bodyweight),
            "12 reps"
        )
        XCTAssertEqual(
            ExerciseProgressView.formatMetricValue(15, metric: .volume, exerciseCategory: .bodyweight),
            "15 reps"
        )
    }
}
