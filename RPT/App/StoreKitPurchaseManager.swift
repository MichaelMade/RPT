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
    @Published var alertMessage: String?

    private var updatesTask: Task<Void, Never>?

    var displayPrice: String {
        proProduct?.displayPrice ?? MonetizationPlan.launchPrice
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
        case .ready, .unavailable, .unlocked:
            return "Unlock RPT Pro for \(displayPrice)"
        }
    }

    var canPurchase: Bool {
        proProduct != nil && !isUnlocked && !state.isBusy
    }

    private init() {}

    deinit {
        updatesTask?.cancel()
    }

    func start() async {
        observeTransactionUpdates()
        await refreshPurchasedState()
        await loadProducts()
    }

    func loadProducts() async {
        if !isUnlocked {
            state = .loadingStore
        }

        do {
            let products = try await Product.products(for: MonetizationPlan.proProductIDs)
            proProduct = products.first { $0.id == MonetizationPlan.proProductID }
            let hasEntitlement = await refreshPurchasedState()

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
        if proProduct == nil {
            await loadProducts()
        }

        guard let proProduct else {
            state = .unavailable
            alertMessage = "RPT Pro is not available from the App Store yet."
            return
        }

        state = .purchasing

        do {
            let result = try await proProduct.purchase()

            switch result {
            case .success(let verification):
                let transaction = try Self.verified(verification)
                await transaction.finish()
                isUnlocked = true
                state = .unlocked
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
    func refreshPurchasedState() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.verified(result) else {
                continue
            }

            if MonetizationPlan.proProductIDs.contains(transaction.productID) {
                isUnlocked = true
                state = .unlocked
                return true
            }
        }

        isUnlocked = false
        if proProduct != nil {
            state = .ready
        }
        return false
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

            if MonetizationPlan.proProductIDs.contains(transaction.productID) {
                await transaction.finish()
                isUnlocked = true
                state = .unlocked
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
}

private enum StoreKitPurchaseError: Error {
    case failedVerification
}
