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
}
