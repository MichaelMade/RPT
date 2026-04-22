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

    func testFormattedTotal_roundsNearThresholdIntoThousandsFormat() {
        XCTAssertEqual(sut.formattedTotal(999.95), "1k lb")
    }

    func testFormattedTotal_roundsSubThousandInsteadOfTruncating() {
        XCTAssertEqual(sut.formattedTotal(123.6), "124 lb")
    }

    func testFormattedTotal_clampsInvalidValuesToZero() {
        XCTAssertEqual(sut.formattedTotal(-10), "0 lb")
        XCTAssertEqual(sut.formattedTotal(.infinity), "0 lb")
    }
}
