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
}
