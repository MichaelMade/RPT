import XCTest
@testable import RPT

final class ProEntitlementGateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000)

    func testPurchaseThenStaleEmptyRefreshKeepsPro() {
        var gate = ProEntitlementGate()
        gate.applyVerifiedTransaction(record(purchaseDate: 1_000), now: now)

        XCTAssertTrue(gate.isUnlocked)
        XCTAssertEqual(gate.lastVerifiedPurchaseDate, Date(timeIntervalSince1970: 1_000))

        let generation = gate.beginRefresh()
        let stillUnlocked = gate.applyRefresh(
            generation: generation,
            entitlements: [],
            kind: .opportunistic,
            now: now
        )

        XCTAssertTrue(stillUnlocked)
        XCTAssertTrue(gate.isUnlocked)
    }

    func testInFlightEmptyRefreshDoesNotOverwritePurchase() {
        var gate = ProEntitlementGate()
        let staleGeneration = gate.beginRefresh()

        gate.applyVerifiedTransaction(record(purchaseDate: 1_500), now: now)
        XCTAssertTrue(gate.isUnlocked)

        let ignored = gate.applyRefresh(
            generation: staleGeneration,
            entitlements: [],
            kind: .canonical,
            now: now
        )

        XCTAssertTrue(ignored)
        XCTAssertTrue(gate.isUnlocked)
    }

    func testRefundRemovesProAfterEmptyCurrentEntitlements() {
        var gate = ProEntitlementGate()
        let purchase = record(purchaseDate: 1_000)
        gate.applyVerifiedTransaction(purchase, now: now)

        gate.applyVerifiedTransaction(record(purchaseDate: 1_000, revokedAt: 1_800), now: now)
        XCTAssertTrue(gate.lastVerifiedWasRevocation)
        XCTAssertFalse(gate.isUnlocked)

        let generation = gate.beginRefresh()
        let hasEntitlement = gate.applyRefresh(
            generation: generation,
            entitlements: [],
            kind: .canonical,
            now: now
        )

        XCTAssertFalse(hasEntitlement)
        XCTAssertFalse(gate.isUnlocked)
    }

    func testOpportunisticEmptyRefreshAfterRevocationStillLocks() {
        var gate = ProEntitlementGate()
        gate.applyVerifiedTransaction(record(purchaseDate: 1_000), now: now)
        gate.applyVerifiedTransaction(record(purchaseDate: 1_000, revokedAt: 1_800), now: now)

        let generation = gate.beginRefresh()
        XCTAssertFalse(
            gate.applyRefresh(
                generation: generation,
                entitlements: [],
                kind: .opportunistic,
                now: now
            )
        )
        XCTAssertFalse(gate.isUnlocked)
    }

    func testCanonicalEmptyRefreshAfterRefundLocksWithoutWaitingForUpdatesFlag() {
        var gate = ProEntitlementGate()
        gate.applyVerifiedTransaction(record(purchaseDate: 1_000), now: now)

        let generation = gate.beginRefresh()
        let hasEntitlement = gate.applyRefresh(
            generation: generation,
            entitlements: [],
            kind: .canonical,
            now: now
        )

        XCTAssertFalse(hasEntitlement)
        XCTAssertFalse(gate.isUnlocked)
    }

    func testOlderRevocationDoesNotLockNewerRepurchase() {
        var gate = ProEntitlementGate()
        gate.applyVerifiedTransaction(record(purchaseDate: 1_000), now: now)
        gate.applyVerifiedTransaction(record(purchaseDate: 1_600), now: now)

        gate.applyVerifiedTransaction(record(purchaseDate: 1_000, revokedAt: 1_800), now: now)

        XCTAssertTrue(gate.isUnlocked)
        XCTAssertFalse(gate.lastVerifiedWasRevocation)

        let generation = gate.beginRefresh()
        let hasEntitlement = gate.applyRefresh(
            generation: generation,
            entitlements: [record(purchaseDate: 1_600)],
            kind: .canonical,
            now: now
        )

        XCTAssertTrue(hasEntitlement)
        XCTAssertTrue(gate.isUnlocked)
    }

    func testRelaunchRestoresFromCurrentEntitlements() {
        var gate = ProEntitlementGate()
        XCTAssertFalse(gate.isUnlocked)

        let generation = gate.beginRefresh()
        let restored = gate.applyRefresh(
            generation: generation,
            entitlements: [record(purchaseDate: 900)],
            kind: .canonical,
            now: now
        )

        XCTAssertTrue(restored)
        XCTAssertTrue(gate.isUnlocked)
        XCTAssertEqual(gate.lastVerifiedPurchaseDate, Date(timeIntervalSince1970: 900))
    }

    func testRelaunchWithoutEntitlementsStaysLocked() {
        var gate = ProEntitlementGate()
        let generation = gate.beginRefresh()
        let restored = gate.applyRefresh(
            generation: generation,
            entitlements: [],
            kind: .canonical,
            now: now
        )

        XCTAssertFalse(restored)
        XCTAssertFalse(gate.isUnlocked)
    }

    func testExpiredTransactionDoesNotUnlock() {
        var gate = ProEntitlementGate()
        let expired = ProEntitlementRecord(
            productID: MonetizationPlan.proProductID,
            purchaseDate: Date(timeIntervalSince1970: 1_000),
            revocationDate: nil,
            expirationDate: Date(timeIntervalSince1970: 1_500)
        )

        gate.applyVerifiedTransaction(expired, now: now)
        XCTAssertFalse(gate.isUnlocked)
        XCTAssertTrue(gate.lastVerifiedWasRevocation)

        let generation = gate.beginRefresh()
        XCTAssertFalse(
            gate.applyRefresh(
                generation: generation,
                entitlements: [expired],
                kind: .canonical,
                now: now
            )
        )
        XCTAssertFalse(gate.isUnlocked)
    }

    func testUnknownProductDoesNotUnlock() {
        var gate = ProEntitlementGate()
        gate.applyVerifiedTransaction(
            ProEntitlementRecord(
                productID: "not.a.real.product",
                purchaseDate: Date(timeIntervalSince1970: 1_000),
                revocationDate: nil,
                expirationDate: nil
            ),
            now: now
        )

        XCTAssertFalse(gate.isUnlocked)
    }

    func testStaleGrantDoesNotReunlockAfterRevocation() {
        var gate = ProEntitlementGate()
        let purchase = record(purchaseDate: 1_000)
        let staleGeneration = gate.beginRefresh()

        gate.applyVerifiedTransaction(purchase, now: now)
        gate.applyVerifiedTransaction(record(purchaseDate: 1_000, revokedAt: 1_800), now: now)

        let generation = gate.beginRefresh()
        XCTAssertFalse(
            gate.applyRefresh(generation: generation, entitlements: [], kind: .canonical, now: now)
        )
        XCTAssertFalse(gate.isUnlocked)

        XCTAssertFalse(
            gate.applyRefresh(
                generation: staleGeneration,
                entitlements: [purchase],
                kind: .opportunistic,
                now: now
            )
        )
        XCTAssertFalse(gate.isUnlocked)
    }

    func testForceRevokeLocksEvenWhenAPurchaseWasJustVerified() {
        var gate = ProEntitlementGate()
        gate.applyVerifiedTransaction(record(purchaseDate: 1_000), now: now)
        gate.forceRevoke()

        XCTAssertFalse(gate.isUnlocked)
        XCTAssertTrue(gate.lastVerifiedWasRevocation)
    }

    func testDelayedStaleActiveUpdateAfterRefundStaysLocked() {
        var gate = ProEntitlementGate()
        let purchase = record(purchaseDate: 1_000, id: 10, signedDate: 1_000)
        gate.applyVerifiedTransaction(purchase, now: now)
        gate.applyVerifiedTransaction(
            record(purchaseDate: 1_000, revokedAt: 1_800, id: 10, signedDate: 1_000),
            now: now
        )
        XCTAssertFalse(gate.isUnlocked)

        gate.applyVerifiedTransaction(purchase, now: now)

        XCTAssertFalse(gate.isUnlocked)
        XCTAssertTrue(gate.lastVerifiedWasRevocation)
        XCTAssertTrue(gate.isAtOrBeforeKnownRevocation(purchase))
    }

    func testNewPurchaseAfterRefundStillUnlocks() {
        var gate = ProEntitlementGate()
        gate.applyVerifiedTransaction(record(purchaseDate: 1_000, id: 10), now: now)
        gate.applyVerifiedTransaction(
            record(purchaseDate: 1_000, revokedAt: 1_800, id: 10),
            now: now
        )
        XCTAssertFalse(gate.isUnlocked)

        let repurchase = record(purchaseDate: 1_900, id: 11, signedDate: 1_900)
        XCTAssertTrue(gate.applyVerifiedTransaction(repurchase, now: now))
        XCTAssertTrue(gate.isUnlocked)
        XCTAssertFalse(gate.lastVerifiedWasRevocation)
    }

    func testPostGrantRevalidationRevokesWhenSnapshotShowsSameTransactionRevoked() {
        var gate = ProEntitlementGate()
        let purchase = record(purchaseDate: 1_000, id: 10)
        gate.applyVerifiedTransaction(purchase, now: now)

        let generation = gate.beginRefresh()
        let revoked = record(purchaseDate: 1_000, revokedAt: 1_800, id: 10)
        XCTAssertFalse(
            gate.applyRefresh(
                generation: generation,
                entitlements: [revoked],
                kind: .postGrantRevalidation,
                now: now
            )
        )
        XCTAssertFalse(gate.isUnlocked)
    }

    func testPostGrantRevalidationKeepsProOnEmptySnapshotInsideGrace() {
        var gate = ProEntitlementGate()
        gate.applyVerifiedTransaction(record(purchaseDate: 1_000, id: 10), now: now)

        let generation = gate.beginRefresh()
        XCTAssertTrue(
            gate.applyRefresh(
                generation: generation,
                entitlements: [],
                kind: .postGrantRevalidation,
                now: now
            )
        )
        XCTAssertTrue(gate.isUnlocked)
    }

    func testCanonicalEmptySnapshotAfterRepurchaseRemembersLatestRevocationAndRejectsStaleUpdate() {
        var gate = ProEntitlementGate()
        let purchaseA = record(purchaseDate: 1_000, id: 10, signedDate: 1_000)
        let purchaseB = record(purchaseDate: 1_900, id: 11, signedDate: 1_900)

        gate.applyVerifiedTransaction(purchaseA, now: now)
        gate.applyVerifiedTransaction(
            record(purchaseDate: 1_000, revokedAt: 1_800, id: 10, signedDate: 1_000),
            now: now
        )
        XCTAssertFalse(gate.isUnlocked)

        XCTAssertTrue(gate.applyVerifiedTransaction(purchaseB, now: now))
        XCTAssertTrue(gate.isUnlocked)
        XCTAssertEqual(gate.lastGrantedSignedDate, Date(timeIntervalSince1970: 1_900))

        let generation = gate.beginRefresh()
        XCTAssertFalse(
            gate.applyRefresh(
                generation: generation,
                entitlements: [],
                kind: .canonical,
                now: now
            )
        )
        XCTAssertFalse(gate.isUnlocked)
        XCTAssertTrue(gate.lastVerifiedWasRevocation)
        XCTAssertEqual(gate.lastRevokedPurchaseDate, Date(timeIntervalSince1970: 1_900))
        XCTAssertEqual(gate.lastRevokedSignedDate, Date(timeIntervalSince1970: 1_900))
        XCTAssertEqual(gate.lastRevokedTransactionID, 11)
        XCTAssertTrue(gate.isAtOrBeforeKnownRevocation(purchaseB))

        gate.applyVerifiedTransaction(purchaseB, now: now)

        XCTAssertFalse(gate.isUnlocked)
        XCTAssertTrue(gate.lastVerifiedWasRevocation)
        XCTAssertTrue(gate.isAtOrBeforeKnownRevocation(purchaseB))
    }

    func testRepurchaseAfterLatestEmptySnapshotRevocationStillUnlocks() {
        var gate = ProEntitlementGate()
        let purchaseA = record(purchaseDate: 1_000, id: 10, signedDate: 1_000)
        let purchaseB = record(purchaseDate: 1_900, id: 11, signedDate: 1_900)
        let purchaseC = record(purchaseDate: 2_100, id: 12, signedDate: 2_100)

        gate.applyVerifiedTransaction(purchaseA, now: now)
        gate.applyVerifiedTransaction(
            record(purchaseDate: 1_000, revokedAt: 1_800, id: 10, signedDate: 1_000),
            now: now
        )
        gate.applyVerifiedTransaction(purchaseB, now: now)

        let generation = gate.beginRefresh()
        XCTAssertFalse(
            gate.applyRefresh(
                generation: generation,
                entitlements: [],
                kind: .canonical,
                now: now
            )
        )
        gate.applyVerifiedTransaction(purchaseB, now: now)
        XCTAssertFalse(gate.isUnlocked)

        XCTAssertTrue(gate.applyVerifiedTransaction(purchaseC, now: now))
        XCTAssertTrue(gate.isUnlocked)
        XCTAssertFalse(gate.lastVerifiedWasRevocation)
        XCTAssertEqual(gate.lastGrantedSignedDate, Date(timeIntervalSince1970: 2_100))
        XCTAssertFalse(gate.isAtOrBeforeKnownRevocation(purchaseC))
    }

    private func record(
        purchaseDate: TimeInterval,
        revokedAt: TimeInterval? = nil,
        id: UInt64? = nil,
        signedDate: TimeInterval? = nil
    ) -> ProEntitlementRecord {
        ProEntitlementRecord(
            productID: MonetizationPlan.proProductID,
            purchaseDate: Date(timeIntervalSince1970: purchaseDate),
            revocationDate: revokedAt.map(Date.init(timeIntervalSince1970:)),
            expirationDate: nil,
            id: id,
            signedDate: signedDate.map(Date.init(timeIntervalSince1970:))
        )
    }
}
