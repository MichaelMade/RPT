//
//  StoreKitPurchaseManager.swift
//  RPT
//
//  StoreKit 2 purchase and entitlement state for the first RPT Pro
//  lifetime unlock.
//

import Foundation
import Combine
import StoreKit

@MainActor
final class StoreKitPurchaseManager: ObservableObject {
    static let shared = StoreKitPurchaseManager()

    @Published private(set) var proProduct: Product?
    @Published private(set) var state: MonetizationPurchaseState = .loadingStore
    @Published private(set) var isUnlocked = false
    @Published private(set) var hasPreparedEntitlements = false
    @Published var alertMessage: String?

    private var updatesTask: Task<Void, Never>?
    private var isLoadingProducts = false
    private var entitlementGate = ProEntitlementGate()

    /// App Store-localized price. Never substitute a hard-coded price because
    /// storefront currency and pricing can differ by region.
    var displayPrice: String? {
        proProduct?.displayPrice
    }

    var purchaseButtonTitle: String {
        if isUnlocked {
            return "RPT Pro Unlocked"
        }

        switch state {
        case .loadingStore:
            return "Loading Upgrade"
        case .purchasing:
            return "Purchasing"
        case .restoring:
            return "Restoring"
        case .pendingApproval:
            return "Pending Approval"
        case .ready:
            if let displayPrice {
                return "Unlock RPT Pro for \(displayPrice)"
            }
            return "Unlock RPT Pro"
        case .unavailable:
            return "Try Again"
        case .unlocked:
            return "RPT Pro Unlocked"
        }
    }

    var canActivatePurchaseButton: Bool {
        guard !isUnlocked else { return false }

        switch state {
        case .ready:
            return proProduct != nil
        case .unavailable:
            return true
        case .loadingStore, .purchasing, .restoring, .pendingApproval, .unlocked:
            return false
        }
    }

    private init() {}

    deinit {
        updatesTask?.cancel()
    }

    func start() async {
        await prepareEntitlements()
        await loadProducts()
    }

    /// Starts transaction observation and restores the current unlock without
    /// waiting on a product-network request. This is safe to call at launch.
    func prepareEntitlements() async {
        observeTransactionUpdates()
        await refreshPurchasedState()
    }

    func loadProducts() async {
        // Product loading may begin from the initial `.loadingStore` state,
        // but it must never replace an in-flight customer action.
        guard state != .purchasing,
              state != .restoring,
              state != .pendingApproval else { return }

        guard proProduct == nil else {
            if !isUnlocked {
                state = .ready
            }
            return
        }
        guard !isLoadingProducts else { return }

        isLoadingProducts = true
        defer { isLoadingProducts = false }
        alertMessage = nil

        if !isUnlocked {
            state = .loadingStore
        }

        do {
            let products = try await Product.products(for: MonetizationPlan.proProductIDs)
            proProduct = products.first { $0.id == MonetizationPlan.proProductID }
            let hasEntitlement = await refreshPurchasedState(kind: .opportunistic)

            if !hasEntitlement {
                state = proProduct == nil ? .unavailable : .ready
            }
        } catch {
            if !isUnlocked {
                state = .unavailable
                alertMessage = "Could not load RPT Pro from the App Store. Please try again."
            }
        }
    }

    func purchasePro() async {
        guard !isUnlocked, state == .ready || state == .unavailable else {
            return
        }

        if proProduct == nil {
            await loadProducts()
        }

        guard let proProduct else {
            state = .unavailable
            alertMessage = "RPT Pro is unavailable right now. Check your connection and try again."
            return
        }

        state = .purchasing

        do {
            let result = try await proProduct.purchase()

            switch result {
            case .success(let verification):
                let transaction = try Self.verified(verification)
                let record = ProEntitlementRecord(transaction)
                guard record.isActive(at: Date()) else {
                    throw StoreKitPurchaseError.unexpectedTransaction
                }

                // A verified transaction is the authoritative purchase
                // result. Deliver the entitlement before finishing it.
                grantProEntitlement(from: record)
                await transaction.finish()
            case .userCancelled:
                state = .ready
            case .pending:
                state = .pendingApproval
            @unknown default:
                state = .ready
            }
        } catch {
            state = .ready
            alertMessage = "Could not complete the RPT Pro purchase. Please try again."
        }
    }

    func restorePurchases() async {
        guard !state.isBusy else { return }

        state = .restoring

        do {
            try await AppStore.sync()
            let hasEntitlement = await refreshPurchasedState()

            if !hasEntitlement {
                state = proProduct == nil ? .unavailable : .ready
                alertMessage = "No RPT Pro purchase was found for this Apple ID."
            }
        } catch {
            state = proProduct == nil ? .unavailable : .ready
            alertMessage = "Could not restore RPT Pro. Please try again."
        }
    }

    @discardableResult
    func refreshPurchasedState(kind: ProEntitlementRefreshKind = .canonical) async -> Bool {
        defer { hasPreparedEntitlements = true }

        let refreshGeneration = entitlementGate.beginRefresh()
        let records = await currentEntitlementRecords()
        let hasEntitlement = entitlementGate.applyRefresh(
            generation: refreshGeneration,
            entitlements: records,
            kind: kind
        )
        publishEntitlementState()
        return hasEntitlement
    }

    private func observeTransactionUpdates() {
        guard updatesTask == nil else { return }

        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionUpdate: result)
            }
        }
    }

    private func handle(transactionUpdate result: VerificationResult<Transaction>) async {
        do {
            let transaction = try Self.verified(result)
            let record = ProEntitlementRecord(transaction)

            if MonetizationPlan.proProductIDs.contains(record.productID) {
                if record.isActive(at: Date()) {
                    grantProEntitlement(from: record)
                    await transaction.finish()
                    return
                }

                await transaction.finish()

                // Revocation/expiration: currentEntitlements is canonical so a
                // delayed revocation of an older transaction cannot lock a newer
                // valid repurchase. A just-completed purchase is protected by the
                // generation token if this refresh is empty only because of lag.
                entitlementGate.applyVerifiedTransaction(record)
                let hasEntitlement = await refreshPurchasedState()
                if !hasEntitlement {
                    revokeProEntitlement()
                }
            }
        } catch {
            alertMessage = "Could not verify the latest App Store purchase update."
        }
    }

    private nonisolated static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, _):
            throw StoreKitPurchaseError.failedVerification
        }
    }

    private func currentEntitlementRecords() async -> [ProEntitlementRecord] {
        var records: [ProEntitlementRecord] = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.verified(result) else {
                continue
            }
            records.append(ProEntitlementRecord(transaction))
        }
        return records
    }

    private func grantProEntitlement(from record: ProEntitlementRecord) {
        entitlementGate.applyVerifiedTransaction(record)
        publishEntitlementState()
    }

    private func revokeProEntitlement() {
        entitlementGate.forceRevoke()
        publishEntitlementState()
    }

    private func publishEntitlementState() {
        isUnlocked = entitlementGate.isUnlocked
        hasPreparedEntitlements = true
        if entitlementGate.isUnlocked {
            state = .unlocked
        } else if !state.isBusy {
            state = proProduct == nil ? .unavailable : .ready
        }
    }

    #if DEBUG
    func resetEntitlementStateForTesting() {
        entitlementGate.reset()
        isUnlocked = false
        hasPreparedEntitlements = false
        state = .loadingStore
        alertMessage = nil
    }
    #endif
}

extension ProEntitlementRecord {
    init(_ transaction: Transaction) {
        self.init(
            productID: transaction.productID,
            purchaseDate: transaction.purchaseDate,
            revocationDate: transaction.revocationDate,
            expirationDate: transaction.expirationDate
        )
    }
}

private enum StoreKitPurchaseError: Error {
    case failedVerification
    case unexpectedTransaction
}
