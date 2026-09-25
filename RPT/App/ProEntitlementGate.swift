//
//  ProEntitlementGate.swift
//  RPT
//
//  In-memory entitlement state machine. A verified purchase or
//  Transaction.updates result must not be overwritten by an older or
//  in-flight currentEntitlements refresh that returns nothing.
//

import Foundation

struct ProEntitlementRecord: Equatable, Sendable {
    let productID: String
    let purchaseDate: Date
    let revocationDate: Date?
    let expirationDate: Date?

    func isActive(at now: Date) -> Bool {
        guard MonetizationPlan.proProductIDs.contains(productID) else {
            return false
        }
        if revocationDate != nil {
            return false
        }
        if let expirationDate, expirationDate <= now {
            return false
        }
        return true
    }
}

enum ProEntitlementRefreshKind: Equatable, Sendable {
    /// Launch, restore, or a verified revocation follow-up. An empty
    /// currentEntitlements snapshot is authoritative.
    case canonical
    /// Product load or other opportunistic refresh. An empty snapshot
    /// cannot undo a verified grant that has not been revoked.
    case opportunistic
}

struct ProEntitlementGate: Equatable, Sendable {
    private(set) var isUnlocked = false
    private(set) var generation: UInt64 = 0
    private(set) var lastVerifiedPurchaseDate: Date?
    private(set) var lastVerifiedWasRevocation = false

    mutating func beginRefresh() -> UInt64 {
        generation &+= 1
        return generation
    }

    mutating func applyVerifiedTransaction(_ record: ProEntitlementRecord, now: Date = Date()) {
        generation &+= 1

        if record.isActive(at: now) {
            lastVerifiedPurchaseDate = record.purchaseDate
            lastVerifiedWasRevocation = false
            isUnlocked = true
            return
        }

        if let lastVerifiedPurchaseDate, record.purchaseDate < lastVerifiedPurchaseDate, isUnlocked {
            return
        }

        lastVerifiedWasRevocation = true
    }

    @discardableResult
    mutating func applyRefresh(
        generation refreshGeneration: UInt64,
        entitlements: [ProEntitlementRecord],
        kind: ProEntitlementRefreshKind,
        now: Date = Date()
    ) -> Bool {
        let active = entitlements.filter { $0.isActive(at: now) }

        if refreshGeneration != generation {
            if active.isEmpty || lastVerifiedWasRevocation {
                return isUnlocked
            }
            if let latest = latestActive(in: active) {
                grant(latest)
            }
            return isUnlocked
        }

        if let latest = latestActive(in: active) {
            grant(latest)
            return true
        }

        if kind == .opportunistic,
           isUnlocked,
           !lastVerifiedWasRevocation,
           lastVerifiedPurchaseDate != nil {
            return true
        }

        isUnlocked = false
        return false
    }

    mutating func forceRevoke() {
        generation &+= 1
        isUnlocked = false
        lastVerifiedWasRevocation = true
    }

    mutating func reset() {
        self = ProEntitlementGate()
    }

    private mutating func grant(_ record: ProEntitlementRecord) {
        lastVerifiedPurchaseDate = record.purchaseDate
        lastVerifiedWasRevocation = false
        isUnlocked = true
    }

    private func latestActive(in records: [ProEntitlementRecord]) -> ProEntitlementRecord? {
        records.max { lhs, rhs in
            if lhs.purchaseDate != rhs.purchaseDate {
                return lhs.purchaseDate < rhs.purchaseDate
            }
            return false
        }
    }
}
