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
