import XCTest
@testable import RPT

final class ActiveWorkoutViewTests: XCTestCase {
    func testToolbarUsesExplicitSaveForLaterCopy() {
        XCTAssertEqual(ActiveWorkoutView.toolbarSaveForLaterLabel, "Save for Later")
    }
}
