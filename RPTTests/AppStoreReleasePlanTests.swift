import XCTest
@testable import RPT

final class AppStoreReleasePlanTests: XCTestCase {
    func testMetadataPositionsRPTForSearchAndConversion() {
        XCTAssertEqual(AppStoreReleasePlan.appName, "RPT: Reverse Pyramid Training")
        XCTAssertEqual(AppStoreReleasePlan.subtitle, "Reverse pyramid training log")
        XCTAssertTrue(AppStoreReleasePlan.promotionalText.contains("heavy top sets first"))
        XCTAssertTrue(AppStoreReleasePlan.shortDescription.contains("private on-device workout history"))
    }

    func testKeywordsStayWithinAppStoreConnectLimit() {
        XCTAssertTrue(AppStoreReleasePlan.keywordPhrases.contains("rpt"))
        XCTAssertTrue(AppStoreReleasePlan.keywordPhrases.contains("progressive overload"))
        XCTAssertTrue(AppStoreReleasePlan.hasAppStoreSafeKeywordLength)
        XCTAssertLessThanOrEqual(AppStoreReleasePlan.keywordCharacterCount, 100)
    }

    func testScreenshotPlanCoversReleaseCriticalUserJourney() {
        XCTAssertEqual(AppStoreReleasePlan.screenshotPlan.count, 5)
        XCTAssertEqual(AppStoreReleasePlan.screenshotPlan.first?.title, "Start Heavy")

        let targetScreens = AppStoreReleasePlan.screenshotPlan.map(\.targetScreen)
        XCTAssertTrue(targetScreens.contains("Active workout logging"))
        XCTAssertTrue(targetScreens.contains("Stats dashboard"))
        XCTAssertTrue(targetScreens.contains("RPT Pro upgrade"))
    }

    func testReleasePositioningMatchesFreemiumLaunchPlan() {
        XCTAssertTrue(AppStoreReleasePlan.releasePositioningBullets.contains { $0.contains("core training loop free") })
        XCTAssertTrue(AppStoreReleasePlan.releasePositioningBullets.contains { $0.contains("one-time lifetime upgrade") })
        XCTAssertTrue(AppStoreReleasePlan.releasePositioningBullets.contains { $0.contains("Private by design") })
    }

    func testSupportPrivacyAndTermsLinksUseReleaseUrls() {
        XCTAssertEqual(AppStoreReleasePlan.supportURL.host, "github.com")
        XCTAssertTrue(AppStoreReleasePlan.supportURL.path.hasSuffix("/SUPPORT.md"))
        XCTAssertEqual(AppStoreReleasePlan.privacyURL.host, "github.com")
        XCTAssertTrue(AppStoreReleasePlan.privacyURL.path.contains("Privacy Policy"))
        XCTAssertEqual(AppStoreReleasePlan.standardEULAURL.host, "www.apple.com")
        XCTAssertEqual(AppStoreReleasePlan.standardEULAURL.absoluteString, "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    }
}
