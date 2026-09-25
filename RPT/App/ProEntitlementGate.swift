//
//  ProEntitlementGate.swift
//  RPT
//
//  In-memory entitlement state machine. A verified purchase or
//  Transaction.updates result must not be overwritten by an older or
//  in-flight currentEntitlements refresh that returns nothing.
//  A delayed active update queued before a refund must not re-grant
//  after that refund has already locked Pro.
//

import Foundation

struct ProEntitlementRecord: Equatable, Sendable {
    let productID: String
    let purchaseDate: Date
    let revocationDate: Date?
    let expirationDate: Date?
    let id: UInt64?
    let signedDate: Date?

    init(
        productID: String,
        purchaseDate: Date,
        revocationDate: Date?,
        expirationDate: Date?,
        id: UInt64? = nil,
        signedDate: Date? = nil
    ) {
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.revocationDate = revocationDate
        self.expirationDate = expirationDate
        self.id = id
        self.signedDate = signedDate
    }

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
    /// Recheck after an immediate grant. An empty snapshot inside the
    /// post-purchase grace window is lag and must not revoke. The same
    /// transaction appearing with a revocationDate must revoke.
    case postGrantRevalidation
}

struct ProEntitlementGate: Equatable, Sendable {
    static let postPurchaseGraceInterval: TimeInterval = 5

    private(set) var isUnlocked = false
    private(set) var generation: UInt64 = 0
    private(set) var lastVerifiedPurchaseDate: Date?
    private(set) var lastVerifiedWasRevocation = false
    private(set) var lastGrantedAt: Date?
    private(set) var lastGrantedTransactionID: UInt64?
    private(set) var lastGrantedSignedDate: Date?
    private(set) var lastRevokedProductID: String?
    private(set) var lastRevokedPurchaseDate: Date?
    private(set) var lastRevokedSignedDate: Date?
    private(set) var lastRevokedTransactionID: UInt64?

    mutating func beginRefresh() -> UInt64 {
        generation &+= 1
        return generation
    }

    @discardableResult
    mutating func applyVerifiedTransaction(_ record: ProEntitlementRecord, now: Date = Date()) -> Bool {
        generation &+= 1

        if record.revocationDate != nil || !record.isActive(at: now) {
            return applyInactiveTransaction(record)
        }

        if isAtOrBeforeKnownRevocation(record) {
            return isUnlocked
        }

        grant(record, now: now)
        return true
    }

    @discardableResult
    mutating func applyRefresh(
        generation refreshGeneration: UInt64,
        entitlements: [ProEntitlementRecord],
        kind: ProEntitlementRefreshKind,
        now: Date = Date()
    ) -> Bool {
        if let revokedGrant = revokedCopyOfLastGrant(in: entitlements) {
            rememberRevocation(revokedGrant)
            generation &+= 1
            isUnlocked = false
            lastVerifiedWasRevocation = true
            return false
        }

        let active = entitlements.filter { record in
            record.isActive(at: now) && !isAtOrBeforeKnownRevocation(record)
        }

        if refreshGeneration != generation {
            if active.isEmpty || lastVerifiedWasRevocation {
                return isUnlocked
            }
            if let latest = latestActive(in: active) {
                grant(latest, now: now)
            }
            return isUnlocked
        }

        if let latest = latestActive(in: active) {
            grant(latest, now: now)
            return true
        }

        if shouldKeepGrantOnEmptySnapshot(kind: kind, at: now) {
            return true
        }

        rememberRevocationOfLastGrant()
        isUnlocked = false
        lastVerifiedWasRevocation = true
        return false
    }

    mutating func forceRevoke() {
        generation &+= 1
        isUnlocked = false
        lastVerifiedWasRevocation = true
        rememberRevocationOfLastGrant()
    }

    mutating func reset() {
        self = ProEntitlementGate()
    }

    func isAtOrBeforeKnownRevocation(_ record: ProEntitlementRecord) -> Bool {
        guard let lastRevokedProductID,
              lastRevokedProductID == record.productID,
              let revokedPurchaseDate = lastRevokedPurchaseDate else {
            return false
        }

        if record.purchaseDate != revokedPurchaseDate {
            return record.purchaseDate < revokedPurchaseDate
        }

        switch (record.signedDate, lastRevokedSignedDate) {
        case let (signed?, revokedSigned?) where signed != revokedSigned:
            return signed < revokedSigned
        default:
            break
        }

        switch (record.id, lastRevokedTransactionID) {
        case let (id?, revokedID?):
            return id <= revokedID
        default:
            return true
        }
    }

    private mutating func applyInactiveTransaction(_ record: ProEntitlementRecord) -> Bool {
        if let lastVerifiedPurchaseDate, record.purchaseDate < lastVerifiedPurchaseDate, isUnlocked {
            return true
        }

        rememberRevocation(record)
        lastVerifiedWasRevocation = true
        isUnlocked = false
        return false
    }

    private mutating func grant(_ record: ProEntitlementRecord, now: Date) {
        lastVerifiedPurchaseDate = record.purchaseDate
        lastGrantedTransactionID = record.id
        lastGrantedSignedDate = record.signedDate
        lastGrantedAt = now
        lastVerifiedWasRevocation = false
        isUnlocked = true
    }

    private mutating func rememberRevocation(_ record: ProEntitlementRecord) {
        lastRevokedProductID = record.productID
        lastRevokedPurchaseDate = record.purchaseDate
        lastRevokedSignedDate = record.signedDate
        lastRevokedTransactionID = record.id
    }

    private mutating func rememberRevocationOfLastGrant() {
        guard lastGrantIsNewerThanKnownRevocation() else { return }

        lastRevokedProductID = MonetizationPlan.proProductID
        lastRevokedPurchaseDate = lastVerifiedPurchaseDate
        lastRevokedSignedDate = lastGrantedSignedDate
        lastRevokedTransactionID = lastGrantedTransactionID
    }

    private func lastGrantIsNewerThanKnownRevocation() -> Bool {
        guard lastRevokedPurchaseDate != nil else {
            return true
        }
        guard let lastVerifiedPurchaseDate else {
            return false
        }

        let lastGrant = ProEntitlementRecord(
            productID: MonetizationPlan.proProductID,
            purchaseDate: lastVerifiedPurchaseDate,
            revocationDate: nil,
            expirationDate: nil,
            id: lastGrantedTransactionID,
            signedDate: lastGrantedSignedDate
        )
        return !isAtOrBeforeKnownRevocation(lastGrant)
    }

    private func revokedCopyOfLastGrant(in entitlements: [ProEntitlementRecord]) -> ProEntitlementRecord? {
        entitlements.first { record in
            record.revocationDate != nil
                && MonetizationPlan.proProductIDs.contains(record.productID)
                && isSameAsLastGrant(record)
        }
    }

    private func isSameAsLastGrant(_ record: ProEntitlementRecord) -> Bool {
        if let lastGrantedTransactionID, let recordID = record.id {
            return record.productID == MonetizationPlan.proProductID
                && recordID == lastGrantedTransactionID
        }
        if let lastVerifiedPurchaseDate {
            return record.productID == MonetizationPlan.proProductID
                && record.purchaseDate == lastVerifiedPurchaseDate
        }
        return false
    }

    private func shouldKeepGrantOnEmptySnapshot(kind: ProEntitlementRefreshKind, at now: Date) -> Bool {
        guard isUnlocked, !lastVerifiedWasRevocation, lastVerifiedPurchaseDate != nil else {
            return false
        }

        switch kind {
        case .opportunistic:
            return true
        case .postGrantRevalidation:
            guard let lastGrantedAt else { return true }
            return now.timeIntervalSince(lastGrantedAt) < Self.postPurchaseGraceInterval
        case .canonical:
            return false
        }
    }

    private func latestActive(in records: [ProEntitlementRecord]) -> ProEntitlementRecord? {
        records.max { lhs, rhs in
            if lhs.purchaseDate != rhs.purchaseDate {
                return lhs.purchaseDate < rhs.purchaseDate
            }
            switch (lhs.id, rhs.id) {
            case let (leftID?, rightID?):
                return leftID < rightID
            default:
                return false
            }
        }
    }
}
