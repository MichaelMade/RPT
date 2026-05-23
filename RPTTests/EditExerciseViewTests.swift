import XCTest
@testable import RPT

final class EditExerciseViewTests: XCTestCase {
    func testNavigationTitle_prefersTheDraftExerciseNameWhenAvailable() {
        let exercise = Exercise(
            name: "Garage Dip",
            category: .bodyweight,
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest],
            instructions: ""
        )

        XCTAssertEqual(
            EditExerciseView.navigationTitle(
                for: "  Ring\n\n Dip  ",
                fallbackExercise: exercise
            ),
            "Edit “Ring Dip”"
        )
    }

    func testNavigationTitle_fallsBackToTheSavedExerciseNameForBlankDrafts() {
        let exercise = Exercise(
            name: "Garage Dip",
            category: .bodyweight,
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest],
            instructions: ""
        )

        XCTAssertEqual(
            EditExerciseView.navigationTitle(
                for: " \n\t ",
                fallbackExercise: exercise
            ),
            "Edit “Garage Dip”"
        )
    }

    func testNavigationTitle_fallsBackGracefullyForBlankLegacyExerciseNames() {
        let exercise = Exercise(
            name: " \n\t ",
            category: .bodyweight,
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest],
            instructions: ""
        )

        XCTAssertEqual(
            EditExerciseView.navigationTitle(
                for: " \n\t ",
                fallbackExercise: exercise
            ),
            "Edit Exercise"
        )
    }

    func testSaveFailureAlertTitle_prefersTheDraftExerciseNameWhenAvailable() {
        let exercise = Exercise(
            name: "Garage Dip",
            category: .bodyweight,
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest],
            instructions: ""
        )

        XCTAssertEqual(
            EditExerciseView.saveFailureAlertTitle(
                for: "  Ring\n\n Dip  ",
                fallbackExercise: exercise
            ),
            "Couldn’t Save “Ring Dip”"
        )
    }

    func testSaveFailureAlertTitle_fallsBackToTheSavedExerciseNameForBlankDrafts() {
        let exercise = Exercise(
            name: "Garage Dip",
            category: .bodyweight,
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest],
            instructions: ""
        )

        XCTAssertEqual(
            EditExerciseView.saveFailureAlertTitle(
                for: " \n\t ",
                fallbackExercise: exercise
            ),
            "Couldn’t Save “Garage Dip”"
        )
    }

    func testSaveFailureAlertTitle_fallsBackGracefullyForBlankLegacyExerciseNames() {
        let exercise = Exercise(
            name: " \n\t ",
            category: .bodyweight,
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest],
            instructions: ""
        )

        XCTAssertEqual(
            EditExerciseView.saveFailureAlertTitle(
                for: " \n\t ",
                fallbackExercise: exercise
            ),
            "Couldn’t Save This Exercise"
        )
    }

    func testDiscardAlertTitle_prefersTheDraftExerciseNameWhenAvailable() {
        let exercise = Exercise(
            name: "Garage Dip",
            category: .bodyweight,
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest],
            instructions: ""
        )

        XCTAssertEqual(
            EditExerciseView.discardAlertTitle(
                for: "  Ring\n\n Dip  ",
                fallbackExercise: exercise
            ),
            "Discard “Ring Dip”?"
        )
    }

    func testDiscardAlertTitle_fallsBackToTheSavedExerciseNameForBlankDrafts() {
        let exercise = Exercise(
            name: "Garage Dip",
            category: .bodyweight,
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest],
            instructions: ""
        )

        XCTAssertEqual(
            EditExerciseView.discardAlertTitle(
                for: " \n\t ",
                fallbackExercise: exercise
            ),
            "Discard “Garage Dip”?"
        )
    }

    func testDiscardAlertTitle_fallsBackGracefullyForBlankLegacyExerciseNames() {
        let exercise = Exercise(
            name: " \n\t ",
            category: .bodyweight,
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest],
            instructions: ""
        )

        XCTAssertEqual(
            EditExerciseView.discardAlertTitle(
                for: " \n\t ",
                fallbackExercise: exercise
            ),
            "Discard Exercise Changes?"
        )
    }

    func testDiscardAlertActionTitle_prefersTheDraftExerciseNameWhenAvailable() {
        let exercise = Exercise(
            name: "Garage Dip",
            category: .bodyweight,
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest],
            instructions: ""
        )

        XCTAssertEqual(
            EditExerciseView.discardAlertActionTitle(
                for: "  Ring\n\n Dip  ",
                fallbackExercise: exercise
            ),
            "Discard “Ring Dip”"
        )
    }

    func testDiscardAlertActionTitle_fallsBackGracefullyForBlankLegacyExerciseNames() {
        let exercise = Exercise(
            name: " \n\t ",
            category: .bodyweight,
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest],
            instructions: ""
        )

        XCTAssertEqual(
            EditExerciseView.discardAlertActionTitle(
                for: " \n\t ",
                fallbackExercise: exercise
            ),
            "Discard Exercise Changes"
        )
    }

    func testDiscardAlertMessage_usesFallbackCopyWhenNoSpecificFieldsChanged() {
        XCTAssertEqual(
            EditExerciseView.discardAlertMessage(changedFields: []),
            "You’ll lose your unsaved changes to this exercise."
        )
    }

    func testDiscardAlertMessage_namesTheChangedFieldsThatWouldBeLost() {
        XCTAssertEqual(
            EditExerciseView.discardAlertMessage(changedFields: ["category", "secondary muscles"]),
            "You’ll lose your unsaved changes to this exercise, including its category and secondary muscles."
        )
    }
}
