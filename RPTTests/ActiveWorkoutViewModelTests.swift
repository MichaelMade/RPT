//
//  ActiveWorkoutViewModelTests.swift
//  RPTTests
//
//  Core behavior of the live-workout view model: RPT back-off math,
//  warm-up ordering, and set completion semantics.
//

import XCTest
@testable import RPT

@MainActor
final class ActiveWorkoutViewModelTests: XCTestCase {
    private var originalDrops: [Double] = UserSettings.defaultRPTPercentageDrops

    override func setUp() {
        super.setUp()
        originalDrops = SettingsManager.shared.settings.defaultRPTPercentageDrops
        _ = SettingsManager.shared.updateRPTPercentageDropsSafely(drops: [0.0, 0.10, 0.15])
        WorkoutStateManager.shared.clearDiscardedState()
    }

    override func tearDown() {
        _ = SettingsManager.shared.updateRPTPercentageDropsSafely(
            drops: UserSettings.normalizedRPTPercentageDrops(originalDrops)
        )
        WorkoutStateManager.shared.clearDiscardedState()
        super.tearDown()
    }

    private func makeExercise(_ name: String = "Bench Press") -> Exercise {
        Exercise(name: name, category: .compound, primaryMuscleGroups: [.chest])
    }

    // MARK: - RPT Back-off Suggestions

    func testFirstBackoffSetDropsFromTopSet() {
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))

        // Log the top set: 200 x 5.
        let topSet = viewModel.orderedSetsForDisplay(in: exercise)[0]
        XCTAssertTrue(viewModel.updateSetSafely(topSet, weight: 200, reps: 5, rpe: nil))

        XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))

        let sets = viewModel.orderedSetsForDisplay(in: exercise)
        XCTAssertEqual(sets.count, 2)
        // 10% drop from the 200 lb top set.
        XCTAssertEqual(sets[1].weight, 180)
        // Reps progress upward from the last completed set.
        XCTAssertEqual(sets[1].reps, 7)
    }

    func testSecondBackoffDropsFromTopSetNotPreviousSet() {
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))

        let topSet = viewModel.orderedSetsForDisplay(in: exercise)[0]
        XCTAssertTrue(viewModel.updateSetSafely(topSet, weight: 200, reps: 5, rpe: nil))

        // Log a deliberately light second set; the third suggestion must
        // still anchor on the 200 lb top set, not compound off 100 lb.
        XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))
        let secondSet = viewModel.orderedSetsForDisplay(in: exercise)[1]
        XCTAssertTrue(viewModel.updateSetSafely(secondSet, weight: 100, reps: 8, rpe: nil))

        XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))

        let sets = viewModel.orderedSetsForDisplay(in: exercise)
        XCTAssertEqual(sets.count, 3)
        // 15% drop from 200 = 170, not 15% off the 100 lb second set (85).
        XCTAssertEqual(sets[2].weight, 170)
    }

    func testAddSetWithNothingLoggedMirrorsPlaceholder() {
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))
        XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))

        let sets = viewModel.orderedSetsForDisplay(in: exercise)
        XCTAssertEqual(sets.count, 2)
        XCTAssertEqual(sets[1].weight, 0)
        XCTAssertEqual(sets[1].reps, 8)
    }

    // MARK: - Drop Set Recalculation

    func testUpdateDropSetSuggestionsRecalculatesFromTopWeight() {
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))
        XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))
        XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))

        XCTAssertTrue(viewModel.updateDropSetSuggestionsSafely(for: exercise, firstSetWeight: 300))

        let sets = viewModel.orderedSetsForDisplay(in: exercise)
        XCTAssertEqual(sets.count, 3)
        XCTAssertEqual(sets[1].weight, 270, "10% drop from 300")
        XCTAssertEqual(sets[2].weight, 255, "15% drop from 300")
    }

    func testUpdateDropSetSuggestionsDoesNotLogUntouchedSets() {
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))
        XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))
        XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))

        XCTAssertTrue(viewModel.updateDropSetSuggestionsSafely(for: exercise, firstSetWeight: 300))

        let sets = viewModel.orderedSetsForDisplay(in: exercise)
        XCTAssertFalse(sets[1].isCompletedLoggedSet, "Recalculating suggestions must not log unperformed sets")
        XCTAssertFalse(sets[2].isCompletedLoggedSet, "Recalculating suggestions must not log unperformed sets")
    }

    // MARK: - Warm-up Sets

    func testWarmupSetsSortAheadOfWorkingSets() {
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))

        let topSet = viewModel.orderedSetsForDisplay(in: exercise)[0]
        XCTAssertTrue(viewModel.updateSetSafely(topSet, weight: 225, reps: 5, rpe: nil))

        // Warm-up added after the working set still displays first.
        XCTAssertTrue(viewModel.addWarmupSetSafely(to: exercise, weight: 135, reps: 5))

        let sets = viewModel.orderedSetsForDisplay(in: exercise)
        XCTAssertEqual(sets.count, 2)
        XCTAssertTrue(sets[0].isWarmup)
        XCTAssertEqual(sets[0].weight, 135)
        XCTAssertFalse(sets[1].isWarmup)
    }

    func testWarmupSetsExcludedFromBackoffMath() {
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))
        XCTAssertTrue(viewModel.addWarmupSetSafely(to: exercise, weight: 45, reps: 10))

        let topSet = viewModel.orderedSetsForDisplay(in: exercise).first { !$0.isWarmup }
        XCTAssertNotNil(topSet)
        XCTAssertTrue(viewModel.updateSetSafely(topSet!, weight: 200, reps: 5, rpe: nil))

        XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))

        let workingSets = viewModel.orderedSetsForDisplay(in: exercise).filter { !$0.isWarmup }
        XCTAssertEqual(workingSets.count, 2)
        XCTAssertEqual(workingSets[1].weight, 180, "Back-off ignores the 45 lb warm-up")
    }

    // MARK: - Set Completion Semantics

    func testUpdateSetMarksValidValuesLogged() {
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))

        let set = viewModel.orderedSetsForDisplay(in: exercise)[0]
        XCTAssertFalse(set.isCompletedLoggedSet, "Fresh sets start unlogged")

        XCTAssertTrue(viewModel.updateSetSafely(set, weight: 185, reps: 8, rpe: 9))
        XCTAssertTrue(set.isCompletedLoggedSet)
        XCTAssertEqual(set.displayRPE, 9)

        // Zeroing reps un-logs the set.
        XCTAssertTrue(viewModel.updateSetSafely(set, weight: 185, reps: 0, rpe: nil))
        XCTAssertFalse(set.isCompletedLoggedSet)
    }

    func testRejectsInvalidRPE() {
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))
        let set = viewModel.orderedSetsForDisplay(in: exercise)[0]

        XCTAssertFalse(viewModel.updateSetSafely(set, weight: 185, reps: 8, rpe: 11))
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testDuplicateExerciseRejected() {
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))
        XCTAssertFalse(viewModel.addExerciseToWorkoutSafely(exercise))
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testExerciseCompletionToggle() {
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))
        XCTAssertFalse(viewModel.allExercisesCompleted)

        viewModel.toggleExerciseCompletion(exercise)
        XCTAssertTrue(viewModel.isExerciseCompleted(exercise))
        XCTAssertTrue(viewModel.allExercisesCompleted)

        viewModel.toggleExerciseCompletion(exercise)
        XCTAssertFalse(viewModel.isExerciseCompleted(exercise))
    }

    // MARK: - Explicit Set Logging

    func testToggleSetLoggedLogsAndUnlogsSetWithCompleteValues() {
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))
        let set = viewModel.orderedSetsForDisplay(in: exercise)[0]
        XCTAssertTrue(viewModel.updateSetSafely(set, weight: 200, reps: 5, rpe: nil))
        XCTAssertTrue(set.isCompletedLoggedSet)

        XCTAssertEqual(viewModel.toggleSetLoggedSafely(set), .unlogged)
        XCTAssertFalse(set.isCompletedLoggedSet)
        XCTAssertEqual(set.weight, 200, "Unlogging must not clear the set's values")
        XCTAssertEqual(set.reps, 5, "Unlogging must not clear the set's values")

        XCTAssertEqual(viewModel.toggleSetLoggedSafely(set), .logged)
        XCTAssertTrue(set.isCompletedLoggedSet)
    }

    func testToggleSetLoggedLogsPrefilledSetWithoutValueChanges() {
        // Template-created sets arrive pre-filled but unlogged; a single
        // log tap must mark them done without editing weight or reps.
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))
        let set = viewModel.orderedSetsForDisplay(in: exercise)[0]
        set.weight = 185
        set.reps = 5
        set.completedAt = .distantPast
        XCTAssertFalse(set.isCompletedLoggedSet)

        XCTAssertEqual(viewModel.toggleSetLoggedSafely(set), .logged)
        XCTAssertTrue(set.isCompletedLoggedSet)
    }

    func testToggleSetLoggedRejectsEmptySet() {
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))
        // Placeholder set: weight 0 on a non-bodyweight exercise is incomplete.
        let set = viewModel.orderedSetsForDisplay(in: exercise)[0]

        XCTAssertEqual(viewModel.toggleSetLoggedSafely(set), .needsValues)
        XCTAssertFalse(set.isCompletedLoggedSet)
    }

    func testToggleSetLoggedAllowsBodyweightZeroWeight() {
        let exercise = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))
        let set = viewModel.orderedSetsForDisplay(in: exercise)[0]
        XCTAssertEqual(set.weight, 0)
        XCTAssertEqual(set.reps, 8)

        XCTAssertEqual(viewModel.toggleSetLoggedSafely(set), .logged)
        XCTAssertTrue(set.isCompletedLoggedSet)
    }
}
