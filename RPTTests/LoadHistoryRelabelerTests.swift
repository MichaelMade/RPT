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
        LoadHistoryRelabeler(dataManager: manager, defaults: defaults)
    }

    /// A finished workout trained with RPT set to kilograms: every set
    /// carries its own unit and was logged with the unit on kilograms.
    @discardableResult
    private func insertKilogramWorkout(
        _ exercise: Exercise,
        loads: [(kilograms: Double, reps: Int)],
        at date: Date
    ) throws -> Workout {
        let workout = Workout(date: date, name: "\(exercise.name) Day, kg", isCompleted: true)
        context.insert(workout)
        for (index, load) in loads.enumerated() {
            let set = workout.addSet(exercise: exercise, weight: 0, reps: load.reps)
            set.setLoad(load.kilograms, in: .kilograms)
            set.markLogged(at: date.addingTimeInterval(TimeInterval(index + 1) * 180), unit: .kilograms)
        }
        try context.save()
        return workout
    }

    /// A finished workout trained with RPT deliberately set to pounds, by a
    /// build that records the unit in use.
    @discardableResult
    private func insertPoundWorkout(
        _ exercise: Exercise,
        loads: [(weight: Int, reps: Int)],
        at date: Date
    ) throws -> Workout {
        let workout = Workout(date: date, name: "\(exercise.name) Day, lb", isCompleted: true)
        context.insert(workout)
        for (index, load) in loads.enumerated() {
            let set = workout.addSet(exercise: exercise, weight: load.weight, reps: load.reps)
            set.markLogged(at: date.addingTimeInterval(TimeInterval(index + 1) * 180), unit: .pounds)
        }
        try context.save()
        return workout
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

    // MARK: - Only what was entered before the lifter logged in kilograms

    private var day: TimeInterval { 86_400 }

    func testPoundSetsLoggedAfterTheLifterStartedLoggingInKilogramsAreNeverRelabeled() throws {
        let earlier = try insertFinishedWorkout(bench, loads: [(100, 5)])
        try insertKilogramWorkout(bench, loads: [(102.5, 5)], at: firstSession.addingTimeInterval(30 * day))
        // Back on pounds for a trip, and logging real pounds.
        let trip = try insertPoundWorkout(bench, loads: [(225, 5)], at: firstSession.addingTimeInterval(40 * day))
        let tripLoad = try XCTUnwrap(trip.sets.first).storedLoad
        // Kilograms again afterwards: the line is the first kilogram set,
        // not the latest one.
        try insertKilogramWorkout(bench, loads: [(105, 5)], at: firstSession.addingTimeInterval(50 * day))

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
        // A new install outside the US: kilograms from the first day, then
        // one session with the unit on pounds.
        try insertKilogramWorkout(bench, loads: [(100, 5)], at: firstSession)
        let trip = try insertPoundWorkout(bench, loads: [(225, 5)], at: firstSession.addingTimeInterval(20 * day))

        XCTAssertNil(relabeler.question(afterSwitchingTo: .kilograms))
        XCTAssertEqual(relabeler.status(for: .kilograms), .nothingToOffer)
        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .nothingToChange)

        XCTAssertEqual(trip.sets.first?.weight, 225)
        XCTAssertNil(trip.sets.first?.loadValue)
        XCTAssertNil(trip.sets.first?.relabeledFromPounds)
    }

    func testLookingAtKilogramsWithoutLoggingInThemClosesNothingOff() throws {
        // The lifter this is for: typed kilograms for months, switches to
        // kg, sees 45.4 kg, taps They Were Pounds by reflex, goes back to
        // lb where the numbers look right, and carries on typing kilograms.
        try insertFinishedWorkout(bench, loads: [(100, 5), (90, 6)])
        XCTAssertNotNil(relabeler.question(afterSwitchingTo: .kilograms))
        relabeler.recordPromptAnswered()
        XCTAssertNil(relabeler.question(afterSwitchingTo: .pounds))
        try insertFinishedWorkout(bench, loads: [(105, 5), (95, 6)], at: firstSession.addingTimeInterval(40 * day))

        XCTAssertEqual(
            relabeler.status(for: .kilograms),
            .readAsPounds(KilogramRelabelPolicy.Preview(setCount: 4, exerciseName: "Bench Press", number: 95)),
            "Nothing was logged in kilograms, so every set is still theirs to relabel"
        )
        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 4))
        XCTAssertTrue(try storedSets().allSatisfy { $0.loadUnit == .kilograms })
    }

    func testAKilogramRowCheckedOffWithTheUnitBackOnPoundsIsNotTrainingInKilograms() throws {
        // Typed kilograms for months, switched to kg, tapped They Were
        // Pounds, started a workout (its rows are planned in kilograms from
        // the misread history), went back to lb where the top row reads
        // 110 lb, and checked it off.
        try insertFinishedWorkout(bench, loads: [(110, 5), (100, 6)])
        relabeler.recordPromptAnswered()
        let draft = Workout(date: firstSession.addingTimeInterval(10 * day), name: "Started while looking at kg")
        context.insert(draft)
        let planned = draft.addSet(exercise: bench, weight: 0, reps: 5)
        planned.setLoad(50, in: .kilograms)
        planned.completedAt = .distantPast
        try context.save()

        let viewModel = ActiveWorkoutViewModel(
            workout: draft,
            workoutManager: WorkoutManager(dataManager: dataManager)
        )
        XCTAssertEqual(viewModel.toggleSetLoggedSafely(planned, unit: .pounds), .logged)
        XCTAssertEqual(planned.loadUnit, .kilograms, "The row still holds the kilogram load it was planned with")
        try insertFinishedWorkout(bench, loads: [(112, 5), (102, 6)], at: firstSession.addingTimeInterval(20 * day))

        XCTAssertEqual(
            relabeler.status(for: .kilograms),
            .readAsPounds(KilogramRelabelPolicy.Preview(setCount: 4, exerciseName: "Bench Press", number: 102)),
            "Nothing was logged with the unit on kilograms, so every bare set is still on offer"
        )
        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 4))
    }

    func testCorrectingALoggedSetToKilogramsDoesNotBackdateTheLine() throws {
        // A parked workout with a set logged months ago, then months of
        // sessions typed in kilograms with the unit on pounds. The lifter
        // switches to kg and corrects the parked set in the editor.
        let parked = Workout(date: firstSession, name: "Parked")
        context.insert(parked)
        let loggedLongAgo = parked.addSet(exercise: bench, weight: 100, reps: 5)
        loggedLongAgo.completedAt = firstSession.addingTimeInterval(600)
        try context.save()
        try insertFinishedWorkout(bench, loads: [(105, 5)], at: firstSession.addingTimeInterval(30 * day))
        try insertFinishedWorkout(bench, loads: [(110, 5)], at: firstSession.addingTimeInterval(60 * day))

        let viewModel = ActiveWorkoutViewModel(
            workout: parked,
            workoutManager: WorkoutManager(dataManager: dataManager)
        )
        XCTAssertTrue(viewModel.updateSetSafely(loggedLongAgo, load: 100, unit: .kilograms, reps: 5, rpe: nil))
        XCTAssertEqual(loggedLongAgo.loadUnit, .kilograms)
        XCTAssertTrue(loggedLongAgo.isCompletedLoggedSet)

        XCTAssertEqual(
            relabeler.status(for: .kilograms),
            .readAsPounds(KilogramRelabelPolicy.Preview(setCount: 2, exerciseName: "Bench Press", number: 110)),
            "The months of sessions after it are still on offer"
        )
    }

    func testABareRowConfirmedWithTheUnitOnKilogramsIsNotRelabeled() throws {
        // A planned 100 (pounds) shown as 45.4 kg and checked off as shown.
        try insertFinishedWorkout(bench, loads: [(100, 5)])
        let draft = Workout(date: firstSession.addingTimeInterval(day), name: "Saved for later")
        context.insert(draft)
        let planned = draft.addSet(exercise: bench, weight: 100, reps: 5)
        planned.completedAt = .distantPast
        try context.save()
        let viewModel = ActiveWorkoutViewModel(
            workout: draft,
            workoutManager: WorkoutManager(dataManager: dataManager)
        )
        XCTAssertEqual(viewModel.toggleSetLoggedSafely(planned, unit: .kilograms), .logged)

        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 1))

        XCTAssertEqual(planned.weight, 100, "The lifter stood behind 45.4 kg, not 100 kg")
        XCTAssertNil(planned.loadValue)
        XCTAssertNil(planned.relabeledFromPounds)
    }

    func testASetOnlyPlannedInKilogramsIsNotTrainingInKilograms() throws {
        try insertFinishedWorkout(bench, loads: [(100, 5)])
        // A workout started with the unit on kg and never trained: its rows
        // carry kilograms, but nothing was logged.
        let draft = Workout(date: firstSession.addingTimeInterval(10 * day), name: "Started in kg")
        context.insert(draft)
        let planned = draft.addSet(exercise: bench, weight: 0, reps: 5)
        planned.setLoad(45, in: .kilograms)
        planned.completedAt = .distantPast
        try context.save()
        try insertFinishedWorkout(bench, loads: [(105, 5)], at: firstSession.addingTimeInterval(20 * day))

        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 2))

        XCTAssertEqual(planned.load(in: .kilograms), 45, "A kilogram row is never relabeled")
        XCTAssertNil(planned.relabeledFromPounds)
    }

    func testAPlannedKilogramRowDoesNotHideTheFirstSetLoggedInKilograms() throws {
        // The line is found by asking the store for the earliest kilogram
        // set. A row planned in kilograms and never logged carries no date,
        // so it must not be the one the store hands back.
        try insertFinishedWorkout(bench, loads: [(100, 5)])
        let draft = Workout(date: firstSession.addingTimeInterval(5 * day), name: "Started in kg")
        context.insert(draft)
        let planned = draft.addSet(exercise: bench, weight: 0, reps: 5)
        planned.setLoad(45, in: .kilograms)
        planned.completedAt = .distantPast
        try context.save()
        try insertKilogramWorkout(bench, loads: [(102.5, 5)], at: firstSession.addingTimeInterval(10 * day))
        let trip = try insertPoundWorkout(bench, loads: [(225, 5)], at: firstSession.addingTimeInterval(20 * day))

        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 1))

        XCTAssertEqual(trip.sets.first?.weight, 225)
        XCTAssertNil(trip.sets.first?.loadValue, "The trip came after a set really logged in kilograms")
    }

    func testAnUnloggedRowThatOnceWasLoggedInKilogramsDoesNotHideTheFirstRealLog() throws {
        // Clearing a set's values takes its log back without going through
        // the check, so the row can keep the unit it was once logged with.
        // It carries no date, and must not be the row the store hands back.
        try insertFinishedWorkout(bench, loads: [(100, 5)])
        let draft = Workout(date: firstSession.addingTimeInterval(5 * day), name: "Open")
        context.insert(draft)
        let cleared = draft.addSet(exercise: bench, weight: 0, reps: 5)
        cleared.setLoad(60, in: .kilograms)
        cleared.markLogged(at: firstSession.addingTimeInterval(5 * day + 600), unit: .kilograms)
        cleared.completedAt = .distantPast
        try context.save()
        try insertKilogramWorkout(bench, loads: [(102.5, 5)], at: firstSession.addingTimeInterval(10 * day))
        let trip = try insertPoundWorkout(bench, loads: [(225, 5)], at: firstSession.addingTimeInterval(20 * day))

        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 1))

        XCTAssertEqual(trip.sets.first?.weight, 225)
        XCTAssertNil(trip.sets.first?.loadValue, "The trip came after a session really trained in kilograms")
    }

    func testRelabeledHistoryDoesNotHideTheFirstSetLoggedInKilograms() throws {
        // Relabeled sets read as kilograms and are older than anything
        // logged in kilograms since. They must not be mistaken for it.
        try insertFinishedWorkout(bench, loads: [(100, 5)])
        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 1))
        try insertKilogramWorkout(bench, loads: [(102.5, 5)], at: firstSession.addingTimeInterval(10 * day))
        let trip = try insertPoundWorkout(bench, loads: [(225, 5)], at: firstSession.addingTimeInterval(20 * day))

        XCTAssertEqual(
            relabeler.relabelEarlierSetsAsKilograms(),
            .nothingToChange,
            "With history already relabeled, the only bare set left is the trip, and it is pounds"
        )

        XCTAssertEqual(trip.sets.first?.weight, 225)
        XCTAssertNil(trip.sets.first?.loadValue)
    }

    func testRelabeledSetsAreNotTrainingInKilograms() throws {
        // Relabeled history reads as kilograms but was typed before the
        // lifter could say so. It must not draw the line.
        try insertFinishedWorkout(bench, loads: [(100, 5), (90, 6)])
        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 2))
        try insertFinishedWorkout(bench, loads: [(105, 5)], at: firstSession.addingTimeInterval(20 * day))

        XCTAssertEqual(relabeler.undoRelabel(), .changed(sets: 2))

        XCTAssertEqual(
            relabeler.status(for: .kilograms),
            .readAsPounds(KilogramRelabelPolicy.Preview(setCount: 3, exerciseName: "Bench Press", number: 105))
        )
    }

    func testUndoThenRelabelComesBackToTheSameSetsWithPoundSetsLoggedInBetween() throws {
        let earlier = try insertFinishedWorkout(bench, loads: [(100, 5), (90, 6)])
        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 2))
        try insertKilogramWorkout(bench, loads: [(102.5, 5)], at: firstSession.addingTimeInterval(10 * day))
        let trip = try insertPoundWorkout(bench, loads: [(225, 5)], at: firstSession.addingTimeInterval(20 * day))
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

    func testPlannedSetInAWorkoutStartedAfterTheFirstKilogramLogIsNotRelabeled() throws {
        try insertFinishedWorkout(bench, loads: [(100, 5)])
        try insertKilogramWorkout(bench, loads: [(102.5, 5)], at: firstSession.addingTimeInterval(10 * day))
        let draft = Workout(date: firstSession.addingTimeInterval(20 * day), name: "Planned in pounds")
        context.insert(draft)
        let planned = draft.addSet(exercise: bench, weight: 225, reps: 5)
        planned.completedAt = .distantPast
        try context.save()

        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 1))

        XCTAssertEqual(planned.weight, 225)
        XCTAssertNil(planned.loadValue)
    }

    // MARK: - A set logged since the relabel

    func testLoggingARelabeledPlannedSetMakesItTheLiftersOwn() throws {
        try insertFinishedWorkout(bench, loads: [(100, 5)])
        let draft = Workout(date: firstSession.addingTimeInterval(day), name: "Saved for later")
        context.insert(draft)
        let planned = draft.addSet(exercise: bench, weight: 100, reps: 5)
        planned.completedAt = .distantPast
        try context.save()
        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 2))
        XCTAssertEqual(planned.relabeledFromPounds, 100)

        // The lifter trains the saved workout at the 100 kg it shows and
        // checks the set off, through the screen's own log path.
        let viewModel = ActiveWorkoutViewModel(
            workout: draft,
            workoutManager: WorkoutManager(dataManager: dataManager)
        )
        XCTAssertEqual(viewModel.toggleSetLoggedSafely(planned, unit: .kilograms), .logged)

        XCTAssertNil(planned.relabeledFromPounds, "Logged at 100 kg: it is their own kilogram entry now")
        XCTAssertTrue(planned.wasLoggedWithUnitOnKilograms)
        XCTAssertEqual(relabeler.status(for: .pounds), .relabeled(setCount: 1))
        XCTAssertEqual(relabeler.undoRelabel(), .changed(sets: 1))

        XCTAssertEqual(planned.load(in: .kilograms), 100, "A set performed and logged at 100 kg is not turned into 100 lb")
        XCTAssertEqual(planned.loadUnit, .kilograms)
    }

    func testLogThatDoesNotSaveLeavesTheSetPartOfTheRelabel() throws {
        let draft = Workout(date: firstSession, name: "Saved for later")
        context.insert(draft)
        let planned = draft.addSet(exercise: bench, weight: 100, reps: 5)
        planned.completedAt = .distantPast
        try context.save()
        XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 1))

        let failingModel = ActiveWorkoutViewModel(
            workout: draft,
            workoutManager: WorkoutManager(dataManager: FailingDataManager(context: context))
        )
        XCTAssertEqual(failingModel.toggleSetLoggedSafely(planned, unit: .kilograms), .failed)

        XCTAssertEqual(planned.relabeledFromPounds, 100, "The log did not happen, so neither did what it implies")
        XCTAssertFalse(planned.isCompletedLoggedSet)
        XCTAssertNil(planned.loggedUnitRaw)
        XCTAssertEqual(relabeler.undoRelabel(), .changed(sets: 1))
        XCTAssertEqual(planned.weight, 100)
        XCTAssertEqual(planned.loadUnit, .pounds)
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
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<Workout>()).contains { $0.name == "Not saved yet" },
            "Refusing to start must not throw the other screen's unsaved work away"
        )
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
