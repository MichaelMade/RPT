import XCTest
@testable import RPT

final class ExerciseSelectorViewTests: XCTestCase {
    func testWorkoutSelectorUsesWorkoutSpecificContextCopy() {
        XCTAssertEqual(ExerciseSelectorView.navigationTitle, "Add Exercise to Workout")
        XCTAssertEqual(
            ExerciseSelectorView.searchPrompt,
            "Search workout exercises, notes, instruction cues, body regions, muscle groups, or actions"
        )
    }

    func testTemplateSelectorUsesTemplateSpecificContextCopy() {
        XCTAssertEqual(ExerciseSelectorForTemplateView.navigationTitle, "Add Exercise to Template")
        XCTAssertEqual(
            ExerciseSelectorForTemplateView.searchPrompt,
            "Search template exercises, notes, instruction cues, body regions, muscle groups, or actions"
        )
    }

    func testExerciseLibraryUsesExpandedSearchPrompt() {
        XCTAssertEqual(
            ExercisesView.searchPrompt,
            "Search exercises, notes, instruction cues, body regions, muscle groups, or actions"
        )
    }
}
