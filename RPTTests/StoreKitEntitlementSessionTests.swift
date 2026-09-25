import StoreKit
import StoreKitTest
import XCTest
@testable import RPT

@MainActor
final class StoreKitEntitlementSessionTests: XCTestCase {
    private var session: SKTestSession?

    override func setUpWithError() throws {
        let session = try SKTestSession(contentsOf: try Self.storeKitConfigurationURL())
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        self.session = session
        StoreKitPurchaseManager.shared.resetEntitlementStateForTesting()
    }

    override func tearDownWithError() throws {
        session?.clearTransactions()
        session = nil
        StoreKitPurchaseManager.shared.resetEntitlementStateForTesting()
    }

    func testStoreKitConfigurationUsesMonetizationProductID() throws {
        let data = try Data(contentsOf: try Self.storeKitConfigurationURL())
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let products = try XCTUnwrap(json["products"] as? [[String: Any]])
        let productIDs = products.compactMap { $0["productID"] as? String }

        XCTAssertEqual(productIDs, MonetizationPlan.proProductIDs)
        XCTAssertEqual(productIDs, ["rpt.pro.lifetime"])
    }

    func testBuyProductAppearsInCurrentEntitlements() async throws {
        let session = try XCTUnwrap(self.session)
        let transaction = try await session.buyProduct(
            identifier: MonetizationPlan.proProductID,
            options: []
        )

        XCTAssertEqual(transaction.productID, MonetizationPlan.proProductID)
        XCTAssertNil(transaction.revocationDate)
        let entitledIDs = await currentEntitlementProductIDs()
        XCTAssertTrue(entitledIDs.contains(MonetizationPlan.proProductID))
    }

    func testRefundRemovesLifetimeEntitlement() async throws {
        let session = try XCTUnwrap(self.session)
        let transaction = try await session.buyProduct(
            identifier: MonetizationPlan.proProductID,
            options: []
        )
        try session.refundTransaction(identifier: try refundIdentifier(in: session, after: transaction))

        let activeIDs = await currentEntitlementProductIDs()
        XCTAssertFalse(activeIDs.contains(MonetizationPlan.proProductID))
    }

    func testManagerRefreshUnlocksAfterPurchaseAndLocksAfterRefund() async throws {
        let session = try XCTUnwrap(self.session)
        let manager = StoreKitPurchaseManager.shared

        let transaction = try await session.buyProduct(
            identifier: MonetizationPlan.proProductID,
            options: []
        )
        let unlocked = await manager.refreshPurchasedState()
        XCTAssertTrue(unlocked)
        XCTAssertTrue(manager.isUnlocked)
        XCTAssertEqual(manager.state, .unlocked)

        try session.refundTransaction(identifier: try refundIdentifier(in: session, after: transaction))

        let stillUnlocked = await manager.refreshPurchasedState()
        XCTAssertFalse(stillUnlocked)
        XCTAssertFalse(manager.isUnlocked)
    }

    func testAskToBuyPurchaseStaysOutOfCurrentEntitlementsUntilApproved() async throws {
        let session = try XCTUnwrap(self.session)
        session.askToBuyEnabled = true

        try session.buyProduct(productIdentifier: MonetizationPlan.proProductID)

        let pendingIDs = await currentEntitlementProductIDs()
        XCTAssertFalse(pendingIDs.contains(MonetizationPlan.proProductID))

        let pending = try XCTUnwrap(
            session.allTransactions().first { $0.productIdentifier == MonetizationPlan.proProductID }
        )
        XCTAssertTrue(pending.pendingAskToBuyConfirmation)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)

        let approvedIDs = await currentEntitlementProductIDs()
        XCTAssertTrue(approvedIDs.contains(MonetizationPlan.proProductID))
    }

    private func refundIdentifier(in session: SKTestSession, after transaction: Transaction) throws -> UInt {
        if let identifier = session.allTransactions().first(where: {
            $0.productIdentifier == transaction.productID
        })?.identifier {
            return identifier
        }
        return try XCTUnwrap(UInt(exactly: transaction.id))
    }

    private func currentEntitlementProductIDs() async -> [String] {
        var productIDs: [String] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.revocationDate == nil {
                productIDs.append(transaction.productID)
            }
        }
        return productIDs
    }

    private static func storeKitConfigurationURL() throws -> URL {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let url = testsDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("RPT/Configuration/RPTPro.storekit")

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("RPTPro.storekit is not reachable from this test host")
        }
        return url
    }
}
