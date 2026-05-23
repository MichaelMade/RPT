import XCTest
@testable import RPT

final class TemplateEditViewTests: XCTestCase {
    func testDiscardAlertTitle_namesTheDraftTemplateWhenAvailable() {
        XCTAssertEqual(
            TemplateEditView.discardAlertTitle(isNewTemplate: true, templateName: "  Upper\n\n A  "),
            "Discard “Upper A”?"
        )
    }

    func testDiscardAlertTitle_fallsBackForBlankNewTemplates() {
        XCTAssertEqual(
            TemplateEditView.discardAlertTitle(isNewTemplate: true, templateName: " \n\t "),
            "Discard New Template?"
        )
    }

    func testDiscardAlertTitle_fallsBackForBlankExistingTemplates() {
        XCTAssertEqual(
            TemplateEditView.discardAlertTitle(isNewTemplate: false, templateName: " \n\t "),
            "Discard Template Changes?"
        )
    }

    func testDiscardAlertActionTitle_namesTheDraftTemplateWhenAvailable() {
        XCTAssertEqual(
            TemplateEditView.discardAlertActionTitle(isNewTemplate: false, templateName: "  Upper\n\n A  "),
            "Discard “Upper A”"
        )
    }

    func testDiscardAlertActionTitle_fallsBackForBlankExistingTemplates() {
        XCTAssertEqual(
            TemplateEditView.discardAlertActionTitle(isNewTemplate: false, templateName: " \n\t "),
            "Discard Template Changes"
        )
    }

    func testDiscardAlertTitles_useTemplateDisplayNameNormalizationForLongDrafts() {
        let longName = String(repeating: "Upper A ", count: 20)
        let expectedDisplayName = WorkoutTemplate.normalizedDisplayName(longName)

        XCTAssertEqual(
            TemplateEditView.discardAlertTitle(isNewTemplate: true, templateName: longName),
            "Discard “\(expectedDisplayName)”?"
        )
        XCTAssertEqual(
            TemplateEditView.discardAlertActionTitle(isNewTemplate: false, templateName: longName),
            "Discard “\(expectedDisplayName)”"
        )
    }

    func testDiscardAlertMessage_matchesNewVsExistingFlowsWhenNothingSpecificChanged() {
        XCTAssertEqual(
            TemplateEditView.discardAlertMessage(isNewTemplate: true, changedFields: []),
            "You’ll lose this template draft."
        )
        XCTAssertEqual(
            TemplateEditView.discardAlertMessage(isNewTemplate: false, changedFields: []),
            "You’ll lose your unsaved changes to this template."
        )
    }

    func testDiscardAlertMessage_namesTheChangedTemplateFieldsThatWouldBeLost() {
        XCTAssertEqual(
            TemplateEditView.discardAlertMessage(
                isNewTemplate: false,
                changedFields: ["name", "exercise list", "exercise notes"]
            ),
            "You’ll lose your unsaved changes to this template, including its name, exercise list, and exercise notes."
        )
    }

    func testTemplateExerciseDiscardAlertTitle_namesTheExerciseWhenAvailable() {
        XCTAssertEqual(
            TemplateExerciseEditView.discardAlertTitle(for: "  Bench\n\n Press  "),
            "Discard “Bench Press”?"
        )
    }

    func testTemplateExerciseDiscardAlertTitle_fallsBackForBlankLegacyNames() {
        XCTAssertEqual(
            TemplateExerciseEditView.discardAlertTitle(for: " \n\t "),
            "Discard Exercise Changes?"
        )
    }

    func testTemplateExerciseDiscardAlertActionTitle_matchesTheResolvedName() {
        XCTAssertEqual(
            TemplateExerciseEditView.discardAlertActionTitle(for: "  Bench\n\n Press  "),
            "Discard “Bench Press”"
        )
        XCTAssertEqual(
            TemplateExerciseEditView.discardAlertActionTitle(for: " \n\t "),
            "Discard Exercise Changes"
        )
    }

    func testTemplateExerciseDiscardAlertMessage_usesFallbackCopyWhenNoSpecificFieldsChanged() {
        XCTAssertEqual(
            TemplateExerciseEditView.discardAlertMessage(changedFields: []),
            "You’ll lose your unsaved changes to this template exercise."
        )
    }

    func testTemplateExerciseDiscardAlertMessage_namesTheChangedFieldsThatWouldBeLost() {
        XCTAssertEqual(
            TemplateExerciseEditView.discardAlertMessage(changedFields: ["planned set count", "notes"]),
            "You’ll lose your unsaved changes to this template exercise, including its planned set count and notes."
        )
    }

    func testTemplateDeleteExerciseAlertTitle_namesTheExerciseWhenAvailable() {
        XCTAssertEqual(
            TemplateEditView.deleteExerciseAlertTitle(for: "  Bench\n\n Press  "),
            "Delete “Bench Press” from Template?"
        )
    }

    func testTemplateDeleteExerciseAlertTitles_fallBackForBlankLegacyNames() {
        XCTAssertEqual(
            TemplateEditView.deleteExerciseAlertTitle(for: " \n\t "),
            "Delete This Exercise?"
        )
        XCTAssertEqual(
            TemplateEditView.deleteExerciseActionTitle(for: " \n\t "),
            "Delete Exercise"
        )
    }

    func testTemplateDeleteExerciseActionTitle_matchesTheResolvedName() {
        XCTAssertEqual(
            TemplateEditView.deleteExerciseActionTitle(for: "  Bench\n\n Press  "),
            "Delete “Bench Press”"
        )
    }

    func testTemplateDeleteExerciseAlertMessage_summarizesPlannedSetsRepTargetsAndNotes() {
        let exercise = TemplateExercise(
            exerciseName: "Bench Press",
            suggestedSets: 3,
            repRanges: [
                TemplateRepRange(setNumber: 1, minReps: 6, maxReps: 8),
                TemplateRepRange(setNumber: 2, minReps: 8, maxReps: 10),
                TemplateRepRange(setNumber: 3, minReps: 10, maxReps: 12)
            ],
            notes: "Pause the first rep"
        )

        XCTAssertEqual(
            TemplateEditView.deleteExerciseAlertMessage(for: exercise),
            "This will remove 3 planned sets, their rep targets, and any exercise notes from this template."
        )
    }

    func testTemplateDeleteExerciseAlertMessage_usesSingularRepTargetCopyForSingleSet() {
        let exercise = TemplateExercise(
            exerciseName: "Bench Press",
            suggestedSets: 1,
            repRanges: [
                TemplateRepRange(setNumber: 1, minReps: 6, maxReps: 8)
            ]
        )

        XCTAssertEqual(
            TemplateEditView.deleteExerciseAlertMessage(for: exercise),
            "This will remove 1 planned set and its rep target from this template."
        )
    }

    func testTemplateDeleteExerciseAlertMessage_fallsBackForLegacyExercisesWithoutSetup() {
        let exercise = TemplateExercise(
            exerciseName: " ",
            suggestedSets: 0,
            repRanges: [],
            notes: ""
        )

        XCTAssertEqual(
            TemplateEditView.deleteExerciseAlertMessage(for: exercise),
            "This exercise setup will be removed from this template."
        )
        XCTAssertEqual(
            TemplateEditView.deleteExerciseAlertMessage(for: nil),
            "This exercise setup will be removed from this template."
        )
    }
}
