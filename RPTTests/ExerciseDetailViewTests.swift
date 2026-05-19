import XCTest
@testable import RPT

final class ExerciseDetailViewTests: XCTestCase {
    func testTemplateStartFailureAlertTitles_nameSpecificTemplate() {
        let template = WorkoutTemplate(name: "  Upper   A  ")

        XCTAssertEqual(
            ExerciseDetailView.templateStartFailureAlertTitle(for: template),
            "Couldn’t Start Template “Upper A”"
        )
        XCTAssertEqual(
            ExerciseDetailView.templateSaveAndStartFailureAlertTitle(for: template),
            "Couldn’t Save & Start Template “Upper A”"
        )
        XCTAssertEqual(
            ExerciseDetailView.templateDiscardAndStartFailureAlertTitle(for: template),
            "Couldn’t Discard & Start Template “Upper A”"
        )
    }

    func testTemplateStartFailureAlertTitles_fallBackGracefully() {
        let blankTemplate = WorkoutTemplate(name: " \n ")

        XCTAssertEqual(
            ExerciseDetailView.templateStartFailureAlertTitle(for: blankTemplate),
            "Couldn’t Start This Template"
        )
        XCTAssertEqual(
            ExerciseDetailView.templateSaveAndStartFailureAlertTitle(for: blankTemplate),
            "Couldn’t Save & Start This Template"
        )
        XCTAssertEqual(
            ExerciseDetailView.templateDiscardAndStartFailureAlertTitle(for: blankTemplate),
            "Couldn’t Discard & Start This Template"
        )
        XCTAssertEqual(
            ExerciseDetailView.templateStartFailureAlertTitle(for: nil),
            "Workout Action Failed"
        )
    }
}
