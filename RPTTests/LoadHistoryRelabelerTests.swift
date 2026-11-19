//
//  LoadHistoryRelabelerTests.swift
//  RPTTests
//
//  Relabeling earlier workouts as kilograms rewrites logged sets in bulk,
//  so it has to change exactly the sets it should, leave every other one
//  alone, survive a failed save, and be undone exactly. These run against
//  their own in-memory store and their own defaults.
//

import XCTest
import SwiftData
@testable import RPT

@MainActor
final class LoadHistoryRelabelerTests: XCTestCase {
    private final class FailingDataManager: DataManaging {
        private let wrappedContext: ModelContext

        init(context: ModelContext) {
            self.wrappedContext = context
        }

        func getModelContext() -> ModelContext {
            wrappedContext
        }

        func saveChanges() throws {
            throw DataManager.DataError.saveFailed
        }
    }

    private var dataManager: DataManager!
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!
    private var relabeler: LoadHistoryRelabeler!
    private var bench: Exercise!
    private var squat: Exercise!
    private var ringDip: Exercise!

    private var context: ModelContext { dataManager.getModelContext() }

    private let firstSession = Date(timeIntervalSince1970: 1_760_000_000)

    override func setUp() {
        super.setUp()
        dataManager = DataManager(
            containerFactory: { schema, _ in
                let configuration = ModelConfiguration(
                    isStoredInMemoryOnly: true,
                    allowsSave: true
                )
                return try ModelContainer(for: schema, configurations: configuration)
            },
            seedDefaultData: false
        )

        // Never the app's own defaults: the tab shell watches one of these
        // keys and would rebuild the host app's screens mid-test.
        defaultsSuiteName = "LoadHistoryRelabelerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        relabeler = LoadHistoryRelabeler(dataManager: dataManager, defaults: defaults)

        bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])
        ringDip = Exercise(name: "Ring Dip", category: .bodyweight, primaryMuscleGroups: [.chest])
        context.insert(bench)
        context.insert(squat)
        context.insert(ringDip)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        relabeler = nil
        defaults = nil
        defaultsSuiteName = nil
        bench = nil
        squat = nil
        ringDip = nil
        dataManager = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    /// A finished workout whose sets were logged as bare whole numbers, the
    /// way every set was stored before RPT had a unit.
    @discardableResult
    private func insertFinishedWorkout(
        _ exercise: Exercise,
        loads: [(weight: Int, reps: Int)],
        at date: Date? = nil
    ) throws -> Workout {
        let workoutDate = date ?? firstSession
        let workout = Workout(date: workoutDate, name: "\(exercise.name) Day", isCompleted: true)
        context.insert(workout)
        for (index, load) in loads.enumerated() {
            let set = workout.addSet(exercise: exercise, weight: load.weight, reps: load.reps)
            set.completedAt = workoutDate.addingTimeInterval(TimeInterval(index + 1) * 180)
        }
        try context.save()
        return workout
    }

    private func storedSets() throws -> [ExerciseSet] {
        try context.fetch(FetchDescriptor<ExerciseSet>())
    }

    /// Every set's stored load, by the set itself: a fetch with no sort
    /// promises no order, so two fetches cannot be compared as arrays.
    private func storedLoads() throws -> [ObjectIdentifier: ExerciseSet.StoredLoad] {
        var loads: [ObjectIdentifier: ExerciseSet.StoredLoad] = [:]
        for set in try storedSets() {
            loads[ObjectIdentifier(set)] = set.storedLoad
        }
        return loads
    }

    private func kilograms(_ workout: Workout) -> [Double] {
        workout.setsInLoggedOrder.map { $0.load(in: .kilograms) }
    }

    private var revision: Int {
        defaults.integer(forKey: KilogramRelabelPolicy.revisionDefaultsKey)
    }

    // MARK: - Relabel

    func testRelabelReadsEveryEarlierNumberAsKilograms() throws {
        let benchDay = try insertFinishedWorkout(bench, loads: [(100, 5), (90, 6), (85, 8)])
        let squatDay = try insertFinishedWorkout(squat, loads: [(140, 5)], at: firstSession.addingTimeInterval(86_400))

        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 4))

        let expectedBench: [Double] = [100, 90, 85]
        let expectedSquat: [Double] = [140]
        XCTAssertEqual(kilograms(benchDay), expectedBench)
        XCTAssertEqual(kilograms(squatDay), expectedSquat)
        XCTAssertTrue(try storedSets().allSatisfy { $0.loadUnit == .kilograms })
        XCTAssertEqual(benchDay.setsInLoggedOrder.map { $0.formattedLoadReps(in: .kilograms) }.first, "100 kg × 5 reps")
    }

    func testRelabeledWorkoutTotalsReadInKilograms() throws {
        let benchDay = try insertFinishedWorkout(bench, loads: [(100, 5), (90, 6)])

        relabeler.relabelEarlierSetsAsKilograms()

        // 100 kg x 5 + 90 kg x 6
        let expectedKilograms: Double = 1_040
        let volumeInKilograms = WeightUnit.kilograms.converting(benchDay.totalVolume, from: .pounds)
        XCTAssertEqual(volumeInKilograms, expectedKilograms, accuracy: 0.001)
    }

    func testSetsLoggedInKilogramsAreLeftAlone() throws {
        let earlier = try insertFinishedWorkout(bench, loads: [(100, 5)])
        let later = Workout(date: firstSession.addingTimeInterval(86_400), name: "Kilogram Day", isCompleted: true)
        context.insert(later)
        let fractional = later.addSet(exercise: bench, weight: 0, reps: 5)
        fractional.setLoad(62.5, in: .kilograms)
        let whole = later.addSet(exercise: bench, weight: 0, reps: 5)
        whole.setLoad(100, in: .kilograms)
        try context.save()
        let fractionalBefore = fractional.storedLoad
        let wholeBefore = whole.storedLoad

        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 1))

        XCTAssertEqual(kilograms(earlier), [100])
        XCTAssertEqual(fractional.storedLoad, fractionalBefore)
        XCTAssertEqual(whole.storedLoad, wholeBefore)
        XCTAssertNil(fractional.relabeledFromPounds)
        XCTAssertNil(whole.relabeledFromPounds)
    }

    func testPlannedSetsInASavedDraftAreRelabeledToo() throws {
        try insertFinishedWorkout(bench, loads: [(100, 5)])
        let draft = Workout(name: "Today")
        context.insert(draft)
        let planned = draft.addSet(exercise: bench, weight: 100, reps: 5)
        planned.completedAt = .distantPast
        try context.save()

        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 2))

        XCTAssertEqual(planned.load(in: .kilograms), 100, "A load carried over from history is the same kind of number")
        XCTAssertFalse(planned.isCompletedLoggedSet)
    }

    func testSetsWithNoLoadAreNotTouched() throws {
        let dips = try insertFinishedWorkout(ringDip, loads: [(0, 10), (0, 8)])

        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .nothingToChange)

        XCTAssertTrue(dips.sets.allSatisfy { $0.weight == 0 && $0.loadValue == nil && $0.relabeledFromPounds == nil })
    }

    func testRelabelingASecondTimeChangesNothing() throws {
        let benchDay = try insertFinishedWorkout(bench, loads: [(100, 5)])
        relabeler.relabelEarlierSetsAsKilograms()
        let revisionAfterFirst = revision

        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .nothingToChange)

        XCTAssertEqual(kilograms(benchDay), [100], "100 kg must not become 100 kg read as pounds read as kilograms")
        XCTAssertEqual(revision, revisionAfterFirst)
    }

    func testEmptyHistoryIsNothingToChange() {
        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .nothingToChange)
        XCTAssertEqual(relabeler.undoRelabel(), .nothingToChange)
        XCTAssertEqual(revision, 0)
    }

    // MARK: - Undo

    func testUndoPutsEverySetBackExactly() throws {
        let benchDay = try insertFinishedWorkout(bench, loads: [(100, 5), (90, 6), (85, 8)])
        try insertFinishedWorkout(squat, loads: [(315, 3)], at: firstSession.addingTimeInterval(86_400))
        let before = try storedLoads()
        let volumeBefore = benchDay.totalVolume

        relabeler.relabelEarlierSetsAsKilograms()
        XCTAssertEqual(relabeler.undoRelabel(), .changed(sets: 4))

        XCTAssertEqual(try storedLoads(), before)
        XCTAssertEqual(before.count, 4)
        XCTAssertTrue(try storedSets().allSatisfy { $0.relabeledFromPounds == nil && $0.loadUnit == .pounds })
        XCTAssertEqual(benchDay.totalVolume, volumeBefore, accuracy: 0.0001)
    }

    func testUndoKeepsASetEditedSinceTheRelabel() throws {
        let benchDay = try insertFinishedWorkout(bench, loads: [(100, 5), (90, 6)])
        relabeler.relabelEarlierSetsAsKilograms()
        let corrected = try XCTUnwrap(benchDay.setsInLoggedOrder.first)
        corrected.setLoad(102.5, in: .kilograms)
        try context.save()

        XCTAssertEqual(relabeler.undoRelabel(), .changed(sets: 1))

        XCTAssertEqual(corrected.load(in: .kilograms), 102.5)
        XCTAssertEqual(corrected.loadUnit, .kilograms)
        XCTAssertEqual(benchDay.setsInLoggedOrder.last?.weight, 90)
        XCTAssertTrue(try storedSets().allSatisfy { $0.relabeledFromPounds == nil })
    }

    func testUndoLeavesSetsLoggedAfterTheRelabelAlone() throws {
        try insertFinishedWorkout(bench, loads: [(100, 5)])
        relabeler.relabelEarlierSetsAsKilograms()
        let later = Workout(date: firstSession.addingTimeInterval(86_400), name: "Kilogram Day", isCompleted: true)
        context.insert(later)
        let newSet = later.addSet(exercise: bench, weight: 0, reps: 5)
        newSet.setLoad(100, in: .kilograms)
        try context.save()

        XCTAssertEqual(relabeler.undoRelabel(), .changed(sets: 1))

        XCTAssertEqual(newSet.load(in: .kilograms), 100, "It reads the same as a relabeled set, but it was logged in kilograms")
        XCTAssertEqual(newSet.loadUnit, .kilograms)
    }

    func testUndoWhenEveryRelabeledSetWasEditedOnlyClearsTheMarks() throws {
        let benchDay = try insertFinishedWorkout(bench, loads: [(100, 5)])
        relabeler.relabelEarlierSetsAsKilograms()
        let only = try XCTUnwrap(benchDay.sets.first)
        only.setLoad(105, in: .kilograms)
        try context.save()

        XCTAssertEqual(relabeler.undoRelabel(), .nothingToChange)

        XCTAssertEqual(only.load(in: .kilograms), 105)
        XCTAssertNil(only.relabeledFromPounds)
        XCTAssertEqual(relabeler.status(for: .kilograms), .nothingToOffer)
    }

    func testRelabelCanBeAppliedAgainAfterAnUndo() throws {
        let benchDay = try insertFinishedWorkout(bench, loads: [(100, 5)])
        relabeler.relabelEarlierSetsAsKilograms()
        relabeler.undoRelabel()

        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 1))
        XCTAssertEqual(kilograms(benchDay), [100])
    }

    // MARK: - Stored lifetime totals

    func testRelabelAndUndoCarryTheUsersStoredTotals() throws {
        let user = User(username: "Lifter", email: "lifter@example.com")
        context.insert(user)
        let benchDay = try insertFinishedWorkout(bench, loads: [(100, 5), (90, 6)])
        let squatDay = try insertFinishedWorkout(squat, loads: [(140, 5)], at: firstSession.addingTimeInterval(86_400))
        user.registerCompletedWorkoutIfNeeded(benchDay)
        user.registerCompletedWorkoutIfNeeded(squatDay)
        try context.save()
        // 100x5 + 90x6 + 140x5
        let poundVolume: Double = 1_740
        XCTAssertEqual(user.totalVolume, poundVolume, accuracy: 0.0001)
        XCTAssertEqual(user.personalBests, ["Bench Press": 100, "Squat": 140])

        relabeler.relabelEarlierSetsAsKilograms()

        let kilogramVolumeInPounds = WeightUnit.pounds.converting(poundVolume, from: .kilograms)
        XCTAssertEqual(user.totalVolume, kilogramVolumeInPounds, accuracy: 0.001)
        XCTAssertEqual(user.personalBests, ["Bench Press": 220, "Squat": 309])

        relabeler.undoRelabel()

        XCTAssertEqual(user.totalVolume, poundVolume, accuracy: 0.001)
        XCTAssertEqual(user.personalBests, ["Bench Press": 100, "Squat": 140])
    }

    func testDraftsAndWarmupsDoNotMoveTheStoredTotals() throws {
        let user = User(username: "Lifter", email: "lifter@example.com")
        context.insert(user)
        let benchDay = try insertFinishedWorkout(bench, loads: [(100, 5)])
        user.registerCompletedWorkoutIfNeeded(benchDay)
        let warmup = benchDay.addSet(exercise: bench, weight: 45, reps: 10, isWarmup: true)
        warmup.completedAt = firstSession.addingTimeInterval(60)
        let draft = Workout(name: "Today")
        context.insert(draft)
        _ = draft.addSet(exercise: bench, weight: 300, reps: 5)
        try context.save()
        let volumeBefore = user.totalVolume

        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 3))

        // Only the counted working set moved: 100 kg x 5 instead of 100 lb x 5.
        let countedReps: Double = 5
        let expectedDelta = (WeightUnit.pounds.converting(100, from: .kilograms) - 100) * countedReps
        XCTAssertEqual(user.totalVolume - volumeBefore, expectedDelta, accuracy: 0.001)
        XCTAssertEqual(user.personalBests["Bench Press"], 220)
    }

    // MARK: - Failure

    func testFailedSaveLeavesEverySetAndTotalAsItWas() throws {
        let user = User(username: "Lifter", email: "lifter@example.com")
        context.insert(user)
        let benchDay = try insertFinishedWorkout(bench, loads: [(100, 5), (90, 6)])
        user.registerCompletedWorkoutIfNeeded(benchDay)
        try context.save()
        let loadsBefore = try storedLoads()
        let volumeBefore = user.totalVolume
        let bestsBefore = user.personalBests
        let failing = LoadHistoryRelabeler(
            dataManager: FailingDataManager(context: context),
            defaults: defaults
        )

        XCTAssertEqual(failing.relabelEarlierSetsAsKilograms(), .failed)

        XCTAssertEqual(try storedLoads(), loadsBefore)
        XCTAssertEqual(loadsBefore.count, 2)
        XCTAssertTrue(try storedSets().allSatisfy { $0.relabeledFromPounds == nil })
        XCTAssertEqual(user.totalVolume, volumeBefore, accuracy: 0.0001)
        XCTAssertEqual(user.personalBests, bestsBefore)
        XCTAssertFalse(failing.hasAnsweredPrompt, "A relabel that did not happen must leave the question open")
        XCTAssertEqual(revision, 0)
    }

    func testFailedUndoLeavesTheRelabelInPlace() throws {
        let benchDay = try insertFinishedWorkout(bench, loads: [(100, 5), (90, 6)])
        relabeler.relabelEarlierSetsAsKilograms()
        let loadsAfterRelabel = try storedLoads()
        let revisionAfterRelabel = revision
        let failing = LoadHistoryRelabeler(
            dataManager: FailingDataManager(context: context),
            defaults: defaults
        )

        XCTAssertEqual(failing.undoRelabel(), .failed)

        XCTAssertEqual(try storedLoads(), loadsAfterRelabel)
        let expectedMarks: [Int?] = [100, 90]
        XCTAssertEqual(benchDay.setsInLoggedOrder.map(\.relabeledFromPounds), expectedMarks)
        XCTAssertEqual(revision, revisionAfterRelabel)
        XCTAssertEqual(relabeler.status(for: .kilograms), .relabeled(setCount: 2))
    }

    // MARK: - What the lifter is offered

    func testStatusFollowsTheUnitAndTheHistory() throws {
        XCTAssertEqual(relabeler.status(for: .kilograms), .nothingToOffer, "No history, nothing to ask")

        try insertFinishedWorkout(bench, loads: [(100, 5), (90, 6)])

        XCTAssertEqual(relabeler.status(for: .pounds), .nothingToOffer)
        XCTAssertEqual(
            relabeler.status(for: .kilograms),
            .readAsPounds(KilogramRelabelPolicy.Preview(setCount: 2, exerciseName: "Bench Press", number: 90))
        )

        relabeler.relabelEarlierSetsAsKilograms()

        XCTAssertEqual(relabeler.status(for: .kilograms), .relabeled(setCount: 2))
        XCTAssertEqual(relabeler.status(for: .pounds), .relabeled(setCount: 2), "The undo stays reachable in either unit")

        relabeler.undoRelabel()

        XCTAssertEqual(relabeler.status(for: .pounds), .nothingToOffer)
        guard case .readAsPounds = relabeler.status(for: .kilograms) else {
            return XCTFail("After an undo the relabel can be offered again")
        }
    }

    func testPreviewQuotesTheMostRecentLoggedWorkingSet() throws {
        try insertFinishedWorkout(bench, loads: [(100, 5)])
        let latest = try insertFinishedWorkout(squat, loads: [(140, 5)], at: firstSession.addingTimeInterval(86_400))
        let warmup = latest.addSet(exercise: squat, weight: 60, reps: 5, isWarmup: true)
        warmup.completedAt = firstSession.addingTimeInterval(200_000)
        let draft = Workout(name: "Today")
        context.insert(draft)
        let planned = draft.addSet(exercise: bench, weight: 105, reps: 5)
        planned.completedAt = .distantPast
        try context.save()

        XCTAssertEqual(
            relabeler.preview(),
            KilogramRelabelPolicy.Preview(setCount: 4, exerciseName: "Squat", number: 140),
            "A warm-up or a planned set is a poor example of what the lifter lifted"
        )
    }

    func testPreviewOfOnlyPlannedSetsHasNoExample() throws {
        let draft = Workout(name: "Today")
        context.insert(draft)
        let planned = draft.addSet(exercise: bench, weight: 105, reps: 5)
        planned.completedAt = .distantPast
        try context.save()

        XCTAssertEqual(
            relabeler.preview(),
            KilogramRelabelPolicy.Preview(setCount: 1, exerciseName: nil, number: nil)
        )
    }

    func testQuestionIsRaisedOnceAndOnlyOnASwitchToKilograms() throws {
        XCTAssertNil(relabeler.question(afterSwitchingTo: .kilograms), "Nothing logged, nothing to ask")

        try insertFinishedWorkout(bench, loads: [(100, 5)])

        XCTAssertNil(relabeler.question(afterSwitchingTo: .pounds))
        XCTAssertEqual(
            relabeler.question(afterSwitchingTo: .kilograms),
            KilogramRelabelPolicy.Preview(setCount: 1, exerciseName: "Bench Press", number: 100)
        )

        relabeler.recordPromptAnswered()

        XCTAssertNil(relabeler.question(afterSwitchingTo: .kilograms), "Answered once, whichever answer it was")
        guard case .readAsPounds = relabeler.status(for: .kilograms) else {
            return XCTFail("The Settings row still lets a lifter change their answer")
        }
    }

    func testRelabelAnswersTheQuestionAndTellsTheTabsToRebuild() throws {
        try insertFinishedWorkout(bench, loads: [(100, 5)])
        XCTAssertFalse(relabeler.hasAnsweredPrompt)
        XCTAssertEqual(revision, 0)

        relabeler.relabelEarlierSetsAsKilograms()

        XCTAssertTrue(relabeler.hasAnsweredPrompt)
        XCTAssertEqual(revision, 1)
        XCTAssertNil(relabeler.question(afterSwitchingTo: .kilograms))

        relabeler.undoRelabel()

        XCTAssertEqual(revision, 2)
        XCTAssertNil(relabeler.question(afterSwitchingTo: .kilograms), "An undo does not bring the unprompted question back")
    }
}
