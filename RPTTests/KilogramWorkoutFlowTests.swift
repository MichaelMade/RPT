//
//  KilogramWorkoutFlowTests.swift
//  RPTTests
//
//  Logging a workout in kilograms: what the live-workout view model stores
//  and suggests, and what a new template workout starts from.
//

import XCTest
import SwiftData
@testable import RPT

@MainActor
final class KilogramWorkoutFlowTests: XCTestCase {
    private var originalDrops: [Double] = UserSettings.defaultRPTPercentageDrops

    override func setUp() {
        super.setUp()
        originalDrops = SettingsManager.shared.settings.defaultRPTPercentageDrops
        _ = SettingsManager.shared.updateRPTPercentageDropsSafely(drops: [0.0, 0.10, 0.15])
    }

    override func tearDown() {
        _ = SettingsManager.shared.updateRPTPercentageDropsSafely(
            drops: UserSettings.normalizedRPTPercentageDrops(originalDrops)
        )
        super.tearDown()
    }

    private func makeExercise(category: ExerciseCategory = .compound) -> Exercise {
        Exercise(name: "Bench Press", category: category, primaryMuscleGroups: [.chest])
    }

    /// A workout with one exercise and `setCount` planned, empty working sets.
    private func makeWorkout(
        setCount: Int,
        exercise: Exercise
    ) -> (viewModel: ActiveWorkoutViewModel, sets: [ExerciseSet]) {
        let viewModel = ActiveWorkoutViewModel(workout: Workout(name: "Test"))
        XCTAssertTrue(viewModel.addExerciseToWorkoutSafely(exercise))
        while viewModel.orderedSetsForDisplay(in: exercise).count < setCount {
            XCTAssertTrue(viewModel.addSetToExerciseSafely(exercise))
        }
        return (viewModel, viewModel.orderedSetsForDisplay(in: exercise))
    }

    private func kilograms(_ sets: [ExerciseSet]) -> [Double] {
        sets.map { $0.load(in: .kilograms) }
    }

    // MARK: - Entering a load

    func testKilogramLoadIsStoredExactlyAsTyped() {
        let bench = makeExercise()
        let (viewModel, sets) = makeWorkout(setCount: 1, exercise: bench)

        XCTAssertTrue(viewModel.updateSetSafely(sets[0], load: 61.25, unit: .kilograms, reps: 8, rpe: nil))

        XCTAssertEqual(sets[0].load(in: .kilograms), 61.25)
        XCTAssertEqual(sets[0].loadUnit, .kilograms)
        XCTAssertEqual(sets[0].reps, 8)
        XCTAssertFalse(sets[0].isCompletedLoggedSet, "Editing values never logs a set")
    }

    func testInvalidLoadIsRejected() {
        let bench = makeExercise()
        let (viewModel, sets) = makeWorkout(setCount: 1, exercise: bench)

        XCTAssertFalse(viewModel.updateSetSafely(sets[0], load: -5, unit: .kilograms, reps: 8, rpe: nil))
        XCTAssertFalse(viewModel.updateSetSafely(sets[0], load: .nan, unit: .kilograms, reps: 8, rpe: nil))
        XCTAssertEqual(sets[0].weight, 0)
    }

    func testSavingInAnotherUnitWithoutChangingTheLoadKeepsItExact() {
        let bench = makeExercise()
        let (viewModel, sets) = makeWorkout(setCount: 1, exercise: bench)
        XCTAssertTrue(viewModel.updateSetSafely(sets[0], load: 100, unit: .kilograms, reps: 5, rpe: nil))

        // A pound lifter sees 220 lb and changes only the reps.
        XCTAssertTrue(viewModel.updateSetSafely(sets[0], load: 220, unit: .pounds, reps: 6, rpe: nil))

        XCTAssertEqual(sets[0].load(in: .kilograms), 100)
        XCTAssertEqual(sets[0].reps, 6)
    }

    func testChangingOnlyTheRPENeverTouchesTheLoad() {
        let bench = makeExercise()
        let (viewModel, sets) = makeWorkout(setCount: 1, exercise: bench)
        XCTAssertTrue(viewModel.updateSetSafely(sets[0], load: 102.5, unit: .kilograms, reps: 5, rpe: nil))
        let before = sets[0].storedLoad

        XCTAssertTrue(viewModel.updateRPESafely(sets[0], rpe: 9))

        XCTAssertEqual(sets[0].storedLoad, before)
        XCTAssertEqual(sets[0].rpe, 9)
        XCTAssertEqual(sets[0].reps, 5)
    }

    func testPoundEntryStillStoresWholePoundsOnly() {
        let bench = makeExercise()
        let (viewModel, sets) = makeWorkout(setCount: 1, exercise: bench)

        XCTAssertTrue(viewModel.updateSetSafely(sets[0], load: 185, unit: .pounds, reps: 5, rpe: nil))

        XCTAssertEqual(sets[0].weight, 185)
        XCTAssertNil(sets[0].loadValue)
        XCTAssertNil(sets[0].loadUnitRaw)
    }

    // MARK: - Back-off sets

    func testNewKilogramTopSetPlansBackoffsInLoadableKilograms() {
        let bench = makeExercise()
        let (viewModel, sets) = makeWorkout(setCount: 3, exercise: bench)

        XCTAssertTrue(viewModel.updateSetSafely(sets[0], load: 102.5, unit: .kilograms, reps: 5, rpe: nil))
        XCTAssertTrue(viewModel.syncBackoffsAfterTopSetSave(sets[0], in: bench, previousLoad: 0, unit: .kilograms))

        // 10% and 15% off 102.5 are 92.25 and 87.125.
        XCTAssertEqual(kilograms(sets), [102.5, 92.5, 87.5])
        XCTAssertTrue(sets.allSatisfy { !$0.isCompletedLoggedSet }, "Suggestions never log a set")
    }

    func testAddedBackoffIsRoundedInKilograms() {
        let bench = makeExercise()
        let (viewModel, sets) = makeWorkout(setCount: 1, exercise: bench)
        XCTAssertTrue(viewModel.updateSetSafely(sets[0], load: 100, unit: .kilograms, reps: 5, rpe: nil))
        XCTAssertEqual(viewModel.toggleSetLoggedSafely(sets[0]), .logged)

        XCTAssertNoThrow(try viewModel.addSetToExercise(bench, unit: .kilograms))
        XCTAssertNoThrow(try viewModel.addSetToExercise(bench, unit: .kilograms))

        XCTAssertEqual(kilograms(viewModel.orderedSetsForDisplay(in: bench)), [100, 90, 85])
    }

    func testLoggedKilogramBackoffIsNeverRewritten() {
        let bench = makeExercise()
        let (viewModel, sets) = makeWorkout(setCount: 3, exercise: bench)
        XCTAssertTrue(viewModel.updateSetSafely(sets[0], load: 100, unit: .kilograms, reps: 5, rpe: nil))
        XCTAssertTrue(viewModel.syncBackoffsAfterTopSetSave(sets[0], in: bench, previousLoad: 0, unit: .kilograms))
        XCTAssertTrue(viewModel.updateSetSafely(sets[1], load: 91.25, unit: .kilograms, reps: 6, rpe: nil))
        XCTAssertEqual(viewModel.toggleSetLoggedSafely(sets[1]), .logged)

        // The top set goes up after the first back-off was already lifted.
        XCTAssertTrue(viewModel.updateSetSafely(sets[0], load: 105, unit: .kilograms, reps: 5, rpe: nil))
        XCTAssertTrue(viewModel.syncBackoffsAfterTopSetSave(sets[0], in: bench, previousLoad: 100, unit: .kilograms))

        XCTAssertEqual(sets[1].load(in: .kilograms), 91.25, "What was lifted stays what was lifted")
        XCTAssertEqual(sets[2].load(in: .kilograms), 90, "The planned back-off follows the new top set (89.25 loads as 90)")
    }

    func testRepsOnlySaveLeavesPlannedKilogramBackoffsAlone() {
        let bench = makeExercise()
        let (viewModel, sets) = makeWorkout(setCount: 3, exercise: bench)
        XCTAssertTrue(viewModel.updateSetSafely(sets[0], load: 100, unit: .kilograms, reps: 5, rpe: nil))
        XCTAssertTrue(viewModel.syncBackoffsAfterTopSetSave(sets[0], in: bench, previousLoad: 0, unit: .kilograms))
        XCTAssertTrue(viewModel.updateSetSafely(sets[1], load: 87.5, unit: .kilograms, reps: 6, rpe: nil))

        XCTAssertTrue(viewModel.updateSetSafely(sets[0], load: 100, unit: .kilograms, reps: 6, rpe: nil))
        XCTAssertTrue(viewModel.syncBackoffsAfterTopSetSave(sets[0], in: bench, previousLoad: 100, unit: .kilograms))

        XCTAssertEqual(kilograms(sets), [100, 87.5, 85], "The lifter's own 87.5 is kept")
    }

    func testPoundTopSetOnKilogramHistoryRoundsBackoffsInPounds() {
        let bench = makeExercise()
        let (viewModel, sets) = makeWorkout(setCount: 2, exercise: bench)

        XCTAssertTrue(viewModel.updateSetSafely(sets[0], load: 225, unit: .pounds, reps: 5, rpe: nil))
        XCTAssertTrue(viewModel.syncBackoffsAfterTopSetSave(sets[0], in: bench, previousLoad: 0, unit: .pounds))

        XCTAssertEqual(sets.map(\.weight), [225, 205])
        XCTAssertTrue(sets.allSatisfy { $0.loadValue == nil })
    }

    // MARK: - Warm-ups

    func testKilogramWarmupIsStoredInKilograms() {
        let bench = makeExercise()
        let (viewModel, _) = makeWorkout(setCount: 1, exercise: bench)

        XCTAssertTrue(viewModel.addWarmupSetSafely(to: bench, load: 57.5, unit: .kilograms, reps: 5))

        let warmup = viewModel.orderedSetsForDisplay(in: bench).first(where: \.isWarmup)
        XCTAssertEqual(warmup?.load(in: .kilograms), 57.5)
        XCTAssertEqual(warmup?.isCompletedLoggedSet, false)
    }

    // MARK: - Starting from last session

    private func makeSet(exercise: Exercise) -> ExerciseSet {
        ExerciseSet(weight: 0, reps: 8, exercise: exercise, completedAt: .distantPast)
    }

    func testNewWorkoutStartsAtExactlyLastSessionsKilograms() {
        let bench = makeExercise()
        let lastTime = makeSet(exercise: bench)
        lastTime.setLoad(61.25, in: .kilograms)
        let planned = makeSet(exercise: bench)

        TemplateManager.carryOverLoad(from: lastTime, to: planned, unit: .kilograms)

        XCTAssertEqual(planned.load(in: .kilograms), 61.25)
        XCTAssertEqual(planned.storedLoad, lastTime.storedLoad)
    }

    func testPoundHistoryBecomesALoadableKilogramTarget() {
        let bench = makeExercise()
        let lastTime = ExerciseSet(weight: 225, reps: 5, exercise: bench)
        let planned = makeSet(exercise: bench)

        TemplateManager.carryOverLoad(from: lastTime, to: planned, unit: .kilograms)

        // 102.06 kg cannot be loaded; 102.5 can.
        XCTAssertEqual(planned.load(in: .kilograms), 102.5)
        XCTAssertEqual(planned.loadUnit, .kilograms)
    }

    func testKilogramHistoryBecomesALoadablePoundTarget() {
        let bench = makeExercise()
        let lastTime = makeSet(exercise: bench)
        lastTime.setLoad(100, in: .kilograms)
        let planned = makeSet(exercise: bench)

        TemplateManager.carryOverLoad(from: lastTime, to: planned, unit: .pounds)

        XCTAssertEqual(planned.weight, 220)
        XCTAssertNil(planned.loadValue)
    }

    func testPoundHistoryForAPoundLifterIsCopiedUntouched() {
        let bench = makeExercise()
        let lastTime = ExerciseSet(weight: 187, reps: 5, exercise: bench)
        let planned = makeSet(exercise: bench)

        TemplateManager.carryOverLoad(from: lastTime, to: planned, unit: .pounds)

        XCTAssertEqual(planned.weight, 187, "Not rounded to 185: it is what was lifted")
        XCTAssertNil(planned.loadValue)
    }

    func testNothingIsCarriedOverFromAnEmptySet() {
        let bench = makeExercise()
        let planned = makeSet(exercise: bench)

        TemplateManager.carryOverLoad(from: makeSet(exercise: bench), to: planned, unit: .kilograms)

        XCTAssertEqual(planned.weight, 0)
        XCTAssertNil(planned.loadValue)
    }

    // MARK: - Totals

    func testVolumeIsWrittenCompactlyInKilograms() {
        let manager = WorkoutManager.shared
        let poundsPerKilogram = 1 / WeightUnit.kilogramsPerPound

        XCTAssertEqual(manager.formatVolume(500 * poundsPerKilogram, unit: .kilograms), "500 kg")
        XCTAssertEqual(manager.formatVolume(10_000 * poundsPerKilogram, unit: .kilograms), "10k kg")
        XCTAssertEqual(manager.formatVolume(12_500 * poundsPerKilogram, unit: .kilograms), "12.5k kg")
        XCTAssertEqual(manager.formatVolume(1_000_000 * poundsPerKilogram, unit: .kilograms), "1M kg")
        XCTAssertEqual(manager.formatVolume(1_125, unit: .pounds), "1.1k lb")
    }
}
