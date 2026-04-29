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

    func testWeeklyVolumeEmptyStateMessage_explainsMissingRecentWindow() {
        XCTAssertEqual(
            sut.weeklyVolumeEmptyStateMessage(totalWorkouts: 3),
            "No completed workouts landed in the last 12 weeks, so there’s no recent volume to chart yet."
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
