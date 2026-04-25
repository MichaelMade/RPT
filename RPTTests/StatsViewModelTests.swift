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

    func testIsBetterPRCandidate_prefersMoreRecentSetWhenWeightAndRepsTie() {
        let existing = StatsViewModel.PersonalRecord(
            exerciseName: "Bench Press",
            weight: 225,
            reps: 5,
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

        XCTAssertTrue(
            viewModel.isBetterPRCandidate(candidate, than: existing),
            "Equal PR candidates should prefer the most recent set"
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
}
