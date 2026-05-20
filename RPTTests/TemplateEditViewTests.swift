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

    func testDiscardAlertMessage_matchesNewVsExistingFlows() {
        XCTAssertEqual(
            TemplateEditView.discardAlertMessage(isNewTemplate: true),
            "You’ll lose this template draft and any exercise setup changes."
        )
        XCTAssertEqual(
            TemplateEditView.discardAlertMessage(isNewTemplate: false),
            "You’ll lose your unsaved changes to this template."
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
            "Discard Changes"
        )
    }

    func testTemplateExerciseDiscardAlertMessage_isSpecificToTemplateExerciseEditing() {
        XCTAssertEqual(
            TemplateExerciseEditView.discardAlertMessage,
            "You’ll lose your unsaved changes to this template exercise."
        )
    }
}
