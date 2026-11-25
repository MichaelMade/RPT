//
//  KilogramRelabelTests.swift
//  RPTTests
//
//  A lifter who typed kilograms into RPT while it only knew pounds can have
//  those earlier sets relabeled, and can undo it. These cover the rule for
//  one set, the totals a user stores, and what the lifter is asked.
//

import XCTest
@testable import RPT

final class KilogramRelabelSetTests: XCTestCase {
    private func makeSet(weight: Int = 0, reps: Int = 5, category: ExerciseCategory = .compound) -> ExerciseSet {
        let exercise = Exercise(name: "Bench", category: category, primaryMuscleGroups: [.chest])
        return ExerciseSet(weight: weight, reps: reps, exercise: exercise)
    }

    // MARK: - Relabel

    func testRelabelReadsTheStoredNumberAsKilograms() {
        let set = makeSet(weight: 100)

        XCTAssertTrue(set.relabelAsKilograms())

        XCTAssertEqual(set.loadUnit, .kilograms)
        XCTAssertEqual(set.load(in: .kilograms), 100)
        XCTAssertEqual(set.writtenLoad(in: .kilograms), "100")
        XCTAssertEqual(set.weight, 220, "The whole-pound shadow follows the real load")
        XCTAssertEqual(set.exactPounds, 220.462, accuracy: 0.001)
        XCTAssertEqual(set.relabeledFromPounds, 100)
    }

    func testRelabelLeavesEverythingButTheLoadAlone() {
        let set = makeSet(weight: 100, reps: 6)
        let loggedAt = Date(timeIntervalSince1970: 1_760_000_000)
        set.completedAt = loggedAt
        set.rpe = 9
        set.isWarmup = true
        set.orderIndex = 3
        set.notes = "paused"

        XCTAssertTrue(set.relabelAsKilograms())

        XCTAssertEqual(set.reps, 6)
        XCTAssertEqual(set.completedAt, loggedAt)
        XCTAssertEqual(set.rpe, 9)
        XCTAssertTrue(set.isWarmup)
        XCTAssertEqual(set.orderIndex, 3)
        XCTAssertEqual(set.notes, "paused")
    }

    func testSetLoggedInPoundsAfterUnitsExistedIsStillABareNumber() {
        let set = makeSet()
        set.setLoad(225, in: .pounds)

        XCTAssertTrue(set.holdsUnlabeledWholePounds)
        XCTAssertTrue(set.relabelAsKilograms())
        XCTAssertEqual(set.load(in: .kilograms), 225)
    }

    func testSetsLoggedInKilogramsAreNeverRelabeled() {
        let fractional = makeSet()
        fractional.setLoad(62.5, in: .kilograms)
        let whole = makeSet()
        whole.setLoad(100, in: .kilograms)

        for set in [fractional, whole] {
            let before = set.storedLoad
            XCTAssertFalse(set.holdsUnlabeledWholePounds)
            XCTAssertFalse(set.relabelAsKilograms())
            XCTAssertEqual(set.storedLoad, before)
            XCTAssertNil(set.relabeledFromPounds)
        }
    }

    func testSetWithNoLoadIsNotRelabeled() {
        let bodyweight = makeSet(weight: 0, category: .bodyweight)

        XCTAssertFalse(bodyweight.relabelAsKilograms())

        XCTAssertEqual(bodyweight.weight, 0)
        XCTAssertNil(bodyweight.loadValue)
        XCTAssertNil(bodyweight.relabeledFromPounds)
    }

    func testNumberAboveWhatAKilogramEntryAcceptsIsLeftAsItIs() {
        let ceiling = Int(WeightUnit.kilograms.maximumLoad)
        let atCeiling = makeSet(weight: ceiling)
        let aboveCeiling = makeSet(weight: ceiling + 1)

        XCTAssertTrue(atCeiling.relabelAsKilograms())
        XCTAssertEqual(atCeiling.load(in: .kilograms), Double(ceiling))

        XCTAssertFalse(aboveCeiling.relabelAsKilograms(), "It could not be relabeled without changing the number")
        XCTAssertEqual(aboveCeiling.weight, ceiling + 1)
        XCTAssertNil(aboveCeiling.loadValue)
        XCTAssertNil(aboveCeiling.relabeledFromPounds)
    }

    func testRelabelingTwiceDoesNotConvertTwice() {
        let set = makeSet(weight: 100)

        XCTAssertTrue(set.relabelAsKilograms())
        XCTAssertFalse(set.relabelAsKilograms())

        XCTAssertEqual(set.load(in: .kilograms), 100)
        XCTAssertEqual(set.relabeledFromPounds, 100)
    }

    // MARK: - Undo

    func testUndoPutsTheWholePoundNumberBack() {
        let set = makeSet(weight: 100)
        let original = set.storedLoad
        set.relabelAsKilograms()

        XCTAssertTrue(set.undoKilogramRelabel())

        XCTAssertEqual(set.storedLoad, original)
        XCTAssertEqual(set.loadUnit, .pounds)
        XCTAssertEqual(set.exactPounds, 100)
        XCTAssertNil(set.relabeledFromPounds)
    }

    func testEveryWholeNumberSurvivesRelabelAndUndoExactly() {
        let ceiling = Int(WeightUnit.kilograms.maximumLoad)
        var mismatches: [Int] = []

        for pounds in 1...ceiling {
            let set = makeSet(weight: pounds)
            let original = set.storedLoad

            let relabeled = set.relabelAsKilograms()
            let readsAsTyped = set.load(in: .kilograms) == Double(pounds) && set.weight >= 1
            let undone = set.undoKilogramRelabel()

            if !relabeled || !readsAsTyped || !undone || set.storedLoad != original || set.relabeledFromPounds != nil {
                mismatches.append(pounds)
            }
        }

        XCTAssertEqual(mismatches, [])
    }

    func testUndoKeepsALoadEditedSinceTheRelabel() {
        let set = makeSet(weight: 100)
        set.relabelAsKilograms()
        set.setLoad(102.5, in: .kilograms)

        XCTAssertFalse(set.undoKilogramRelabel())

        XCTAssertEqual(set.load(in: .kilograms), 102.5)
        XCTAssertEqual(set.loadUnit, .kilograms)
        XCTAssertNil(set.relabeledFromPounds, "The set is no longer part of the relabel either way")
    }

    func testUndoKeepsALoadReenteredInPounds() {
        let set = makeSet(weight: 100)
        set.relabelAsKilograms()
        set.setLoad(225, in: .pounds)

        XCTAssertFalse(set.undoKilogramRelabel())

        XCTAssertEqual(set.weight, 225)
        XCTAssertEqual(set.loadUnit, .pounds)
        XCTAssertNil(set.relabeledFromPounds)
    }

    func testUndoRestoresASetEditedBackToTheRelabeledLoad() {
        let set = makeSet(weight: 100)
        set.relabelAsKilograms()
        set.setLoad(105, in: .kilograms)
        set.setLoad(100, in: .kilograms)

        XCTAssertTrue(set.undoKilogramRelabel())

        XCTAssertEqual(set.weight, 100)
        XCTAssertEqual(set.loadUnit, .pounds)
    }

    func testUndoDoesNothingToASetThatWasNeverRelabeled() {
        let pounds = makeSet(weight: 135)
        let kilograms = makeSet()
        kilograms.setLoad(100, in: .kilograms)

        for set in [pounds, kilograms] {
            let before = set.storedLoad
            XCTAssertFalse(set.undoKilogramRelabel())
            XCTAssertEqual(set.storedLoad, before)
        }
    }

    // MARK: - Which sets are earlier sets

    func testLoggedSetWasEnteredWhenItWasLogged() {
        let set = makeSet(weight: 100)
        let loggedAt = Date(timeIntervalSince1970: 1_760_000_600)
        set.completedAt = loggedAt
        let workout = Workout(date: Date(timeIntervalSince1970: 1_750_000_000), name: "Bench Day")
        set.workout = workout

        XCTAssertEqual(set.loadEnteredAt, loggedAt)
    }

    func testPlannedSetWasEnteredWhenItsWorkoutWasStarted() {
        let set = makeSet(weight: 100)
        set.completedAt = .distantPast
        let started = Date(timeIntervalSince1970: 1_760_000_000)
        set.workout = Workout(date: started, name: "Today")

        XCTAssertEqual(set.loadEnteredAt, started)

        set.workout = nil
        XCTAssertEqual(set.loadEnteredAt, .distantPast, "With nothing to date it by, it counts as old")
    }

    func testOnlyNumbersEnteredBeforeTheFirstKilogramLogCanBeRelabeled() {
        let firstKilogramLog = Date(timeIntervalSince1970: 1_770_000_000)
        let before = makeSet(weight: 100)
        before.completedAt = firstKilogramLog.addingTimeInterval(-86_400)
        let after = makeSet(weight: 225)
        after.completedAt = firstKilogramLog.addingTimeInterval(86_400)

        XCTAssertTrue(before.canBeRelabeledAsKilograms(beforeFirstKilogramLog: firstKilogramLog))
        XCTAssertFalse(
            after.canBeRelabeledAsKilograms(beforeFirstKilogramLog: firstKilogramLog),
            "Logged with the unit deliberately on pounds: it is pounds"
        )
        XCTAssertTrue(after.holdsUnlabeledWholePounds, "It is stored the same way, which is why the date decides")
    }

    func testEveryBareNumberCanBeRelabeledWhileNothingHasBeenLoggedInKilograms() {
        let old = makeSet(weight: 100)
        old.completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let recent = makeSet(weight: 105)
        recent.completedAt = Date()

        XCTAssertTrue(old.canBeRelabeledAsKilograms(beforeFirstKilogramLog: nil))
        XCTAssertTrue(recent.canBeRelabeledAsKilograms(beforeFirstKilogramLog: nil))
    }

    func testKilogramSetIsNotACandidateWhateverItsDate() {
        let set = makeSet()
        set.setLoad(100, in: .kilograms)
        set.completedAt = Date(timeIntervalSince1970: 1_000_000_000)

        XCTAssertFalse(set.canBeRelabeledAsKilograms(beforeFirstKilogramLog: nil))
        XCTAssertFalse(set.canBeRelabeledAsKilograms(beforeFirstKilogramLog: .distantFuture))
    }

    func testOnlyALoggedUnrelabeledKilogramSetCountsAsLoggingInKilograms() {
        let logged = makeSet()
        logged.setLoad(100, in: .kilograms)
        logged.completedAt = Date(timeIntervalSince1970: 1_770_000_000)
        XCTAssertTrue(logged.isLoggedInKilograms)

        let planned = makeSet()
        planned.setLoad(100, in: .kilograms)
        planned.completedAt = .distantPast
        XCTAssertFalse(planned.isLoggedInKilograms, "Planned, never performed")

        let relabeled = makeSet(weight: 100)
        relabeled.completedAt = Date(timeIntervalSince1970: 1_770_000_000)
        relabeled.relabelAsKilograms()
        XCTAssertFalse(relabeled.isLoggedInKilograms, "Typed before the lifter could say it was kilograms")

        let pounds = makeSet(weight: 225)
        pounds.completedAt = Date(timeIntervalSince1970: 1_770_000_000)
        XCTAssertFalse(pounds.isLoggedInKilograms)
    }

    // MARK: - Logging a relabeled set

    func testLoggingARelabeledSetTakesItOutOfTheRelabel() {
        let planned = makeSet(weight: 100)
        planned.completedAt = .distantPast
        planned.relabelAsKilograms()
        let loggedAt = Date(timeIntervalSince1970: 1_770_003_600)

        planned.markLogged(at: loggedAt)

        XCTAssertEqual(planned.completedAt, loggedAt)
        XCTAssertNil(planned.relabeledFromPounds)
        XCTAssertEqual(planned.load(in: .kilograms), 100, "Logging never changes the load")
        XCTAssertTrue(planned.isLoggedInKilograms)
        XCTAssertFalse(planned.undoKilogramRelabel(), "There is nothing left to undo on a set performed at 100 kg")
        XCTAssertEqual(planned.load(in: .kilograms), 100)
    }

    func testLogStateCanBePutBackWhenTheSaveFails() {
        let planned = makeSet(weight: 100)
        planned.completedAt = .distantPast
        planned.relabelAsKilograms()
        let before = planned.logState

        planned.markLogged(at: Date(timeIntervalSince1970: 1_770_003_600))
        planned.restoreLogState(before)

        XCTAssertEqual(planned.completedAt, .distantPast)
        XCTAssertEqual(planned.relabeledFromPounds, 100)
        XCTAssertTrue(planned.undoKilogramRelabel(), "Still part of the relabel, so still undone with it")
        XCTAssertEqual(planned.weight, 100)
    }

    func testLoggingAnOrdinarySetOnlyStampsTheTime() {
        let set = makeSet(weight: 135)
        set.completedAt = .distantPast
        let before = set.storedLoad

        set.markLogged(at: Date(timeIntervalSince1970: 1_770_003_600))

        XCTAssertEqual(set.storedLoad, before)
        XCTAssertNil(set.relabeledFromPounds)
    }

    func testSmallestLoadKeepsANonZeroPoundShadow() {
        let set = makeSet(weight: 1)

        XCTAssertTrue(set.relabelAsKilograms())

        XCTAssertEqual(set.load(in: .kilograms), 1)
        XCTAssertEqual(set.weight, 2)
        XCTAssertTrue(set.undoKilogramRelabel())
        XCTAssertEqual(set.weight, 1)
    }
}

final class KilogramRelabelPolicyTests: XCTestCase {
    private typealias Policy = KilogramRelabelPolicy

    private let preview = KilogramRelabelPolicy.Preview(setCount: 312, exerciseName: "Bench Press", number: 100)

    // MARK: - What is offered

    func testPoundLifterIsOfferedNothing() {
        XCTAssertEqual(Policy.status(unit: .pounds, relabeledSetCount: 0, preview: preview), .nothingToOffer)
        XCTAssertEqual(Policy.status(unit: .pounds, relabeledSetCount: 0, preview: nil), .nothingToOffer)
    }

    func testKilogramLifterWithBareNumbersCanRelabelThem() {
        XCTAssertEqual(Policy.status(unit: .kilograms, relabeledSetCount: 0, preview: preview), .readAsPounds(preview))
    }

    func testKilogramLifterWithNothingToRelabelIsOfferedNothing() {
        let empty = Policy.Preview(setCount: 0, exerciseName: nil, number: nil)

        XCTAssertEqual(Policy.status(unit: .kilograms, relabeledSetCount: 0, preview: nil), .nothingToOffer)
        XCTAssertEqual(Policy.status(unit: .kilograms, relabeledSetCount: 0, preview: empty), .nothingToOffer)
    }

    func testUndoIsOfferedInEitherUnitWhileRelabeledSetsExist() {
        for unit in WeightUnit.allCases {
            XCTAssertEqual(
                Policy.status(unit: unit, relabeledSetCount: 40, preview: preview),
                .relabeled(setCount: 40),
                "\(unit)"
            )
        }
    }

    // MARK: - The unprompted question

    func testQuestionIsRaisedOnlyBeforeItHasBeenAnswered() {
        XCTAssertEqual(Policy.question(hasAnswered: false, status: .readAsPounds(preview)), preview)
        XCTAssertNil(Policy.question(hasAnswered: true, status: .readAsPounds(preview)))
    }

    func testQuestionIsNotRaisedWhenThereIsNothingToRelabel() {
        XCTAssertNil(Policy.question(hasAnswered: false, status: .nothingToOffer))
        XCTAssertNil(Policy.question(hasAnswered: false, status: .relabeled(setCount: 12)))
    }

    // MARK: - Wording

    func testQuestionIsWrittenFromWhatIsStored() {
        let message = Policy.questionMessage(for: preview)

        XCTAssertEqual(
            message,
            "RPT stored 312 earlier sets as pounds. "
                + "The most recent, Bench Press, was entered as 100 and now reads 45.4 kg. "
                + "If you typed kilograms back then, RPT can relabel them so that 100 reads 100 kg. "
                + "You can undo this here in Settings."
        )
    }

    func testQuestionAboutASingleSet() {
        let single = Policy.Preview(setCount: 1, exerciseName: "Squat", number: 140)

        XCTAssertEqual(
            Policy.questionMessage(for: single),
            "RPT stored 1 earlier set as pounds. "
                + "It is a Squat set entered as 140, which now reads 63.5 kg. "
                + "If you typed kilograms back then, RPT can relabel it so that 140 reads 140 kg. "
                + "You can undo this here in Settings."
        )
    }

    func testQuestionFallsBackToAPlainExampleWhenNothingHasBeenLogged() {
        let planned = Policy.Preview(setCount: 3, exerciseName: nil, number: nil)

        XCTAssertEqual(
            Policy.questionMessage(for: planned),
            "RPT stored 3 earlier sets as pounds. "
                + "A set entered as 100 now reads 45.4 kg. "
                + "If you typed kilograms back then, RPT can relabel them so that 100 reads 100 kg. "
                + "You can undo this here in Settings."
        )
    }

    func testQuestionAssumesNothingAboutWhenTheLifterStarted() {
        // A lifter who has had kilograms for a year, or who logged in
        // kilograms last week, reads the same message. It must not claim
        // that pounds were all RPT knew "until now", or that the example is
        // their last set.
        let message = Policy.questionMessage(for: preview)

        XCTAssertFalse(message.contains("until now"), message)
        XCTAssertFalse(message.contains("your last"), message)
    }

    func testUndoExplainsWhatGoesBackAndWhatStays() {
        XCTAssertEqual(
            Policy.undoMessage(setCount: 312),
            "The 312 relabeled sets go back to pounds, so 100 kg reads 100 lb again. "
                + "Sets you have edited or logged since stay as they are. "
                + "Check the planned loads of any workout you saved for later."
        )
        XCTAssertTrue(Policy.undoMessage(setCount: 1).hasPrefix("The 1 relabeled set goes back to pounds"))
    }

    func testRowDetailCountsTheRelabeledSets() {
        XCTAssertEqual(Policy.relabeledDetail(setCount: 1), "1 set relabeled as kilograms")
        XCTAssertEqual(Policy.relabeledDetail(setCount: 312), "312 sets relabeled as kilograms")
    }

    func testBothAnswersAndTheUndoAreNamed() {
        XCTAssertEqual(Policy.questionTitle, "Were your earlier workouts logged in kilograms?")
        XCTAssertEqual(Policy.relabelAnswer, "They Were Kilograms")
        XCTAssertEqual(Policy.keepAnswer, "They Were Pounds")
        XCTAssertEqual(Policy.undoAnswer, "Undo Relabel")
    }
}

final class UserLoadTotalsCorrectionTests: XCTestCase {
    private func makeUser() -> User {
        User(username: "Lifter", email: "lifter@example.com")
    }

    private func completedWorkout(_ exercise: Exercise, loads: [(weight: Int, reps: Int)]) -> Workout {
        let workout = Workout(name: "Bench Day", isCompleted: true)
        for load in loads {
            _ = workout.addSet(exercise: exercise, weight: load.weight, reps: load.reps)
        }
        return workout
    }

    func testVolumeMovesByTheDifferenceAndNeverBelowZero() {
        let user = makeUser()
        user.totalVolume = 1_000

        user.correctLoadTotals(volumeDelta: 250.5, exerciseNames: [])
        XCTAssertEqual(user.totalVolume, 1_250.5, accuracy: 0.0001)

        user.correctLoadTotals(volumeDelta: -5_000, exerciseNames: [])
        XCTAssertEqual(user.totalVolume, 0, accuracy: 0.0001)
    }

    func testVolumeIgnoresADifferenceThatIsNotANumber() {
        let user = makeUser()
        user.totalVolume = 1_000

        user.correctLoadTotals(volumeDelta: .nan, exerciseNames: [])
        user.correctLoadTotals(volumeDelta: .infinity, exerciseNames: [])

        XCTAssertEqual(user.totalVolume, 1_000, accuracy: 0.0001)
    }

    func testBestIsReadAgainFromTheWorkoutsThatExist() {
        let user = makeUser()
        let bench = Exercise(name: "Bench", category: .compound, primaryMuscleGroups: [.chest])
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])
        let benchDay = completedWorkout(bench, loads: [(100, 5), (90, 6)])
        let squatDay = completedWorkout(squat, loads: [(140, 5)])
        user.registerCompletedWorkoutIfNeeded(benchDay)
        user.registerCompletedWorkoutIfNeeded(squatDay)
        XCTAssertEqual(user.personalBests, ["Bench": 100, "Squat": 140])

        for set in benchDay.sets {
            set.relabelAsKilograms()
        }
        user.correctLoadTotals(volumeDelta: 0, exerciseNames: ["Bench"])

        XCTAssertEqual(user.personalBests["Bench"], 220)
        XCTAssertEqual(user.personalBests["Squat"], 140, "A lift that was not named keeps its stored best")

        for set in benchDay.sets {
            set.undoKilogramRelabel()
        }
        user.correctLoadTotals(volumeDelta: 0, exerciseNames: ["Bench"])

        XCTAssertEqual(user.personalBests["Bench"], 100)
    }

    func testBestOfALiftWithNoRemainingSetsIsKept() {
        let user = makeUser()
        user.personalBests = ["Deadlift": 315]

        user.correctLoadTotals(volumeDelta: 0, exerciseNames: ["Deadlift"])

        XCTAssertEqual(user.personalBests["Deadlift"], 315)
    }

    func testWarmupsAndUnfinishedWorkoutsDoNotSetABest() {
        let user = makeUser()
        let bench = Exercise(name: "Bench", category: .compound, primaryMuscleGroups: [.chest])
        let finished = completedWorkout(bench, loads: [(100, 5)])
        user.registerCompletedWorkoutIfNeeded(finished)
        let warmup = finished.addSet(exercise: bench, weight: 400, reps: 1, isWarmup: true)
        XCTAssertTrue(warmup.isWarmup)
        let draft = Workout(name: "Today")
        _ = draft.addSet(exercise: bench, weight: 500, reps: 1)
        user.workouts.append(draft)

        user.correctLoadTotals(volumeDelta: 0, exerciseNames: ["Bench"])

        XCTAssertEqual(user.personalBests["Bench"], 100)
    }
}
