//
//  ActiveWorkoutViewModelTests.swift
//  RPTTests
//
//  Core behavior of the live-workout view model: RPT back-off math,
//  warm-up ordering, and set completion semantics.
//

import XCTest
import SwiftData
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

        // Log the top set: 200 x 5 (logging is explicit).
        let topSet = viewModel.orderedSetsForDisplay(in: exercise)[0]
        XCTAssertTrue(viewModel.updateSetSafely(topSet, weight: 200, reps: 5, rpe: nil))
        XCTAssertEqual(viewModel.toggleSetLoggedSafely(topSet), .logged)

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
        XCTAssertEqual(viewModel.toggleSetLoggedSafely(topSet), .logged)

        // Log a deliberately light second set; the third suggestion must
        // still anchor on the 200 lb top set, not compound off 100 lb.
        XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))
        let secondSet = viewModel.orderedSetsForDisplay(in: exercise)[1]
        XCTAssertTrue(viewModel.updateSetSafely(secondSet, weight: 100, reps: 8, rpe: nil))
        XCTAssertEqual(viewModel.toggleSetLoggedSafely(secondSet), .logged)

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

    func testUpdateDropSetSuggestionsLeavesLoggedBackoffsAlone() {
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))
        XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))
        XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))

        var sets = viewModel.orderedSetsForDisplay(in: exercise)
        XCTAssertTrue(viewModel.updateSetSafely(sets[0], weight: 185, reps: 6, rpe: nil))
        XCTAssertEqual(viewModel.toggleSetLoggedSafely(sets[0]), .logged)

        // The first back-off was lifted heavier than suggested, and logged.
        XCTAssertTrue(viewModel.updateSetSafely(sets[1], weight: 170, reps: 8, rpe: nil))
        XCTAssertEqual(viewModel.toggleSetLoggedSafely(sets[1]), .logged)

        // The second back-off is still only a plan.
        XCTAssertTrue(viewModel.updateSetSafely(sets[2], weight: 150, reps: 8, rpe: nil))

        XCTAssertTrue(viewModel.updateDropSetSuggestionsSafely(for: exercise, firstSetWeight: 200))

        sets = viewModel.orderedSetsForDisplay(in: exercise)
        XCTAssertEqual(sets[1].weight, 170, "A logged back-off keeps the load that was actually lifted")
        XCTAssertTrue(sets[1].isCompletedLoggedSet)
        XCTAssertEqual(sets[2].weight, 170, "A planned back-off still follows the top set: 15% off 200")
        XCTAssertFalse(sets[2].isCompletedLoggedSet)
    }

    // MARK: - Template Autofill

    @MainActor
    private struct IsolatedStore {
        let dataManager: DataManager
        let workoutManager: WorkoutManager
        let exerciseManager: ExerciseManager

        var context: ModelContext { dataManager.getModelContext() }

        func makeViewModel(for workout: Workout) -> ActiveWorkoutViewModel {
            ActiveWorkoutViewModel(
                workout: workout,
                workoutManager: workoutManager,
                exerciseManager: exerciseManager
            )
        }
    }

    /// Template autofill reads prior sessions from the store, so these tests
    /// run against their own in-memory container rather than the app's.
    private func makeIsolatedStore() -> IsolatedStore {
        let dataManager = DataManager(
            containerFactory: { schema, _ in
                let configuration = ModelConfiguration(
                    isStoredInMemoryOnly: true,
                    allowsSave: true
                )
                return try ModelContainer(for: schema, configurations: configuration)
            },
            seedDefaultData: false
        )

        return IsolatedStore(
            dataManager: dataManager,
            workoutManager: WorkoutManager(dataManager: dataManager),
            exerciseManager: ExerciseManager(dataManager: dataManager)
        )
    }

    /// Inserts a completed 185 / 165 / 155 bench session from a week ago.
    private func insertLastWeeksBenchSession(for bench: Exercise, in store: IsolatedStore) throws -> Workout {
        let lastWeek = Workout(
            date: Date(timeIntervalSinceNow: -7 * 24 * 60 * 60),
            name: "Bench Day",
            startedFromTemplate: "Bench Day"
        )
        store.context.insert(lastWeek)

        for (weight, rpe) in [(185, 9), (165, 8), (155, 8)] {
            _ = lastWeek.addSet(exercise: bench, weight: weight, reps: 8, rpe: rpe)
        }
        lastWeek.isCompleted = true

        try store.context.save()
        return lastWeek
    }

    /// Inserts a fresh template-origin workout with three empty working sets.
    private func insertTodaysTemplateWorkout(for bench: Exercise, in store: IsolatedStore) throws -> Workout {
        let today = Workout(name: "Bench Day", startedFromTemplate: "Bench Day")
        store.context.insert(today)

        for _ in 0..<3 {
            let plannedSet = today.addSet(exercise: bench, weight: 0, reps: 8)
            plannedSet.completedAt = .distantPast
        }

        try store.context.save()
        return today
    }

    func testTemplateWorkoutPrefillsWeightsButNotRPEFromLastSession() throws {
        let store = makeIsolatedStore()
        let bench = makeExercise()
        store.context.insert(bench)
        _ = try insertLastWeeksBenchSession(for: bench, in: store)
        let today = try insertTodaysTemplateWorkout(for: bench, in: store)

        let viewModel = store.makeViewModel(for: today)
        let sets = viewModel.orderedSetsForDisplay(in: bench)

        XCTAssertEqual(sets.map(\.weight), [185, 165, 155], "First open pre-fills from the last session")
        XCTAssertEqual(sets.map(\.reps), [8, 8, 8], "Template rep targets are kept")
        XCTAssertTrue(sets.allSatisfy { $0.rpe == nil }, "RPE belongs to a performed set and is never pre-filled")
        XCTAssertTrue(sets.allSatisfy { !$0.isCompletedLoggedSet }, "Pre-filling never logs a set")
    }

    func testReopeningTemplateWorkoutKeepsEditedAndLoggedValues() throws {
        let store = makeIsolatedStore()
        let bench = makeExercise()
        store.context.insert(bench)
        _ = try insertLastWeeksBenchSession(for: bench, in: store)
        let today = try insertTodaysTemplateWorkout(for: bench, in: store)

        let firstOpen = store.makeViewModel(for: today)
        var sets = firstOpen.orderedSetsForDisplay(in: bench)
        XCTAssertEqual(sets.map(\.weight), [185, 165, 155])

        // Go heavier than last week, log the top set, adjust a back-off,
        // and add a warm-up.
        XCTAssertTrue(firstOpen.updateSetSafely(sets[0], weight: 190, reps: 8, rpe: 8))
        XCTAssertEqual(firstOpen.toggleSetLoggedSafely(sets[0]), .logged)
        XCTAssertTrue(firstOpen.updateSetSafely(sets[1], weight: 170, reps: 8, rpe: nil))
        XCTAssertTrue(firstOpen.addWarmupSetSafely(to: bench, weight: 95, reps: 5))

        // "Save for later" then "Continue" (or a relaunch) builds a brand
        // new view model on the same workout.
        let reopened = store.makeViewModel(for: today)
        sets = reopened.orderedSetsForDisplay(in: bench)

        XCTAssertEqual(sets.count, 4)
        XCTAssertTrue(sets[0].isWarmup)
        XCTAssertEqual(sets[0].weight, 95, "A warm-up must not receive last week's top-set weight")
        XCTAssertEqual(sets[1].weight, 190, "A logged set keeps the weight that was lifted")
        XCTAssertEqual(sets[1].rpe, 8, "A logged set keeps its own RPE")
        XCTAssertTrue(sets[1].isCompletedLoggedSet)
        XCTAssertEqual(sets[2].weight, 170, "An edited back-off keeps the lifter's number")
        XCTAssertEqual(sets[3].weight, 155)
        XCTAssertNil(reopened.errorMessage)
    }

    func testFollowUpFromTemplateSessionKeepsItsProgressedWeights() throws {
        let store = makeIsolatedStore()
        let bench = makeExercise()
        store.context.insert(bench)
        let lastWeek = try insertLastWeeksBenchSession(for: bench, in: store)

        let followUp = try XCTUnwrap(store.workoutManager.createFollowUpWorkoutSafely(from: lastWeek))
        XCTAssertNotNil(followUp.startedFromTemplate, "Sanity check: the follow-up inherits the template origin")

        let viewModel = store.makeViewModel(for: followUp)

        XCTAssertEqual(
            viewModel.orderedSetsForDisplay(in: bench).map(\.weight),
            [190, 170, 160],
            "Opening a follow-up must not swap its progressed loads back to last session's"
        )
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
        XCTAssertEqual(viewModel.toggleSetLoggedSafely(topSet!), .logged)

        XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))

        let workingSets = viewModel.orderedSetsForDisplay(in: exercise).filter { !$0.isWarmup }
        XCTAssertEqual(workingSets.count, 2)
        XCTAssertEqual(workingSets[1].weight, 180, "Back-off ignores the 45 lb warm-up")
    }

    // MARK: - Set Completion Semantics

    func testUpdateSetNeverImplicitlyLogs() {
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))

        let set = viewModel.orderedSetsForDisplay(in: exercise)[0]
        XCTAssertFalse(set.isCompletedLoggedSet, "Fresh sets start unlogged")

        // Entering valid values does NOT log — logging is the explicit toggle.
        XCTAssertTrue(viewModel.updateSetSafely(set, weight: 185, reps: 8, rpe: 9))
        XCTAssertFalse(set.isCompletedLoggedSet, "Value edits must not log a set")
        XCTAssertEqual(set.displayRPE, 9)

        XCTAssertEqual(viewModel.toggleSetLoggedSafely(set), .logged)
        XCTAssertTrue(set.isCompletedLoggedSet)

        // Editing values on a logged set keeps it logged...
        XCTAssertTrue(viewModel.updateSetSafely(set, weight: 190, reps: 7, rpe: 9))
        XCTAssertTrue(set.isCompletedLoggedSet, "Valid edits keep the logged state")

        // ...but invalidating its values force-unlogs it.
        XCTAssertTrue(viewModel.updateSetSafely(set, weight: 190, reps: 0, rpe: nil))
        XCTAssertFalse(set.isCompletedLoggedSet, "A logged set must stay valid")
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
        XCTAssertFalse(set.isCompletedLoggedSet, "Editing values must never log a set")

        XCTAssertEqual(viewModel.toggleSetLoggedSafely(set), .logged)
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

    func testCompleteWorkoutRefusesWhenNothingLogged() {
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))
        let set = viewModel.orderedSetsForDisplay(in: exercise)[0]
        XCTAssertTrue(viewModel.updateSetSafely(set, weight: 200, reps: 5, rpe: nil))

        // Values alone aren't enough — nothing is checked off yet.
        XCTAssertFalse(viewModel.completeWorkoutSafely())
        XCTAssertFalse(viewModel.workout.isCompleted)
        XCTAssertEqual(viewModel.errorAlertTitle, "Nothing Logged Yet")

        viewModel.clearError()
        XCTAssertEqual(viewModel.toggleSetLoggedSafely(set), .logged)
        XCTAssertTrue(viewModel.completeWorkoutSafely())
        XCTAssertTrue(viewModel.workout.isCompleted)
    }
}
