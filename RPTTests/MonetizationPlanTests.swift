import XCTest
@testable import RPT

final class MonetizationPlanTests: XCTestCase {
    func testFreeTierKeepsCoreTrainingValueFree() {
        XCTAssertEqual(MonetizationPlan.freeTier.name, "RPT Free")
        XCTAssertTrue(MonetizationPlan.freeTier.features.contains("Unlimited workout logging"))
        XCTAssertTrue(MonetizationPlan.freeTier.features.contains("Starter template plus basic progress stats"))
    }

    func testProTierDefinesPaidValueForLaunch() {
        XCTAssertEqual(MonetizationPlan.proTier.name, "RPT Pro")
        XCTAssertEqual(MonetizationPlan.launchPrice, "$9.99")
        XCTAssertEqual(MonetizationPlan.launchOfferTitle, "Lifetime unlock")
        XCTAssertTrue(MonetizationPlan.proTier.features.contains("Advanced analytics and personal-record trends"))
        XCTAssertTrue(MonetizationPlan.proTier.features.contains("Unlimited custom templates"))
        XCTAssertTrue(MonetizationPlan.proTier.features.contains("CSV export for your complete training history"))
    }

    func testUpgradeCTAStaysAlignedWithProValueProp() {
        XCTAssertEqual(
            MonetizationPlan.upgradeCTA,
            "RPT Pro unlocks advanced analytics, unlimited templates, and CSV export."
        )
    }
}
