import XCTest
@testable import RPT

final class ActiveWorkoutViewTests: XCTestCase {
    func testToolbarUsesExplicitSaveForLaterCopy() {
        XCTAssertEqual(ActiveWorkoutView.toolbarSaveForLaterLabel, "Save for Later")
    }

    func testNavigationTitleNormalizesLegacyPlaceholderNames() {
        XCTAssertEqual(ActiveWorkoutView.navigationTitle(for: "Current Workout"), "Workout")
        XCTAssertEqual(ActiveWorkoutView.navigationTitle(for: "  Current   Workout  "), "Workout")
        XCTAssertEqual(ActiveWorkoutView.navigationTitle(for: " current workout "), "Workout")
        XCTAssertEqual(ActiveWorkoutView.navigationTitle(for: "Upper A"), "Upper A")
    }
}
