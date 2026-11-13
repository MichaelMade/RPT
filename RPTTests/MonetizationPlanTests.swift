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
        XCTAssertTrue(MonetizationPlan.proTier.features.contains("Advanced analytics — weekly volume charts, muscle balance, and your PR leaderboard"))
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

    func testProAnalyticsBulletOnlyPromisesWhatIsGated() {
        // The per-exercise e1RM trend chart is free. Selling it as a Pro
        // feature misdescribes the purchase.
        let analyticsBullet = MonetizationPlan.proTier.features[0]
        XCTAssertFalse(analyticsBullet.localizedCaseInsensitiveContains("e1RM"))
        XCTAssertTrue(analyticsBullet.contains("weekly volume"))
        XCTAssertTrue(analyticsBullet.contains("muscle balance"))
    }

    func testEveryGateExplainsWhyThePaywallAppeared() {
        XCTAssertEqual(MonetizationPlan.gateTitle(for: .templateLimit), MonetizationPlan.gateTemplatesTitle)
        XCTAssertEqual(MonetizationPlan.gateTitle(for: .csvExport), MonetizationPlan.gateCSVTitle)
        XCTAssertEqual(MonetizationPlan.gateTitle(for: .advancedStats), MonetizationPlan.gateAdvancedStatsTitle)

        for reason in [FunnelGateReason.templateLimit, .csvExport, .advancedStats] {
            let message = MonetizationPlan.gateMessage(for: reason)
            XCTAssertTrue(message.hasPrefix(MonetizationPlan.gateBenefit(for: reason)))
            XCTAssertTrue(message.contains("Unlock RPT Pro once"), "\(reason.rawValue) gate must carry the one-time offer")
        }

        XCTAssertTrue(
            MonetizationPlan.gateBenefit(for: .templateLimit).contains("three templates of your own"),
            "The template gate should state the free allowance the user just reached"
        )
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
