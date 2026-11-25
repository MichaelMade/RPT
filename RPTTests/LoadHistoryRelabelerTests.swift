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

    /// Saves for real until told to stop, so a failure can be placed after
    /// work that did reach the store.
    private final class FailingAfterDataManager: DataManaging {
        private let wrappedContext: ModelContext
        private var savesThatSucceed: Int
        private(set) var saveAttempts = 0

        init(context: ModelContext, savesThatSucceed: Int) {
            self.wrappedContext = context
            self.savesThatSucceed = savesThatSucceed
        }

        func getModelContext() -> ModelContext {
            wrappedContext
        }

        func saveChanges() throws {
            saveAttempts += 1
            guard savesThatSucceed > 0 else {
                throw DataManager.DataError.saveFailed
            }
            savesThatSucceed -= 1
            try wrappedContext.save()
        }
    }

    /// The moment the relabeler believes it is.
    private final class Clock {
        var now: Date

        init(now: Date) {
            self.now = now
        }
    }

    private var dataManager: DataManager!
    private var clock: Clock!
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

        // Far ahead of every fixture, and of the real clock that stamps a
        // set added without a date, so by default everything logged in a
        // test happened before the lifter had kilograms. A test about what
        // came after sets `clock.now` before the relabeler is first asked.
        clock = Clock(now: Date(timeIntervalSince1970: 4_000_000_000))
        relabeler = makeRelabeler(using: dataManager)

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
        clock = nil
        defaults = nil
        defaultsSuiteName = nil
        bench = nil
        squat = nil
        ringDip = nil
        dataManager = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    private func makeRelabeler(using manager: DataManaging) -> LoadHistoryRelabeler {
        let clock: Clock = self.clock
        return LoadHistoryRelabeler(dataManager: manager, defaults: defaults, now: { clock.now })
    }

    private var recordedFirstKilogramChoice: Date? {
        defaults.object(forKey: KilogramRelabelPolicy.firstKilogramChoiceDefaultsKey) as? Date
    }

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

    /// Every set's stored load, by the row it belongs to. A fetch with no
    /// sort promises no order, and SwiftData lets go of model objects
    /// between fetches, so neither position nor object identity says which
    /// set is which across two fetches. Call it only after a save: an
    /// unsaved row's identifier is temporary.
    private func storedLoads() throws -> [PersistentIdentifier: ExerciseSet.StoredLoad] {
        var loads: [PersistentIdentifier: ExerciseSet.StoredLoad] = [:]
        for set in try storedSets() {
            loads[set.persistentModelID] = set.storedLoad
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
        XCTAssertFalse(relabeler.hasAnsweredPrompt, "Nothing was relabeled, so the question has not been answered")
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

    // MARK: - Every earlier set, whatever it looks like

    func testEveryKindOfEarlierSetIsRelabeledAndPutBack() throws {
        // A history large and varied enough that a relabel which only took
        // heavy sets, plain sets, or the first few hundred rows would show.
        let numbers = [1, 2, 5, 10, 20, 44, 45, 135, 225, 1_000, 4_500]
        let setsPerWorkout = 12
        let workoutCount = 130
        var expected = 0

        for workoutIndex in 0..<workoutCount {
            let date = firstSession.addingTimeInterval(TimeInterval(workoutIndex) * 86_400)
            let isDraft = workoutIndex % 40 == 39
            let workout = Workout(date: date, name: "Session \(workoutIndex)", isCompleted: !isDraft)
            context.insert(workout)

            for setIndex in 0..<setsPerWorkout {
                let serial = workoutIndex * setsPerWorkout + setIndex
                let exercise = serial % 3 == 0 ? squat! : bench!
                let number = numbers[serial % numbers.count]
                let set = workout.addSet(
                    exercise: exercise,
                    weight: number,
                    reps: 1 + serial % 12,
                    isWarmup: serial % 7 == 0,
                    rpe: serial % 5 == 0 ? 8 : nil
                )
                set.completedAt = isDraft && setIndex > 5
                    ? .distantPast
                    : date.addingTimeInterval(TimeInterval(setIndex + 1) * 120)
                if serial % 11 == 0 {
                    set.notes = "note \(serial)"
                }
                expected += 1
            }
        }

        // Sets that must be left out.
        let mixed = Workout(date: firstSession, name: "Mixed", isCompleted: true)
        context.insert(mixed)
        let kilogram = mixed.addSet(exercise: bench, weight: 0, reps: 5)
        kilogram.setLoad(100, in: .kilograms)
        let tooLarge = mixed.addSet(exercise: bench, weight: 4_501, reps: 1)
        _ = mixed.addSet(exercise: ringDip, weight: 0, reps: 10)
        try context.save()

        let before = try storedLoads()
        XCTAssertEqual(expected, workoutCount * setsPerWorkout)
        XCTAssertEqual(
            try storedSets().filter(\.holdsUnlabeledWholePounds).count,
            expected,
            "The fixture and the rule agree on what an earlier set is"
        )

        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: expected))

        let relabeled = try storedSets().filter { $0.relabeledFromPounds != nil }
        XCTAssertEqual(relabeled.count, expected)
        XCTAssertTrue(
            relabeled.allSatisfy { $0.loadUnit == .kilograms && $0.load(in: .kilograms) == Double($0.relabeledFromPounds ?? -1) },
            "Each set reads, in kilograms, the number it was stored with"
        )
        XCTAssertEqual(relabeler.status(for: .pounds), .relabeled(setCount: expected))
        XCTAssertEqual(kilogram.load(in: .kilograms), 100)
        XCTAssertNil(kilogram.relabeledFromPounds)
        XCTAssertEqual(tooLarge.weight, 4_501)
        XCTAssertNil(tooLarge.loadValue)

        XCTAssertEqual(relabeler.undoRelabel(), .changed(sets: expected))

        XCTAssertEqual(try storedLoads(), before)
        XCTAssertTrue(try storedSets().allSatisfy { $0.relabeledFromPounds == nil })
    }

    // MARK: - Only what was entered before the lifter had kilograms

    func testFirstKilogramMomentIsRecordedOnceAndNeverWhileInPounds() throws {
        let firstSwitch = firstSession.addingTimeInterval(30 * 86_400)
        clock.now = firstSwitch

        _ = relabeler.status(for: .pounds)
        _ = relabeler.question(afterSwitchingTo: .pounds)
        XCTAssertNil(recordedFirstKilogramChoice, "A lifter who has only trained in pounds has made no such choice")

        _ = relabeler.status(for: .kilograms)
        XCTAssertEqual(recordedFirstKilogramChoice, firstSwitch)

        clock.now = firstSwitch.addingTimeInterval(90 * 86_400)
        _ = relabeler.status(for: .kilograms)
        _ = relabeler.question(afterSwitchingTo: .kilograms)
        relabeler.relabelEarlierSetsAsKilograms()
        XCTAssertEqual(recordedFirstKilogramChoice, firstSwitch, "The first choice stays the first choice")
    }

    func testSwitchingWithTheQuestionAlreadyAnsweredStillRecordsTheMoment() throws {
        clock.now = firstSession.addingTimeInterval(30 * 86_400)
        relabeler.recordPromptAnswered()

        XCTAssertNil(relabeler.question(afterSwitchingTo: .kilograms))

        XCTAssertEqual(recordedFirstKilogramChoice, clock.now)
    }

    func testPoundSetsLoggedAfterTheLifterHadKilogramsAreNeverRelabeled() throws {
        let earlier = try insertFinishedWorkout(bench, loads: [(100, 5)])
        let firstSwitch = firstSession.addingTimeInterval(30 * 86_400)
        clock.now = firstSwitch
        XCTAssertNotNil(relabeler.question(afterSwitchingTo: .kilograms))

        // Back on pounds for a trip, and logging real pounds.
        let trip = try insertFinishedWorkout(bench, loads: [(225, 5)], at: firstSwitch.addingTimeInterval(10 * 86_400))
        let tripLoad = try XCTUnwrap(trip.sets.first).storedLoad

        XCTAssertEqual(
            relabeler.status(for: .kilograms),
            .readAsPounds(KilogramRelabelPolicy.Preview(setCount: 1, exerciseName: "Bench Press", number: 100)),
            "Only the set from before is offered, and it is the example"
        )
        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 1))

        XCTAssertEqual(kilograms(earlier), [100])
        XCTAssertEqual(trip.sets.first?.storedLoad, tripLoad, "225 lb stays 225 lb")
        XCTAssertNil(trip.sets.first?.relabeledFromPounds)
    }

    func testLifterWhoStartedInKilogramsIsNeverAsked() throws {
        // A new install outside the US: kilograms from the first day.
        clock.now = firstSession
        XCTAssertEqual(relabeler.status(for: .kilograms), .nothingToOffer)

        let kilogramDay = Workout(date: firstSession.addingTimeInterval(86_400), name: "Kilogram Day", isCompleted: true)
        context.insert(kilogramDay)
        let kilogramSet = kilogramDay.addSet(exercise: bench, weight: 0, reps: 5)
        kilogramSet.setLoad(100, in: .kilograms)
        kilogramSet.completedAt = firstSession.addingTimeInterval(86_400 + 600)
        try context.save()
        let trip = try insertFinishedWorkout(bench, loads: [(225, 5)], at: firstSession.addingTimeInterval(20 * 86_400))

        XCTAssertNil(relabeler.question(afterSwitchingTo: .kilograms))
        XCTAssertEqual(relabeler.status(for: .kilograms), .nothingToOffer)
        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .nothingToChange)

        XCTAssertEqual(trip.sets.first?.weight, 225)
        XCTAssertNil(trip.sets.first?.loadValue)
        XCTAssertNil(trip.sets.first?.relabeledFromPounds)
    }

    func testUndoThenRelabelComesBackToTheSameSetsWithPoundSetsLoggedInBetween() throws {
        let earlier = try insertFinishedWorkout(bench, loads: [(100, 5), (90, 6)])
        let firstSwitch = firstSession.addingTimeInterval(30 * 86_400)
        clock.now = firstSwitch
        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 2))

        let trip = try insertFinishedWorkout(bench, loads: [(225, 5)], at: firstSwitch.addingTimeInterval(10 * 86_400))
        let tripLoad = try XCTUnwrap(trip.sets.first).storedLoad

        XCTAssertEqual(relabeler.undoRelabel(), .changed(sets: 2))
        XCTAssertEqual(
            relabeler.status(for: .kilograms),
            .readAsPounds(KilogramRelabelPolicy.Preview(setCount: 2, exerciseName: "Bench Press", number: 90))
        )
        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 2))

        let expectedKilograms: [Double] = [100, 90]
        XCTAssertEqual(kilograms(earlier), expectedKilograms)
        XCTAssertEqual(trip.sets.first?.storedLoad, tripLoad, "The pound set from the trip is never swept in")
    }

    func testPlannedSetInAWorkoutStartedAfterTheLifterHadKilogramsIsNotRelabeled() throws {
        try insertFinishedWorkout(bench, loads: [(100, 5)])
        let firstSwitch = firstSession.addingTimeInterval(30 * 86_400)
        clock.now = firstSwitch
        _ = relabeler.status(for: .kilograms)

        let draft = Workout(date: firstSwitch.addingTimeInterval(86_400), name: "Planned in pounds")
        context.insert(draft)
        let planned = draft.addSet(exercise: bench, weight: 225, reps: 5)
        planned.completedAt = .distantPast
        try context.save()

        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 1))

        XCTAssertEqual(planned.weight, 225)
        XCTAssertNil(planned.loadValue)
    }

    func testUndoKeepsASetLoggedSinceTheRelabel() throws {
        try insertFinishedWorkout(bench, loads: [(100, 5)])
        let draft = Workout(date: firstSession.addingTimeInterval(86_400), name: "Saved for later")
        context.insert(draft)
        let planned = draft.addSet(exercise: bench, weight: 100, reps: 5)
        planned.completedAt = .distantPast
        try context.save()
        let firstSwitch = firstSession.addingTimeInterval(30 * 86_400)
        clock.now = firstSwitch
        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 2))

        // The lifter trains the saved workout at the 100 kg it shows and
        // checks the set off. Logging stamps the time and nothing else.
        planned.completedAt = firstSwitch.addingTimeInterval(86_400)
        try context.save()

        XCTAssertEqual(relabeler.undoRelabel(), .changed(sets: 1))

        XCTAssertEqual(planned.load(in: .kilograms), 100, "A set performed and logged at 100 kg is not turned into 100 lb")
        XCTAssertEqual(planned.loadUnit, .kilograms)
        XCTAssertNil(planned.relabeledFromPounds)
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
        let failing = makeRelabeler(using: FailingDataManager(context: context))

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
        let failing = makeRelabeler(using: FailingDataManager(context: context))

        XCTAssertEqual(failing.undoRelabel(), .failed)

        XCTAssertEqual(try storedLoads(), loadsAfterRelabel)
        let expectedMarks: [Int?] = [100, 90]
        XCTAssertEqual(benchDay.setsInLoggedOrder.map(\.relabeledFromPounds), expectedMarks)
        XCTAssertEqual(revision, revisionAfterRelabel)
        XCTAssertEqual(relabeler.status(for: .kilograms), .relabeled(setCount: 2))
    }

    func testWorkLeftUnsavedByAnotherScreenSurvivesAFailedRelabel() throws {
        try insertFinishedWorkout(bench, loads: [(100, 5)])
        let pending = Workout(date: firstSession.addingTimeInterval(86_400), name: "Not saved yet")
        context.insert(pending)
        let saving = FailingAfterDataManager(context: context, savesThatSucceed: 1)
        let failing = makeRelabeler(using: saving)

        XCTAssertEqual(failing.relabelEarlierSetsAsKilograms(), .failed)

        XCTAssertEqual(saving.saveAttempts, 2, "What was pending is saved on its own, before anything is rewritten")
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<Workout>()).contains { $0.name == "Not saved yet" },
            "Rolling the relabel back must not take another screen's work with it"
        )
        XCTAssertTrue(try storedSets().allSatisfy { $0.relabeledFromPounds == nil && $0.loadUnit == .pounds })
    }

    func testRelabelDoesNotStartWhenPendingWorkCannotBeSaved() throws {
        let benchDay = try insertFinishedWorkout(bench, loads: [(100, 5)])
        context.insert(Workout(date: firstSession.addingTimeInterval(86_400), name: "Not saved yet"))
        let saving = FailingAfterDataManager(context: context, savesThatSucceed: 0)
        let failing = makeRelabeler(using: saving)

        XCTAssertEqual(failing.relabelEarlierSetsAsKilograms(), .failed)

        XCTAssertEqual(saving.saveAttempts, 1)
        XCTAssertEqual(benchDay.sets.first?.weight, 100)
        XCTAssertNil(benchDay.sets.first?.relabeledFromPounds)
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
            relabeler.status(for: .kilograms),
            .readAsPounds(KilogramRelabelPolicy.Preview(setCount: 4, exerciseName: "Squat", number: 140)),
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
            relabeler.status(for: .kilograms),
            .readAsPounds(KilogramRelabelPolicy.Preview(setCount: 1, exerciseName: nil, number: nil))
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
