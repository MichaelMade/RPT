import XCTest
@testable import RPT

final class ActiveWorkoutViewTests: XCTestCase {
    func testToolbarUsesExplicitSaveForLaterCopy() {
        XCTAssertEqual(ActiveWorkoutView.toolbarSaveForLaterLabel, "Save for Later")
    }

    func testToolbarSaveForLaterLabel_namesSpecificWorkout() {
        XCTAssertEqual(
            ActiveWorkoutView.toolbarSaveForLaterLabel(for: "  Push   Day  "),
            "Save “Push Day” for Later"
        )
    }

    func testToolbarSaveForLaterLabel_fallsBackForLegacyPlaceholderNames() {
        XCTAssertEqual(
            ActiveWorkoutView.toolbarSaveForLaterLabel(for: "Current Workout"),
            ActiveWorkoutView.toolbarSaveForLaterLabel
        )
    }

    func testEmptyStateHelperMessage_mentionsFinishRequirementAndDraftRecovery() {
        XCTAssertEqual(
            ActiveWorkoutView.emptyStateHelperMessage,
            "Add at least one exercise before you can finish this workout. Save for Later keeps it as a draft if you're not ready yet."
        )
    }

    func testNamedEmptyStateHelperMessage_mentionsSpecificWorkout() {
        XCTAssertEqual(
            ActiveWorkoutView.emptyStateHelperMessage(for: "  Push   Day  "),
            "Add at least one exercise to “Push Day” before you can finish it. Save “Push Day” for Later keeps it as a draft if you're not ready yet."
        )
    }

    func testNamedEmptyStateHelperMessage_usesNamedSaveForLaterAction() {
        XCTAssertEqual(
            ActiveWorkoutView.emptyStateSaveForLaterLabel(for: "  Push   Day  "),
            ActiveWorkoutView.toolbarSaveForLaterLabel(for: "  Push   Day  ")
        )
        XCTAssertEqual(
            ActiveWorkoutView.emptyStateSaveForLaterLabel(for: "Current Workout"),
            ActiveWorkoutView.toolbarSaveForLaterLabel
        )
    }

    func testNamedEmptyStateHelperMessage_fallsBackForLegacyPlaceholderNames() {
        XCTAssertEqual(
            ActiveWorkoutView.emptyStateHelperMessage(for: "Current Workout"),
            ActiveWorkoutView.emptyStateHelperMessage
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
