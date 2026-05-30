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

    func testStartWorkoutHelperMessages_omitsDuplicateEmptyTemplateGuidance() {
        let template = WorkoutTemplate(name: "Empty Template", exercises: [], notes: "")
        let emptyGuidance = "This template doesn’t have any exercises yet. Edit it to add at least one exercise before starting."

        XCTAssertEqual(
            TemplateDetailView.startWorkoutHelperMessages(
                for: template,
                startWorkoutDisabledMessage: emptyGuidance,
                activeWorkoutBlockMessage: nil
            ),
            [],
            "Template Details should not repeat the same empty-template guidance in both the exercise section and the footer helpers"
        )
    }

    func testStartWorkoutHelperMessages_keepsDistinctFooterMessages() {
        let template = WorkoutTemplate(
            name: "Upper A",
            exercises: [TemplateExercise(exerciseName: "Bench Press")],
            notes: ""
        )
        let disabledMessage = "This template can’t start right now because its only exercise is missing from your library. Restore or replace it before starting."
        let activeWorkoutMessage = "You already have a workout in progress. Continue it, save it for later, or discard it before starting this template."

        XCTAssertEqual(
            TemplateDetailView.startWorkoutHelperMessages(
                for: template,
                startWorkoutDisabledMessage: disabledMessage,
                activeWorkoutBlockMessage: activeWorkoutMessage
            ),
            [disabledMessage, activeWorkoutMessage],
            "Template Details should still show distinct footer helpers when the messages add different recovery guidance"
        )
    }
}
