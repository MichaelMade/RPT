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

    func testFormatMetricValue_forBodyweightTruncatesAndSanitizesCorruptedValues() {
        XCTAssertEqual(
            ExerciseProgressView.formatMetricValue(1.9, metric: .topSet, exerciseCategory: .bodyweight),
            "1 rep"
        )
        XCTAssertEqual(
            ExerciseProgressView.formatMetricValue(-5, metric: .volume, exerciseCategory: .bodyweight),
            "0 reps"
        )
        XCTAssertEqual(
            ExerciseProgressView.formatMetricValue(.infinity, metric: .volume, exerciseCategory: .bodyweight),
            "0 reps"
        )
    }

    func testFormatMetricValue_forWeightedVolumeTruncatesThousandsInsteadOfRoundingUp() {
        XCTAssertEqual(
            ExerciseProgressView.formatMetricValue(1999, metric: .volume, exerciseCategory: .compound),
            "1.9k lb"
        )
    }

    func testFormatMetricValue_forWeightedVolumeSupportsMillionsWithTruncation() {
        XCTAssertEqual(
            ExerciseProgressView.formatMetricValue(1_000_000, metric: .volume, exerciseCategory: .compound),
            "1M lb"
        )
        XCTAssertEqual(
            ExerciseProgressView.formatMetricValue(1_999_999, metric: .volume, exerciseCategory: .compound),
            "1.9M lb"
        )
    }

    func testFormatMetricValue_forWeightedMetricsSanitizesCorruptedValues() {
        XCTAssertEqual(
            ExerciseProgressView.formatMetricValue(-42, metric: .topSet, exerciseCategory: .compound),
            "0 lb"
        )
        XCTAssertEqual(
            ExerciseProgressView.formatMetricValue(.nan, metric: .volume, exerciseCategory: .compound),
            "0 lb"
        )
    }

    func testFormatMetricDeltaValue_includesSignForPositiveAndNegativeChanges() {
        XCTAssertEqual(
            ExerciseProgressView.formatMetricDeltaValue(12, metric: .topSet, exerciseCategory: .compound),
            "+12 lb"
        )
        XCTAssertEqual(
            ExerciseProgressView.formatMetricDeltaValue(-12, metric: .topSet, exerciseCategory: .compound),
            "-12 lb"
        )
    }

    func testFormatMetricDeltaValue_forBodyweightUsesRepUnitsAndSign() {
        XCTAssertEqual(
            ExerciseProgressView.formatMetricDeltaValue(1.9, metric: .topSet, exerciseCategory: .bodyweight),
            "+1 rep"
        )
        XCTAssertEqual(
            ExerciseProgressView.formatMetricDeltaValue(-3.9, metric: .volume, exerciseCategory: .bodyweight),
            "-3 reps"
        )
    }

    func testDeltaTrend_classifiesPositiveNeutralAndNegativeValues() {
        XCTAssertEqual(ExerciseProgressView.deltaTrend(for: 5), .positive)
        XCTAssertEqual(ExerciseProgressView.deltaTrend(for: 0), .neutral)
        XCTAssertEqual(ExerciseProgressView.deltaTrend(for: -5), .negative)
    }

    func testDeltaTrend_treatsNonFiniteValuesAsNeutral() {
        XCTAssertEqual(ExerciseProgressView.deltaTrend(for: .infinity), .neutral)
        XCTAssertEqual(ExerciseProgressView.deltaTrend(for: .nan), .neutral)
    }
}
