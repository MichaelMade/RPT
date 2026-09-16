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
        XCTAssertEqual(MonetizationPlan.purchaseOfferTitle, "One-time · No subscription")
        XCTAssertEqual(MonetizationPlan.purchaseOfferSummary, "One-time purchase. No subscription.")
        XCTAssertTrue(MonetizationPlan.proTier.features.contains("Advanced analytics — weekly volume, muscle balance, PR & e1RM trends"))
        XCTAssertTrue(MonetizationPlan.proTier.features.contains("Unlimited custom templates"))
        XCTAssertTrue(MonetizationPlan.proTier.features.contains("Full CSV export of every logged set"))
    }

    func testUpgradeCTAStaysAlignedWithProValueProp() {
        XCTAssertEqual(
            MonetizationPlan.upgradeCTA,
            "RPT Pro unlocks advanced analytics, unlimited templates, and full CSV export."
        )
    }

    func testPurchaseStateMessagesSupportStoreKitSurfaces() {
        XCTAssertEqual(
            MonetizationPurchaseState.ready.displayMessage,
            "One purchase, yours forever. No subscription. Restore anytime with your Apple ID."
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

    func testGateSheetTitlesAreConfigured() {
        XCTAssertEqual(MonetizationPlan.gateTemplatesTitle, "You've used your free custom templates")
        XCTAssertEqual(MonetizationPlan.gateCSVTitle, "Export your full training history")
        XCTAssertEqual(MonetizationPlan.gateAdvancedStatsTitle, "See the trends behind your lifts")
    }

    func testGateBodyIncludesAntiSubscriptionMessage() {
        let body = MonetizationPlan.gateBody(for: "Test benefit.")
        XCTAssertTrue(body.contains("Unlock RPT Pro once"))
        XCTAssertTrue(body.contains("no subscription"))
    }

    func testPrivacyNoteIsExposed() {
        XCTAssertEqual(MonetizationPlan.privacyNote, "No account. No ads. No tracking.")
    }

    func testStoreKitNoteIncludesPrivacyAndRestoreGuidance() {
        XCTAssertTrue(MonetizationPlan.storeKitNote.contains("No account"))
        XCTAssertTrue(MonetizationPlan.storeKitNote.contains("Apple ID"))
    }
}
