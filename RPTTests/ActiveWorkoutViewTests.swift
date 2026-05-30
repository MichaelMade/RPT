import XCTest
@testable import RPT

final class ActiveWorkoutViewTests: XCTestCase {
    func testToolbarUsesExplicitSaveForLaterCopy() {
        XCTAssertEqual(ActiveWorkoutView.toolbarSaveForLaterLabel, "Save for Later")
    }

    func testEmptyStateHelperMessage_mentionsFinishRequirementAndDraftRecovery() {
        XCTAssertEqual(
            ActiveWorkoutView.emptyStateHelperMessage,
            "Add at least one exercise before you can finish this workout. Save for Later keeps it as a draft if you're not ready yet."
        )
    }

    func testNavigationTitleNormalizesLegacyPlaceholderNames() {
        XCTAssertEqual(ActiveWorkoutView.navigationTitle(for: "Current Workout"), "Workout")
        XCTAssertEqual(ActiveWorkoutView.navigationTitle(for: "  Current   Workout  "), "Workout")
        XCTAssertEqual(ActiveWorkoutView.navigationTitle(for: " current workout "), "Workout")
        XCTAssertEqual(ActiveWorkoutView.navigationTitle(for: "Current Draft"), "Workout")
        XCTAssertEqual(ActiveWorkoutView.navigationTitle(for: "  Current   Draft  "), "Workout")
        XCTAssertEqual(ActiveWorkoutView.navigationTitle(for: " current draft "), "Workout")
        XCTAssertEqual(ActiveWorkoutView.navigationTitle(for: "Upper A"), "Upper A")
    }
}
