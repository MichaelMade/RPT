import XCTest
@testable import RPT

final class MonetizationPlanTests: XCTestCase {
    func testFreeTierKeepsCoreTrainingValueFree() {
        XCTAssertEqual(MonetizationPlan.freeTier.name, "RPT Free")
        XCTAssertTrue(MonetizationPlan.freeTier.features.contains("Unlimited workout logging"))
        XCTAssertTrue(
            MonetizationPlan.freeTier.features.contains(
                "Built-in three-day RPT split, three custom templates, and basic progress stats"
            )
        )
    }

    func testProTierDefinesLifetimePaidValue() {
        XCTAssertEqual(MonetizationPlan.proTier.name, "RPT Pro")
        XCTAssertEqual(MonetizationPlan.proProductID, "rpt.pro.lifetime")
        XCTAssertEqual(MonetizationPlan.proProductIDs, ["rpt.pro.lifetime"])
        XCTAssertEqual(MonetizationPlan.purchaseOfferTitle, "Lifetime unlock")
        XCTAssertEqual(MonetizationPlan.purchaseOfferSummary, "One-time purchase. No subscription.")
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

    func testPurchaseStateMessagesSupportStoreKitSurfaces() {
        XCTAssertEqual(
            MonetizationPurchaseState.ready.displayMessage,
            "One lifetime purchase. No subscription."
        )
        XCTAssertEqual(
            MonetizationPurchaseState.unlocked.displayMessage,
            "RPT Pro is unlocked on this device."
        )
        XCTAssertEqual(
            MonetizationPurchaseState.unavailable.displayMessage,
            "RPT Pro is unavailable right now. Check your connection and try again."
        )
    }

    func testPendingApprovalPreventsDuplicatePurchaseActions() {
        XCTAssertTrue(MonetizationPurchaseState.pendingApproval.isBusy)
    }
}
