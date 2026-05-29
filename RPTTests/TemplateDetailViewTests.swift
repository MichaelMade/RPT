import XCTest
@testable import RPT

final class TemplateDetailViewTests: XCTestCase {
    func testEmptyExercisesHelperMessage_reusesDisabledStartGuidanceForEmptyTemplates() {
        let template = WorkoutTemplate(name: "Empty Template", exercises: [], notes: "")

        XCTAssertEqual(
            TemplateDetailView.emptyExercisesHelperMessage(for: template),
            "This template doesn’t have any exercises yet. Edit it to add at least one exercise before starting."
        )
    }
}
