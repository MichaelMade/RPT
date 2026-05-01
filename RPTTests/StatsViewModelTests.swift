import XCTest
@testable import RPT

@MainActor
final class StatsViewModelTests: XCTestCase {
    private var viewModel: StatsViewModel!
    private var exercise: Exercise!
    private var workout: Workout!

    override func setUp() {
        super.setUp()
        viewModel = StatsViewModel()
        exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        workout = Workout(name: "Test Workout")
    }

    override func tearDown() {
        viewModel = nil
        exercise = nil
        workout = nil
        super.tearDown()
    }

    func testIsBetterPRCandidate_prefersHigherRepsWhenWeightTies() {
        let existing = StatsViewModel.PersonalRecord(
            exerciseName: "Bench Press",
            weight: 225,
            reps: 5,
            date: Date(timeIntervalSince1970: 100)
        )

        let candidate = ExerciseSet(
            weight: 225,
            reps: 7,
            exercise: exercise,
            workout: workout,
            completedAt: Date(timeIntervalSince1970: 90),
            isWarmup: false
        )

        XCTAssertTrue(
            viewModel.isBetterPRCandidate(candidate, than: existing),
            "Equal-weight PR candidates should prefer higher reps"
        )
    }

    func testIsBetterPRCandidate_prefersMoreRecentWorkoutWhenWeightAndRepsTie() {
        let existing = StatsViewModel.PersonalRecord(
            exerciseName: "Bench Press",
            weight: 225,
            reps: 5,
            date: Date(timeIntervalSince1970: 100)
        )

        let candidateWorkout = Workout(
            date: Date(timeIntervalSince1970: 200),
            name: "Newer Workout",
            isCompleted: true
        )
        let candidate = ExerciseSet(
            weight: 225,
            reps: 5,
            exercise: exercise,
            workout: candidateWorkout,
            completedAt: Date(timeIntervalSince1970: 50),
            isWarmup: false
        )

        XCTAssertTrue(
            viewModel.isBetterPRCandidate(candidate, than: existing),
            "Equal PR candidates should prefer the most recent workout date even if a set timestamp is stale"
        )
    }

    func testIsBetterPRCandidate_rejectsLowerRepsWhenWeightTies() {
        let existing = StatsViewModel.PersonalRecord(
            exerciseName: "Bench Press",
            weight: 225,
            reps: 6,
            date: Date(timeIntervalSince1970: 100)
        )

        let candidate = ExerciseSet(
            weight: 225,
            reps: 5,
            exercise: exercise,
            workout: workout,
            completedAt: Date(timeIntervalSince1970: 200),
            isWarmup: false
        )

        XCTAssertFalse(
            viewModel.isBetterPRCandidate(candidate, than: existing),
            "Lower-rep ties should not replace an existing PR"
        )
    }

    func testPersonalRecordFormattedWeightReps_usesBodyweightLabelForZeroWeightBodyweightPR() {
        let bodyweightPR = StatsViewModel.PersonalRecord(
            exerciseName: "Pull-up",
            weight: 0,
            reps: 12,
            date: Date(),
            exerciseCategory: .bodyweight
        )

        let weightedPR = StatsViewModel.PersonalRecord(
            exerciseName: "Dip",
            weight: 45,
            reps: 8,
            date: Date(),
            exerciseCategory: .bodyweight
        )

        XCTAssertEqual(bodyweightPR.formattedWeightReps, "BW × 12 reps")
        XCTAssertEqual(weightedPR.formattedWeightReps, "45 lb × 8 reps")
    }

    func testPRReferenceDate_prefersWorkoutDateOverCorruptedSetTimestamp() {
        let workoutDate = Date(timeIntervalSince1970: 2_000)
        let set = ExerciseSet(
            weight: 225,
            reps: 5,
            exercise: exercise,
            workout: Workout(date: workoutDate, name: "Workout", isCompleted: true),
            completedAt: Date(timeIntervalSince1970: 100),
            isWarmup: false
        )

        XCTAssertEqual(
            viewModel.prReferenceDate(for: set),
            workoutDate,
            "PR cards should use the workout date as the canonical recency/date signal"
        )
    }

    func testNormalizedPRExerciseName_collapsesWhitespaceAndNormalizesLookupKey() {
        let normalized = viewModel.normalizedPRExerciseName("  Bench   Press\n")
        let variant = viewModel.normalizedPRExerciseName("bench press")

        XCTAssertEqual(normalized?.display, "Bench Press")
        XCTAssertEqual(normalized?.key, variant?.key)
    }

    func testNormalizedPRExerciseName_returnsNilForWhitespaceOnlyNames() {
        XCTAssertNil(viewModel.normalizedPRExerciseName("  \n\t  "))
    }

    func testSanitizedVolume_clampsCorruptedValuesToZero() {
        XCTAssertEqual(viewModel.sanitizedVolume(-10), 0)
        XCTAssertEqual(viewModel.sanitizedVolume(.infinity), 0)
        XCTAssertEqual(viewModel.sanitizedVolume(.nan), 0)
    }

    func testSanitizedVolume_preservesFinitePositiveValues() {
        XCTAssertEqual(viewModel.sanitizedVolume(1234.5), 1234.5)
    }

    func testWeeklyWorkMetric_prefersVolumeWhenWeightedWorkExists() {
        XCTAssertEqual(
            viewModel.weeklyWorkMetricTitle(
                weeklyWorkoutCount: 2,
                totalVolume: 1200,
                totalBodyweightReps: 40
            ),
            "Volume"
        )
        XCTAssertEqual(
            viewModel.weeklyWorkMetricValue(
                weeklyWorkoutCount: 2,
                formattedVolume: "1.2k lb",
                totalBodyweightReps: 40
            ),
            "1.2k lb"
        )
        XCTAssertEqual(
            viewModel.weeklyWorkMetricSubtitle(
                weeklyWorkoutCount: 2,
                totalVolume: 1200,
                totalBodyweightReps: 40
            ),
            "lifted"
        )
    }

    func testWeeklyWorkMetric_fallsBackToBodyweightRepsWhenVolumeIsZero() {
        XCTAssertEqual(
            viewModel.weeklyWorkMetricTitle(
                weeklyWorkoutCount: 2,
                totalVolume: 0,
                totalBodyweightReps: 32
            ),
            "Reps"
        )
        XCTAssertEqual(
            viewModel.weeklyWorkMetricValue(
                weeklyWorkoutCount: 2,
                formattedVolume: "0 lb",
                totalBodyweightReps: 32
            ),
            "32"
        )
        XCTAssertEqual(
            viewModel.weeklyWorkMetricSubtitle(
                weeklyWorkoutCount: 2,
                totalVolume: 0,
                totalBodyweightReps: 32
            ),
            "bodyweight"
        )
    }

    func testWeeklyWorkMetric_usesNeutralWorkLabelWhenNoRecentWorkExists() {
        XCTAssertEqual(
            viewModel.weeklyWorkMetricTitle(
                weeklyWorkoutCount: 0,
                totalVolume: 0,
                totalBodyweightReps: 0
            ),
            "Work"
        )
        XCTAssertEqual(
            viewModel.weeklyWorkMetricValue(
                weeklyWorkoutCount: 0,
                formattedVolume: "0 lb",
                totalBodyweightReps: 0
            ),
            "—"
        )
        XCTAssertEqual(
            viewModel.weeklyWorkMetricSubtitle(
                weeklyWorkoutCount: 0,
                totalVolume: 0,
                totalBodyweightReps: 0
            ),
            "last 7 days"
        )
    }
}
