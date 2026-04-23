import XCTest
@testable import RPT

@MainActor
final class TemplateManagerTests: XCTestCase {
    func testInitialCompletedAt_returnsDistantPastForIncompleteTemplateSet() {
        let now = Date()

        XCTAssertEqual(
            TemplateManager.initialCompletedAt(weight: 0, reps: 8, fallbackDate: now),
            .distantPast
        )
    }

    func testInitialCompletedAt_returnsFallbackDateForCompleteTemplateSet() {
        let now = Date()

        XCTAssertEqual(
            TemplateManager.initialCompletedAt(weight: 185, reps: 8, fallbackDate: now),
            now
        )
    }
}
