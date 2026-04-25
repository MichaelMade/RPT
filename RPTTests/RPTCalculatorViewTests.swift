import XCTest
@testable import RPT

@MainActor
final class RPTCalculatorViewTests: XCTestCase {

    func testNormalizedPercentageDrops_padsMissingValuesToSupportedSetCount() {
        let normalized = RPTCalculatorView.normalizedPercentageDrops([0.0, 0.1])

        XCTAssertEqual(normalized, [0.0, 0.1, 0.15])
    }

    func testNormalizedPercentageDrops_filtersInvalidAndFallsBackToDefaults() {
        let normalized = RPTCalculatorView.normalizedPercentageDrops([.infinity, -0.1])

        XCTAssertEqual(normalized, [0.0, 0.10, 0.15])
    }

    func testNormalizedPercentageDrops_limitsToCalculatorSetCount() {
        let normalized = RPTCalculatorView.normalizedPercentageDrops([0.0, 0.05, 0.10, 0.15, 0.20])

        XCTAssertEqual(normalized, [0.0, 0.05, 0.10])
    }

    func testUpdatedPercentageDrops_clampsOutOfRangePercentInput() {
        let updated = RPTCalculatorView.updatedPercentageDrops([0.0, 0.10, 0.15], editing: 1, rawPercent: 140)

        XCTAssertEqual(updated, [0.0, 1.0, 1.0])
    }

    func testUpdatedPercentageDrops_preservesMonotonicBackoffProgression() {
        let updated = RPTCalculatorView.updatedPercentageDrops([0.0, 0.10, 0.15], editing: 1, rawPercent: 20)

        XCTAssertEqual(updated, [0.0, 0.20, 0.20])
    }

    func testUpdatedPercentageDrops_keepsTopSetDropAtZero() {
        let updated = RPTCalculatorView.updatedPercentageDrops([0.5, 0.10, 0.15], editing: 1, rawPercent: 5)

        XCTAssertEqual(updated, [0.0, 0.05, 0.15])
    }
}
