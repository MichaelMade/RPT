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

    func testAddedSetAndRecalculationFollowLadderPosition() {
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // Three planned sets, as a template creates them; only the top is logged.
        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))
        XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))
        XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))

        let topSet = viewModel.orderedSetsForDisplay(in: exercise)[0]
        XCTAssertTrue(viewModel.updateSetSafely(topSet, weight: 200, reps: 5, rpe: nil))
        XCTAssertEqual(viewModel.toggleSetLoggedSafely(topSet), .logged)
        XCTAssertTrue(viewModel.updateDropSetSuggestionsSafely(for: exercise, firstSetWeight: 200))

        // A fourth set is planned before the back-offs are done.
        XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))
        XCTAssertEqual(
            viewModel.orderedSetsForDisplay(in: exercise).map(\.weight),
            [200, 180, 170, 170],
            "A fourth set reuses the deepest drop; it must not come out heavier than the third"
        )

        // The top set turns out lighter: every planned back-off follows it.
        XCTAssertTrue(viewModel.updateSetSafely(topSet, weight: 150, reps: 5, rpe: nil))
        XCTAssertTrue(viewModel.updateDropSetSuggestionsSafely(for: exercise, firstSetWeight: 150))
        XCTAssertEqual(
            viewModel.orderedSetsForDisplay(in: exercise).map(\.weight),
            [150, 135, 130, 130],
            "No back-off may be left heavier than the top set"
        )
    }

    func testResavingTopSetOnlyFillsBackoffsThatHaveNoLoad() {
        let exercise = makeExercise()
        let workout = Workout(name: "Test")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))
        XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))
        XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))

        var sets = viewModel.orderedSetsForDisplay(in: exercise)
        XCTAssertTrue(viewModel.updateSetSafely(sets[0], weight: 200, reps: 5, rpe: nil))
        // The lifter planned their own first back-off; the second is empty.
        XCTAssertTrue(viewModel.updateSetSafely(sets[1], weight: 185, reps: 8, rpe: nil))

        XCTAssertTrue(
            viewModel.updateDropSetSuggestionsSafely(for: exercise, firstSetWeight: 200, onlyEmptySets: true)
        )

        sets = viewModel.orderedSetsForDisplay(in: exercise)
        XCTAssertEqual(sets[1].weight, 185, "A load the lifter planned is left alone")
        XCTAssertEqual(sets[2].weight, 170, "An empty back-off is filled: 15% off 200")
        XCTAssertFalse(sets[2].isCompletedLoggedSet)
    }

    // MARK: - Back-offs After A Top-Set Save

    private func makePullUp() -> Exercise {
        Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])
    }

    /// Builds one exercise whose working sets carry the given planned loads
    /// (0 means "no load yet"), none of them logged.
    private func makeLadder(_ plannedWeights: [Int], of exercise: Exercise) -> ActiveWorkoutViewModel {
        let viewModel = ActiveWorkoutViewModel(workout: Workout(name: "Test"))

        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))
        for _ in plannedWeights.dropFirst() {
            XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))
        }

        for (set, weight) in zip(viewModel.orderedSetsForDisplay(in: exercise), plannedWeights) {
            XCTAssertTrue(viewModel.updateSetSafely(set, weight: weight, reps: 8, rpe: nil))
        }

        return viewModel
    }

    /// What the set editor does when the top set is saved.
    private func saveTopSet(of exercise: Exercise, in viewModel: ActiveWorkoutViewModel, weight: Int, reps: Int) {
        let topSet = viewModel.orderedSetsForDisplay(in: exercise)[0]
        let previousWeight = topSet.weight

        XCTAssertTrue(viewModel.updateSetSafely(topSet, weight: weight, reps: reps, rpe: nil))
        XCTAssertTrue(viewModel.syncBackoffsAfterTopSetSave(topSet, in: exercise, previousWeight: previousWeight))
    }

    private func plannedWeights(of exercise: Exercise, in viewModel: ActiveWorkoutViewModel) -> [Int] {
        viewModel.orderedSetsForDisplay(in: exercise).map(\.weight)
    }

    func testNewTopSetWeightRecalculatesPlannedBackoffs() {
        let bench = makeExercise()
        let viewModel = makeLadder([200, 180, 170], of: bench)

        saveTopSet(of: bench, in: viewModel, weight: 220, reps: 8)

        XCTAssertEqual(plannedWeights(of: bench, in: viewModel), [220, 200, 185], "10% and 15% off 220")
    }

    func testRepsOnlySaveLeavesPlannedBackoffsAlone() {
        let bench = makeExercise()
        let viewModel = makeLadder([200, 190, 180], of: bench)

        saveTopSet(of: bench, in: viewModel, weight: 200, reps: 6)

        XCTAssertEqual(
            plannedWeights(of: bench, in: viewModel),
            [200, 190, 180],
            "Correcting reps must not replace back-offs the lifter planned"
        )
    }

    func testRepsOnlySaveFillsBackoffsThatHaveNoLoadYet() {
        let bench = makeExercise()
        let viewModel = makeLadder([200, 0, 0], of: bench)

        saveTopSet(of: bench, in: viewModel, weight: 200, reps: 6)

        XCTAssertEqual(plannedWeights(of: bench, in: viewModel), [200, 180, 170])
    }

    func testFilledBackoffNeverComesOutHeavierThanTheSetAboveIt() {
        let bench = makeExercise()
        // The second set is planned lighter than the configured 10% drop.
        let viewModel = makeLadder([200, 165, 0], of: bench)

        saveTopSet(of: bench, in: viewModel, weight: 200, reps: 6)

        XCTAssertEqual(
            plannedWeights(of: bench, in: viewModel),
            [200, 165, 165],
            "15% off 200 is 170, which would sit above the 165 planned before it"
        )
    }

    func testClearingACompoundTopSetLeavesBackoffsAlone() {
        let bench = makeExercise()
        let viewModel = makeLadder([200, 180, 170], of: bench)

        saveTopSet(of: bench, in: viewModel, weight: 0, reps: 8)

        XCTAssertEqual(plannedWeights(of: bench, in: viewModel), [0, 180, 170])
    }

    func testAddedWeightOnABodyweightTopSetRecalculatesBackoffs() {
        let pullUp = makePullUp()
        let viewModel = makeLadder([0, 0, 0], of: pullUp)

        saveTopSet(of: pullUp, in: viewModel, weight: 25, reps: 8)

        XCTAssertEqual(plannedWeights(of: pullUp, in: viewModel), [25, 25, 20], "10% and 15% off 25, rounded to 5 lb")
    }

    func testChangingABodyweightTopSetToBodyweightTakesTheBackoffsWithIt() {
        let pullUp = makePullUp()
        let viewModel = makeLadder([25, 25, 20], of: pullUp)

        saveTopSet(of: pullUp, in: viewModel, weight: 0, reps: 8)

        XCTAssertEqual(
            plannedWeights(of: pullUp, in: viewModel),
            [0, 0, 0],
            "Planned back-offs must not stay heavier than a bodyweight top set"
        )
    }

    func testRepsOnlySaveNeverFillsBodyweightBackoffs() {
        let pullUp = makePullUp()
        // Weighted top set, back-offs deliberately at bodyweight.
        let viewModel = makeLadder([25, 0, 0], of: pullUp)

        saveTopSet(of: pullUp, in: viewModel, weight: 25, reps: 6)

        XCTAssertEqual(
            plannedWeights(of: pullUp, in: viewModel),
            [25, 0, 0],
            "Zero is a real load for a bodyweight movement, not an empty set"
        )
    }

    func testSavingABackoffNeverMovesTheLadder() {
        let bench = makeExercise()
        let viewModel = makeLadder([200, 180, 170], of: bench)
        let firstBackoff = viewModel.orderedSetsForDisplay(in: bench)[1]

        XCTAssertTrue(viewModel.updateSetSafely(firstBackoff, weight: 150, reps: 8, rpe: nil))
        XCTAssertTrue(viewModel.syncBackoffsAfterTopSetSave(firstBackoff, in: bench, previousWeight: 180))

        XCTAssertEqual(plannedWeights(of: bench, in: viewModel), [200, 150, 170], "Only the top set drives the ladder")
    }

    // MARK: - Template Pre-fill And Reopening

    @MainActor
    private struct IsolatedStore {
        let dataManager: DataManager
        let workoutManager: WorkoutManager
        let exerciseManager: ExerciseManager
        let templateManager: TemplateManager

        var context: ModelContext { dataManager.getModelContext() }

        func makeViewModel(for workout: Workout) -> ActiveWorkoutViewModel {
            ActiveWorkoutViewModel(
                workout: workout,
                workoutManager: workoutManager,
                exerciseManager: exerciseManager
            )
        }
    }

    /// Template pre-fill reads prior sessions from the store, so these tests
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
        let exerciseManager = ExerciseManager(dataManager: dataManager)

        return IsolatedStore(
            dataManager: dataManager,
            workoutManager: WorkoutManager(dataManager: dataManager),
            exerciseManager: exerciseManager,
            templateManager: TemplateManager(
                dataManager: dataManager,
                exerciseManager: exerciseManager,
                seedDefaultTemplates: false
            )
        )
    }

    /// Inserts a library exercise and a three-set template that uses it.
    private func insertTemplate(
        named templateName: String,
        for exercise: Exercise,
        in store: IsolatedStore
    ) throws -> WorkoutTemplate {
        store.context.insert(exercise)

        let template = WorkoutTemplate(
            name: templateName,
            exercises: [
                TemplateExercise(
                    exerciseName: exercise.name,
                    suggestedSets: 3,
                    repRanges: [
                        TemplateRepRange(setNumber: 1, minReps: 7, maxReps: 9, percentageOfFirstSet: 1.0),
                        TemplateRepRange(setNumber: 2, minReps: 7, maxReps: 9, percentageOfFirstSet: 0.9),
                        TemplateRepRange(setNumber: 3, minReps: 7, maxReps: 9, percentageOfFirstSet: 0.85)
                    ]
                )
            ]
        )
        store.context.insert(template)

        try store.context.save()
        return template
    }

    /// Inserts a completed session of `exercise` from a week ago.
    private func insertLastWeeksSession(
        of exercise: Exercise,
        sets: [(weight: Int, rpe: Int)],
        in store: IsolatedStore
    ) throws -> Workout {
        let lastWeek = Workout(
            date: Date(timeIntervalSinceNow: -7 * 24 * 60 * 60),
            name: "Last Week",
            startedFromTemplate: "Last Week"
        )
        store.context.insert(lastWeek)

        for plannedSet in sets {
            _ = lastWeek.addSet(exercise: exercise, weight: plannedSet.weight, reps: 8, rpe: plannedSet.rpe)
        }
        lastWeek.isCompleted = true

        try store.context.save()
        return lastWeek
    }

    func testTemplateWorkoutIsPrefilledOnceWhenItIsCreated() throws {
        let store = makeIsolatedStore()
        let bench = makeExercise()
        let template = try insertTemplate(named: "Bench Day", for: bench, in: store)
        _ = try insertLastWeeksSession(of: bench, sets: [(185, 9), (165, 8), (155, 8)], in: store)

        let workout = try XCTUnwrap(store.templateManager.createWorkoutFromTemplate(template))
        let sets = workout.setsInLoggedOrder

        XCTAssertEqual(sets.map(\.weight), [185, 165, 155], "A new template workout starts at last session's loads")
        XCTAssertEqual(sets.map(\.reps), [8, 8, 8], "Template rep targets are kept")
        XCTAssertTrue(sets.allSatisfy { $0.rpe == nil }, "RPE belongs to a performed set and is never pre-filled")
        XCTAssertTrue(sets.allSatisfy { !$0.isCompletedLoggedSet }, "Pre-filling never logs a set")
    }

    func testTemplateWorkoutWithNoHistoryStartsEmpty() throws {
        let store = makeIsolatedStore()
        let bench = makeExercise()
        let template = try insertTemplate(named: "Bench Day", for: bench, in: store)

        let workout = try XCTUnwrap(store.templateManager.createWorkoutFromTemplate(template))

        XCTAssertEqual(workout.setsInLoggedOrder.map(\.weight), [0, 0, 0])
        XCTAssertTrue(workout.sets.allSatisfy { !$0.isCompletedLoggedSet })
    }

    func testReopeningTemplateWorkoutKeepsEverythingTheLifterEntered() throws {
        let store = makeIsolatedStore()
        let bench = makeExercise()
        let template = try insertTemplate(named: "Bench Day", for: bench, in: store)
        _ = try insertLastWeeksSession(of: bench, sets: [(185, 9), (165, 8), (155, 8)], in: store)
        let today = try XCTUnwrap(store.templateManager.createWorkoutFromTemplate(template))

        let firstOpen = store.makeViewModel(for: today)
        var sets = firstOpen.orderedSetsForDisplay(in: bench)
        XCTAssertEqual(sets.map(\.weight), [185, 165, 155])

        // Go heavier than last week and log the top set, adjust one
        // back-off, clear the other, and add a warm-up.
        XCTAssertTrue(firstOpen.updateSetSafely(sets[0], weight: 190, reps: 8, rpe: 8))
        XCTAssertEqual(firstOpen.toggleSetLoggedSafely(sets[0]), .logged)
        XCTAssertTrue(firstOpen.updateSetSafely(sets[1], weight: 170, reps: 8, rpe: nil))
        XCTAssertTrue(firstOpen.updateSetSafely(sets[2], weight: 0, reps: 8, rpe: nil))
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
        XCTAssertEqual(sets[3].weight, 0, "A back-off the lifter cleared is not refilled from history")
        XCTAssertNil(reopened.errorMessage)
    }

    func testReopeningKeepsBodyweightSetsAtBodyweight() throws {
        let store = makeIsolatedStore()
        let pullUp = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])
        let template = try insertTemplate(named: "Pull Day", for: pullUp, in: store)
        _ = try insertLastWeeksSession(of: pullUp, sets: [(25, 9), (25, 8), (20, 8)], in: store)
        let today = try XCTUnwrap(store.templateManager.createWorkoutFromTemplate(template))

        let firstOpen = store.makeViewModel(for: today)
        let sets = firstOpen.orderedSetsForDisplay(in: pullUp)
        XCTAssertEqual(sets.map(\.weight), [25, 25, 20], "Pre-filled with last week's added weight")

        // Today is a bodyweight day: zero is a real load here, not "empty".
        for set in sets {
            XCTAssertTrue(firstOpen.updateSetSafely(set, weight: 0, reps: 8, rpe: nil))
        }

        let reopened = store.makeViewModel(for: today)

        XCTAssertEqual(
            reopened.orderedSetsForDisplay(in: pullUp).map(\.weight),
            [0, 0, 0],
            "Reopening must not put last week's added weight back on a bodyweight set"
        )
    }

    func testFollowUpFromTemplateSessionKeepsItsProgressedWeights() throws {
        let store = makeIsolatedStore()
        let bench = makeExercise()
        store.context.insert(bench)
        let lastWeek = try insertLastWeeksSession(of: bench, sets: [(185, 9), (165, 8), (155, 8)], in: store)

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
