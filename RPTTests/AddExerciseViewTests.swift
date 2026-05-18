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
}
