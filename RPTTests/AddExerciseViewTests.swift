import XCTest
@testable import RPT

final class AddExerciseViewTests: XCTestCase {
    func testNavigationTitle_namesTheDraftExerciseWhenAvailable() {
        XCTAssertEqual(
            AddExerciseView.navigationTitle(for: "  Garage\n\n Dip  "),
            "Add “Garage Dip”"
        )
    }

    func testNavigationTitle_fallsBackGracefullyForBlankDrafts() {
        XCTAssertEqual(
            AddExerciseView.navigationTitle(for: " \n\t "),
            "Add Exercise"
        )
    }

    func testSaveFailureAlertTitle_namesTheDraftExerciseWhenAvailable() {
        XCTAssertEqual(
            AddExerciseView.saveFailureAlertTitle(for: "  Garage\n\n Dip  "),
            "Couldn’t Save “Garage Dip”"
        )
    }

    func testSaveFailureAlertTitle_fallsBackGracefullyForBlankDrafts() {
        XCTAssertEqual(
            AddExerciseView.saveFailureAlertTitle(for: " \n\t "),
            "Couldn’t Save This Exercise"
        )
    }

    func testDiscardAlertTitle_namesTheDraftExerciseWhenAvailable() {
        XCTAssertEqual(
            AddExerciseView.discardAlertTitle(for: "  Garage\n\n Dip  "),
            "Discard “Garage Dip”?"
        )
    }

    func testDiscardAlertTitle_fallsBackGracefullyForBlankDrafts() {
        XCTAssertEqual(
            AddExerciseView.discardAlertTitle(for: " \n\t "),
            "Discard New Exercise?"
        )
    }

    func testDiscardAlertActionTitle_namesTheDraftExerciseWhenAvailable() {
        XCTAssertEqual(
            AddExerciseView.discardAlertActionTitle(for: "  Garage\n\n Dip  "),
            "Discard “Garage Dip”"
        )
    }

    func testDiscardAlertMessage_matchesNewExerciseFlow() {
        XCTAssertEqual(
            AddExerciseView.discardAlertMessage(),
            "You’ll lose this exercise draft and any setup changes."
        )
    }
}
