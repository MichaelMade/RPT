//
//  TrainingDataIntegrityTests.swift
//  RPTTests
//
//  Regression tests for the numbers a lifter trusts: typed input, the day a
//  session is filed under, the streak, exported dates, and RPT drop settings.
//

import XCTest
@testable import RPT

// MARK: - Typed Input

final class SetInputParserTests: XCTestCase {
    func testWholeNumberAcceptsPlainDigitsAndTreatsEmptyAsZero() {
        XCTAssertEqual(SetInputParser.weight(from: "185"), 185)
        XCTAssertEqual(SetInputParser.weight(from: "  225 "), 225)
        XCTAssertEqual(SetInputParser.weight(from: ""), 0, "A cleared field means zero")
        XCTAssertEqual(SetInputParser.reps(from: "   "), 0, "Whitespace is a cleared field")
        XCTAssertEqual(SetInputParser.reps(from: "0"), 0)
    }

    func testWholeNumberRejectsAnythingThatIsNotAWholeNumber() {
        // These used to be saved silently as 0, which also un-logged the set.
        XCTAssertNil(SetInputParser.weight(from: "82.5"))
        XCTAssertNil(SetInputParser.weight(from: "82,5"))
        XCTAssertNil(SetInputParser.weight(from: "-45"))
        XCTAssertNil(SetInputParser.weight(from: "12a"))
        XCTAssertNil(SetInputParser.reps(from: "eight"))
        XCTAssertNil(SetInputParser.reps(from: "1 0"))
    }

    func testWholeNumberAcceptsDigitsFromOtherNumberingSystems() {
        // The number pad follows the device's numbering system.
        XCTAssertEqual(SetInputParser.weight(from: "١٨٥"), 185, "Arabic-Indic digits")
        XCTAssertEqual(SetInputParser.reps(from: "१२"), 12, "Devanagari digits")
    }

    func testWholeNumberEnforcesBoundsWithoutOverflowing() {
        XCTAssertEqual(SetInputParser.weight(from: "\(SetInputParser.maxWeight)"), SetInputParser.maxWeight)
        XCTAssertNil(SetInputParser.weight(from: "\(SetInputParser.maxWeight + 1)"))
        XCTAssertEqual(SetInputParser.reps(from: "\(SetInputParser.maxReps)"), SetInputParser.maxReps)
        XCTAssertNil(SetInputParser.reps(from: "\(SetInputParser.maxReps + 1)"))

        // Longer than Int can hold: must be rejected, not trap.
        XCTAssertNil(SetInputParser.weight(from: String(repeating: "9", count: 40)))
    }

    func testBoundsKeepVolumeMathWellInsideInt() {
        let (volume, overflowed) = SetInputParser.maxWeight.multipliedReportingOverflow(by: SetInputParser.maxReps)
        XCTAssertFalse(overflowed)
        XCTAssertLessThan(volume, 10_000_000)
    }

    func testDecimalAcceptsDotAndCommaSeparators() throws {
        XCTAssertEqual(try XCTUnwrap(SetInputParser.decimal(from: "82.5")), 82.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(SetInputParser.decimal(from: "82,5")), 82.5, accuracy: 0.0001,
                       "The decimal pad types a comma in most non-US regions")
        XCTAssertEqual(try XCTUnwrap(SetInputParser.decimal(from: " 100 ")), 100, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(SetInputParser.decimal(from: "٨٢٫٥")), 82.5, accuracy: 0.0001,
                       "Arabic digits and decimal separator")
    }

    func testDecimalRejectsMalformedAndOutOfRangeText() {
        XCTAssertNil(SetInputParser.decimal(from: ""))
        XCTAssertNil(SetInputParser.decimal(from: "."))
        XCTAssertNil(SetInputParser.decimal(from: "1.2.3"))
        XCTAssertNil(SetInputParser.decimal(from: "1,234.5"), "Grouping separators are not supported")
        XCTAssertNil(SetInputParser.decimal(from: "abc"))
        XCTAssertNil(SetInputParser.decimal(from: "-20"))
        XCTAssertNil(SetInputParser.decimal(from: String(repeating: "9", count: 40)),
                     "An absurd entry must not reach the plate math")
    }
}

// MARK: - Day A Parked Draft Is Filed Under

@MainActor
final class ParkedDraftDateTests: XCTestCase {
    private let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

    func testDraftTrainedDaysLaterMovesToTheDayItWasTrained() {
        let now = Date()
        let created = now.addingTimeInterval(-3 * 24 * 60 * 60)
        let workout = Workout(date: created, name: "Saved For Later")

        let topSet = workout.addSet(exercise: bench, weight: 200, reps: 5)
        topSet.completedAt = now.addingTimeInterval(-40 * 60)
        let backoff = workout.addSet(exercise: bench, weight: 180, reps: 7)
        backoff.completedAt = now.addingTimeInterval(-5 * 60)

        workout.alignDateWithFirstLoggedSet(now: now)
        workout.complete(now: now)

        XCTAssertEqual(workout.date, topSet.completedAt, "The session belongs to the day its first set was logged")
        XCTAssertEqual(workout.duration, 40 * 60, accuracy: 1, "Duration runs from the first logged set, not the draft's creation")
    }

    func testDraftWithOneSetLoggedDaysLaterGetsASaneDuration() {
        let now = Date()
        let workout = Workout(date: now.addingTimeInterval(-2 * 24 * 60 * 60), name: "Saved For Later")
        let onlySet = workout.addSet(exercise: bench, weight: 200, reps: 5)
        onlySet.completedAt = now.addingTimeInterval(-90)

        workout.alignDateWithFirstLoggedSet(now: now)
        workout.complete(now: now)

        XCTAssertEqual(workout.date, onlySet.completedAt)
        XCTAssertEqual(workout.duration, 90, accuracy: 1, "Two idle days must not become a 48-hour workout")
    }

    func testNormalSessionKeepsItsStartTime() {
        let now = Date()
        let started = now.addingTimeInterval(-50 * 60)
        let workout = Workout(date: started, name: "Today")
        let set = workout.addSet(exercise: bench, weight: 200, reps: 5)
        set.completedAt = now.addingTimeInterval(-45 * 60)

        workout.alignDateWithFirstLoggedSet(now: now)

        XCTAssertEqual(workout.date, started)
    }

    func testLateSessionThatCrossesMidnightKeepsTheDayItBegan() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Chicago"))

        let started = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 23, minute: 50)))
        let firstSetAt = started.addingTimeInterval(20 * 60) // 00:10 the next day
        let now = started.addingTimeInterval(70 * 60)

        let workout = Workout(date: started, name: "Late Session")
        let set = workout.addSet(exercise: bench, weight: 200, reps: 5)
        set.completedAt = firstSetAt

        workout.alignDateWithFirstLoggedSet(now: now, calendar: calendar)

        XCTAssertEqual(workout.date, started, "A session in progress is not a parked draft")
    }

    func testDraftParkedOvernightMovesToTheNextDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Chicago"))

        let created = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 22)))
        let firstSetAt = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 11, hour: 6, minute: 30)))
        let now = firstSetAt.addingTimeInterval(45 * 60)

        let workout = Workout(date: created, name: "Planned The Night Before")
        let set = workout.addSet(exercise: bench, weight: 200, reps: 5)
        set.completedAt = firstSetAt

        workout.alignDateWithFirstLoggedSet(now: now, calendar: calendar)

        XCTAssertEqual(workout.date, firstSetAt)
    }

    func testAlignmentIgnoresUnloggedWarmupOnlyAndCompletedWorkouts() {
        let now = Date()
        let created = now.addingTimeInterval(-3 * 24 * 60 * 60)

        let nothingLogged = Workout(date: created, name: "Nothing Logged")
        let planned = nothingLogged.addSet(exercise: bench, weight: 200, reps: 5)
        planned.completedAt = .distantPast
        nothingLogged.alignDateWithFirstLoggedSet(now: now)
        XCTAssertEqual(nothingLogged.date, created)

        let alreadyCompleted = Workout(date: created, name: "History", isCompleted: true)
        let set = alreadyCompleted.addSet(exercise: bench, weight: 200, reps: 5)
        set.completedAt = now.addingTimeInterval(-60)
        alreadyCompleted.alignDateWithFirstLoggedSet(now: now)
        XCTAssertEqual(alreadyCompleted.date, created, "Completed history is never re-dated")

        let futureStamp = Workout(date: created, name: "Clock Skew")
        let skewed = futureStamp.addSet(exercise: bench, weight: 200, reps: 5)
        skewed.completedAt = now.addingTimeInterval(60 * 60)
        futureStamp.alignDateWithFirstLoggedSet(now: now)
        XCTAssertEqual(futureStamp.date, created, "A timestamp from the future is not trusted")
    }
}

// MARK: - Streak

@MainActor
final class WorkoutStreakTests: XCTestCase {
    private let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

    private func completedWorkout(daysAgo: Int, from now: Date) -> Workout {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
        let workout = Workout(date: date, name: "Day -\(daysAgo)")
        _ = workout.addSet(exercise: bench, weight: 185, reps: 5)
        workout.complete()
        return workout
    }

    func testConsecutiveTrainingDaysCountsTheRunEndingOnTheLatestDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))

        func march(_ day: Int, hour: Int = 18) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour))!
        }

        XCTAssertEqual(User.consecutiveTrainingDays(in: [], calendar: calendar), 0)
        XCTAssertEqual(User.consecutiveTrainingDays(in: [march(5)], calendar: calendar), 1)

        let twoSessionsOneDay = [march(5), march(6, hour: 7), march(6, hour: 19)]
        XCTAssertEqual(
            User.consecutiveTrainingDays(in: twoSessionsOneDay, calendar: calendar),
            2,
            "Two sessions on one day count once"
        )

        let missedDay = [march(2), march(3), march(5), march(6), march(7)]
        XCTAssertEqual(
            User.consecutiveTrainingDays(in: missedDay, calendar: calendar),
            3,
            "A missed day ends the run; only the latest run counts"
        )

        // Spring-forward weekend in New York (March 8, 2026 is a 23-hour day).
        let acrossClockChange = [march(7), march(8), march(9)]
        XCTAssertEqual(
            User.consecutiveTrainingDays(in: acrossClockChange, calendar: calendar),
            3,
            "A daylight-saving change must not break a run"
        )
    }

    func testStreakIsTheSameWhateverOrderWorkoutsAreRegisteredIn() {
        let now = Date()
        let user = User(username: "TestUser", email: "test@example.com")

        // Today's and yesterday's sessions register first; a draft dated two
        // days ago is finished last. Counting incrementally reset this to 1.
        for daysAgo in [1, 0, 2] {
            XCTAssertTrue(user.registerCompletedWorkoutIfNeeded(completedWorkout(daysAgo: daysAgo, from: now)))
        }

        XCTAssertEqual(user.workoutStreak, 3)
        XCTAssertEqual(user.currentWorkoutStreak(asOf: now), 3)
    }

    func testStreakShrinksWhenAWorkoutLeavesHistory() {
        let now = Date()
        let user = User(username: "TestUser", email: "test@example.com")
        let workouts = [2, 1, 0].map { completedWorkout(daysAgo: $0, from: now) }
        workouts.forEach { XCTAssertTrue(user.registerCompletedWorkoutIfNeeded($0)) }
        XCTAssertEqual(user.currentWorkoutStreak(asOf: now), 3)

        // Deleting a workout removes it from the relationship.
        user.workouts.removeAll { $0 === workouts[1] }
        XCTAssertEqual(user.currentWorkoutStreak(asOf: now), 1, "Yesterday is gone, so only today's session is left in the run")

        user.workouts.removeAll { $0 === workouts[2] }
        XCTAssertEqual(user.currentWorkoutStreak(asOf: now), 0, "The latest remaining session is two days old")
    }

    func testReloggingADeletedDayDoesNotInflateTheStreak() {
        let now = Date()
        let user = User(username: "TestUser", email: "test@example.com")
        let yesterday = completedWorkout(daysAgo: 1, from: now)
        let today = completedWorkout(daysAgo: 0, from: now)
        XCTAssertTrue(user.registerCompletedWorkoutIfNeeded(yesterday))
        XCTAssertTrue(user.registerCompletedWorkoutIfNeeded(today))

        // Delete today's accidental duplicate and log it again.
        user.workouts.removeAll { $0 === today }
        XCTAssertTrue(user.registerCompletedWorkoutIfNeeded(completedWorkout(daysAgo: 0, from: now)))

        XCTAssertEqual(user.workoutStreak, 2)
        XCTAssertEqual(user.currentWorkoutStreak(asOf: now), 2, "Two training days are a two-day streak")
    }
}

// MARK: - CSV Export Dates

@MainActor
final class CSVExportDateTests: XCTestCase {
    func testEveningWorkoutExportsOnTheLocalCalendarDay() throws {
        let losAngeles = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = losAngeles

        // 7:30 pm on Nov 10 in Los Angeles is already Nov 11 in UTC.
        let evening = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 19, minute: 30)))
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let workout = Workout(date: evening, name: "Evening Session", isCompleted: true)
        _ = workout.addSet(exercise: exercise, weight: 225, reps: 5)

        let lines = WorkoutCSVExporter.csv(for: [workout], timeZone: losAngeles).components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[1].hasPrefix("2026-11-10,"), "Expected the lifter's local date, got: \(lines[1])")
    }

    func testEarlyMorningWorkoutEastOfUTCExportsOnTheLocalCalendarDay() throws {
        let sydney = try XCTUnwrap(TimeZone(identifier: "Australia/Sydney"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = sydney

        // 6:30 am on Nov 10 in Sydney is still Nov 9 in UTC.
        let morning = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 6, minute: 30)))
        let exercise = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])
        let workout = Workout(date: morning, name: "Morning Session", isCompleted: true)
        _ = workout.addSet(exercise: exercise, weight: 315, reps: 5)

        let lines = WorkoutCSVExporter.csv(for: [workout], timeZone: sydney).components(separatedBy: "\n")

        XCTAssertTrue(lines[1].hasPrefix("2026-11-10,"), "Expected the lifter's local date, got: \(lines[1])")
    }

    func testDayFormatterIgnoresDeviceRegionAndCalendar() throws {
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let date = Date(timeIntervalSince1970: 1_794_355_200) // 2026-11-11 00:00:00 UTC

        XCTAssertEqual(WorkoutCSVExporter.dayFormatter(timeZone: utc).string(from: date), "2026-11-11")
    }
}

// MARK: - RPT Drop Settings

final class RPTDropNormalizationTests: XCTestCase {
    func testEqualBackoffDropsAreKept() {
        XCTAssertEqual(UserSettings.normalizedRPTPercentageDrops([0.0, 0.10, 0.10]), [0.0, 0.10, 0.10])
        XCTAssertEqual(UserSettings.normalizedRPTPercentageDrops([0.0, 0.05, 0.05]), [0.0, 0.05, 0.05])
    }

    func testNormalizationStillSortsPadsAndDropsInvalidValues() {
        XCTAssertEqual(UserSettings.normalizedRPTPercentageDrops([0.15, 0.10]), [0.0, 0.10, 0.15])
        XCTAssertEqual(UserSettings.normalizedRPTPercentageDrops([0.0]), [0.0, 0.10, 0.15])
        XCTAssertEqual(UserSettings.normalizedRPTPercentageDrops([0.0, 0.20]), [0.0, 0.20, 0.20])
        XCTAssertEqual(UserSettings.normalizedRPTPercentageDrops([.nan, -0.1, 1.5]), UserSettings.defaultRPTPercentageDrops)
    }

    /// Mirrors the Settings steppers: nudge one back-off by ±5 points, keep
    /// the ladder from getting heavier, then normalize and save.
    private func stepped(_ percents: [Int], index: Int, by delta: Int) -> [Int] {
        var percents = percents
        percents[index] = min(max(percents[index] + delta, 5), 50)
        for position in 1..<percents.count where percents[position] < percents[position - 1] {
            percents[position] = percents[position - 1]
        }

        let normalized = UserSettings.normalizedRPTPercentageDrops([0.0] + percents.map { Double($0) / 100.0 })
        return normalized.dropFirst().map { Int(($0 * 100).rounded()) }
    }

    func testEveryStepperTapMovesTheDropItWasAskedToMove() {
        for first in stride(from: 5, through: 50, by: 5) {
            for second in stride(from: first, through: 50, by: 5) {
                let start = [first, second]

                for index in 0..<2 {
                    for delta in [-5, 5] {
                        let expectedTapped = min(max(start[index] + delta, 5), 50)
                        var expected = start
                        expected[index] = expectedTapped
                        if expected[1] < expected[0] {
                            expected[1] = expected[0]
                        }

                        XCTAssertEqual(
                            stepped(start, index: index, by: delta),
                            expected,
                            "From \(start), tapping back-off \(index + 1) by \(delta)"
                        )
                    }
                }
            }
        }
    }

    func testDefaultLadderCanStepDownToEqualDrops() {
        // The reported case: on 10% / 15%, minus on back-off 2 did nothing.
        XCTAssertEqual(stepped([10, 15], index: 1, by: -5), [10, 10])
        // And on 5% / 10% it moved the wrong way, to 15%.
        XCTAssertEqual(stepped([5, 10], index: 1, by: -5), [5, 5])
    }
}
