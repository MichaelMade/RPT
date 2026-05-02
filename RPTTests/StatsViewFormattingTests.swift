import XCTest
@testable import RPT

@MainActor
final class StatsViewFormattingTests: XCTestCase {
    private var sut: StatsView!

    override func setUp() {
        super.setUp()
        sut = StatsView()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testThisWeekSummaryMessage_encouragesFirstWorkoutWhenNoHistoryExists() {
        XCTAssertEqual(
            sut.thisWeekSummaryMessage(totalWorkouts: 0, weeklyWorkoutCount: 0),
            "Finish a workout to start this week’s trend"
        )
    }

    func testThisWeekSummaryMessage_explainsWhenReturningUserHasNoRecentWorkouts() {
        XCTAssertEqual(
            sut.thisWeekSummaryMessage(totalWorkouts: 5, weeklyWorkoutCount: 0),
            "No completed workouts in the last 7 days"
        )
    }

    func testThisWeekSummaryMessage_usesSingularAndPluralWorkoutCopy() {
        XCTAssertEqual(
            sut.thisWeekSummaryMessage(totalWorkouts: 5, weeklyWorkoutCount: 1),
            "1 workout in the last 7 days"
        )
        XCTAssertEqual(
            sut.thisWeekSummaryMessage(totalWorkouts: 5, weeklyWorkoutCount: 3),
            "3 workouts in the last 7 days"
        )
    }

    func testThisWeekAverageDurationValue_usesPlaceholderWhenNoRecentWorkoutsExist() {
        XCTAssertEqual(
            sut.thisWeekAverageDurationValue(weeklyWorkoutCount: 0, hasAverageDuration: false, formattedDuration: "0s"),
            "—"
        )
    }

    func testThisWeekAverageDurationValue_usesPlaceholderWhenDurationDataIsUnavailable() {
        XCTAssertEqual(
            sut.thisWeekAverageDurationValue(weeklyWorkoutCount: 3, hasAverageDuration: false, formattedDuration: "0s"),
            "—"
        )
    }

    func testThisWeekAverageDurationValue_preservesFormattedDurationWhenRecentWorkoutsExist() {
        XCTAssertEqual(
            sut.thisWeekAverageDurationValue(weeklyWorkoutCount: 3, hasAverageDuration: true, formattedDuration: "42m 10s"),
            "42m 10s"
        )
    }

    func testWeeklyVolumeEmptyStateMessage_explainsMissingRecentWindow() {
        XCTAssertEqual(
            sut.weeklyVolumeEmptyStateMessage(totalWorkouts: 3),
            "No completed workouts landed in the last 12 weeks, so there’s no recent volume to chart yet."
        )
    }

    func testWeeklyVolumeEmptyStateMessage_explainsWhenRecentTrainingHasNoWeightedVolume() {
        XCTAssertEqual(
            sut.weeklyVolumeEmptyStateMessage(
                totalWorkouts: 3,
                hasRecentCompletedWorkouts: true,
                hasWeightedVolumeData: false
            ),
            "You’ve logged recent workouts, but none added weighted volume in the last 12 weeks yet, so there’s no meaningful volume chart to show."
        )
    }

    func testMuscleGroupEmptyStateMessage_explainsMissingRecentWorkingSets() {
        XCTAssertEqual(
            sut.muscleGroupEmptyStateMessage(totalWorkouts: 2),
            "Log completed working sets in the last 4 weeks to see which muscle groups are getting the most attention."
        )
    }

    func testPersonalRecordsEmptyStateMessage_explainsMissingCompletedSets() {
        XCTAssertEqual(
            sut.personalRecordsEmptyStateMessage(totalWorkouts: 1),
            "Finish a few completed working sets and your strongest recent performances will show up here."
        )
    }

    func testPersonalRecordDateText_usesRelativeTodayLabel() {
        var calendar = Calendar(identifier: .gregorian)
        let locale = Locale(identifier: "en_US_POSIX")
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone

        let now = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 4,
            day: 30,
            hour: 19,
            minute: 20
        ).date!
        let date = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 4,
            day: 30,
            hour: 9,
            minute: 45
        ).date!

        XCTAssertEqual(
            sut.personalRecordDateText(for: date, now: now, calendar: calendar, locale: locale, timeZone: timeZone),
            "Today • 9:45 AM"
        )
    }

    func testPersonalRecordDateText_usesRelativeYesterdayLabel() {
        var calendar = Calendar(identifier: .gregorian)
        let locale = Locale(identifier: "en_US_POSIX")
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone

        let now = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 4,
            day: 30,
            hour: 19,
            minute: 20
        ).date!
        let date = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 4,
            day: 29,
            hour: 8,
            minute: 0
        ).date!

        XCTAssertEqual(
            sut.personalRecordDateText(for: date, now: now, calendar: calendar, locale: locale, timeZone: timeZone),
            "Yesterday • 8:00 AM"
        )
    }

    func testFormattedTotal_doesNotPromoteSubThousandNearThreshold() {
        XCTAssertEqual(sut.formattedTotal(999.95), "999 lb")
    }

    func testFormattedTotal_truncatesSubThousandValues() {
        XCTAssertEqual(sut.formattedTotal(123.6), "123 lb")
    }

    func testFormattedTotal_clampsInvalidValuesToZero() {
        XCTAssertEqual(sut.formattedTotal(-10), "0 lb")
        XCTAssertEqual(sut.formattedTotal(.infinity), "0 lb")
    }

    func testFormattedTotal_truncatesThousandsWithoutOverstating() {
        XCTAssertEqual(sut.formattedTotal(1999.0), "1.9k lb")
    }

    func testFormattedTotal_supportsMillionScaleAbbreviation() {
        XCTAssertEqual(sut.formattedTotal(1_000_000.0), "1M lb")
        XCTAssertEqual(sut.formattedTotal(1_999_999.0), "1.9M lb")
    }

    func testFormattedSetSharePercentage_handlesZeroTotalSafely() {
        XCTAssertEqual(sut.formattedSetSharePercentage(setCount: 3, totalSets: 0), "(0%)")
    }

    func testFormattedSetSharePercentage_clampsInvalidInputs() {
        XCTAssertEqual(sut.formattedSetSharePercentage(setCount: -5, totalSets: 10), "(0%)")
        XCTAssertEqual(sut.formattedSetSharePercentage(setCount: 5, totalSets: -10), "(0%)")
    }

    func testFormattedSetSharePercentage_formatsWholePercentage() {
        XCTAssertEqual(sut.formattedSetSharePercentage(setCount: 3, totalSets: 12), "(25%)")
    }

    func testFormattedSetSharePercentage_clampsOverfullShareToHundredPercent() {
        XCTAssertEqual(sut.formattedSetSharePercentage(setCount: 15, totalSets: 10), "(100%)")
    }
}
