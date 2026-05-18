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
}
