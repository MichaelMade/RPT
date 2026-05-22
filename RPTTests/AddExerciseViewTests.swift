import XCTest
@testable import RPT

final class AddExerciseViewTests: XCTestCase {
    func testNavigationTitle_namesTheDraftExerciseWhenAvailable() {
        XCTAssertEqual(
            AddExerciseView.navigationTitle(for: "  Garage\n\n Dip  "),
            "Add “Garage Dip”"
        )
    }

    func testNavigationTitle_usesWorkoutContextWhenRequested() {
        XCTAssertEqual(
            AddExerciseView.navigationTitle(for: "  Garage\n\n Dip  ", context: .workout),
            "Add “Garage Dip” to Workout"
        )
    }

    func testNavigationTitle_usesTemplateContextWhenRequested() {
        XCTAssertEqual(
            AddExerciseView.navigationTitle(for: "  Garage\n\n Dip  ", context: .template),
            "Add “Garage Dip” to Template"
        )
    }

    func testNavigationTitle_fallsBackGracefullyForBlankDrafts() {
        XCTAssertEqual(
            AddExerciseView.navigationTitle(for: " \n\t "),
            "Add Exercise"
        )
    }

    func testNavigationTitle_fallsBackGracefullyForBlankWorkoutDrafts() {
        XCTAssertEqual(
            AddExerciseView.navigationTitle(for: " \n\t ", context: .workout),
            "Add Exercise to Workout"
        )
    }

    func testNavigationTitle_fallsBackGracefullyForBlankTemplateDrafts() {
        XCTAssertEqual(
            AddExerciseView.navigationTitle(for: " \n\t ", context: .template),
            "Add Exercise to Template"
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

    func testDiscardAlertMessage_usesFallbackCopyWhenNoSpecificFieldsChanged() {
        XCTAssertEqual(
            AddExerciseView.discardAlertMessage(changedFields: []),
            "You’ll lose this exercise draft and any setup changes."
        )
    }

    func testDiscardAlertMessage_namesTheDraftFieldsThatWouldBeLost() {
        XCTAssertEqual(
            AddExerciseView.discardAlertMessage(changedFields: ["name", "primary muscles", "instructions"]),
            "You’ll lose this exercise draft, including its name, primary muscles, and instructions."
        )
    }
}
