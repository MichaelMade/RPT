import XCTest
@testable import RPT

@MainActor
final class PlateCalculatorViewTests: XCTestCase {

    func testSanitizedTargetWeight_trimsWhitespaceAndParsesPositiveValues() {
        XCTAssertEqual(PlateCalculatorView.sanitizedTargetWeight(from: " 135 "), 135)
    }

    func testSanitizedTargetWeight_rejectsBlankInvalidAndNonPositiveInput() {
        XCTAssertNil(PlateCalculatorView.sanitizedTargetWeight(from: ""))
        XCTAssertNil(PlateCalculatorView.sanitizedTargetWeight(from: "abc"))
        XCTAssertNil(PlateCalculatorView.sanitizedTargetWeight(from: "0"))
        XCTAssertNil(PlateCalculatorView.sanitizedTargetWeight(from: "-45"))
    }

    func testBreakdownStatus_blankTargetShowsValidationGuidance() {
        let result = PlateCalculator.calculate(
            targetWeight: 0,
            barbell: .olympic,
            unit: .pounds,
            availablePlates: PlateCalculator.defaultLbPlates
        )

        let status = PlateCalculatorView.breakdownStatus(
            rawTargetText: "   ",
            barbell: .olympic,
            unit: .pounds,
            result: result
        )

        XCTAssertEqual(status, .validation(message: "Enter a target weight to see the plate breakdown."))
    }

    func testBreakdownStatus_targetBelowBarShowsSpecificValidationMessage() {
        let result = PlateCalculator.calculate(
            targetWeight: 40,
            barbell: .olympic,
            unit: .pounds,
            availablePlates: PlateCalculator.defaultLbPlates
        )

        let status = PlateCalculatorView.breakdownStatus(
            rawTargetText: "40",
            barbell: .olympic,
            unit: .pounds,
            result: result
        )

        XCTAssertEqual(status, .validation(message: "Target is less than the selected bar weight (45 lb)."))
    }

    func testBreakdownStatus_exactBarWeightShowsBarOnlySummary() {
        let result = PlateCalculator.calculate(
            targetWeight: 45,
            barbell: .olympic,
            unit: .pounds,
            availablePlates: PlateCalculator.defaultLbPlates
        )

        let status = PlateCalculatorView.breakdownStatus(
            rawTargetText: "45",
            barbell: .olympic,
            unit: .pounds,
            result: result
        )

        XCTAssertEqual(status, .barOnly(message: "Just the bar (45 lb)"))
    }

    func testBreakdownStatus_targetAboveBarWithoutLoadablePlatesShowsUnavailableWarning() {
        let result = PlateCalculator.calculate(
            targetWeight: 135,
            barbell: .olympic,
            unit: .pounds,
            availablePlates: []
        )

        let status = PlateCalculatorView.breakdownStatus(
            rawTargetText: "135",
            barbell: .olympic,
            unit: .pounds,
            result: result
        )

        XCTAssertEqual(
            status,
            .unavailable(message: "Can't make 135 lb with the selected plates — currently only the bar is loadable.")
        )
    }

    func testBreakdownStatus_loadableTargetReturnsCalculatedState() {
        let result = PlateCalculator.calculate(
            targetWeight: 135,
            barbell: .olympic,
            unit: .pounds,
            availablePlates: PlateCalculator.defaultLbPlates
        )

        let status = PlateCalculatorView.breakdownStatus(
            rawTargetText: "135",
            barbell: .olympic,
            unit: .pounds,
            result: result
        )

        XCTAssertEqual(status, .calculated)
    }
}
