//
//  MonetizationPlan.swift
//  RPT
//
//  Productized definition of the free app versus the paid upgrade so
//  roadmap decisions and future StoreKit work share one source of truth.
//

import Foundation

struct MonetizationTier: Equatable {
    let name: String
    let summary: String
    let features: [String]
}

enum MonetizationPlan {
    static let proProductID = "rpt.pro.lifetime"
    static let proProductIDs = [proProductID]

    static let freeTier = MonetizationTier(
        name: "RPT Free",
        summary: "Log workouts, follow the built-in RPT split, and build momentum without a signup.",
        features: [
            "Unlimited workout logging",
            "Built-in three-day RPT split, three custom templates, and basic progress stats",
            "On-device data with no account required"
        ]
    )

    static let proTier = MonetizationTier(
        name: "RPT Pro",
        summary: "Unlock advanced analytics, unlimited templates, and CSV export with one lifetime purchase.",
        features: [
            "Advanced analytics and personal-record trends",
            "Unlimited custom templates",
            "CSV export for your complete training history"
        ]
    )

    /// The app seeds three built-in days and lets free users add three custom
    /// templates. Unlimited templates are part of RPT Pro.
    static let freeTemplateLimit = 6

    static func canCreateTemplate(existingCount: Int, isUnlocked: Bool) -> Bool {
        isUnlocked || existingCount < freeTemplateLimit
    }

    static let purchaseOfferTitle = "Lifetime unlock"
    static let purchaseOfferSummary = "One-time purchase. No subscription."
    static let upgradeCTA = "RPT Pro unlocks advanced analytics, unlimited templates, and CSV export."
    static let storeKitNote = "Purchases are handled securely by the App Store and can be restored anytime."
}

enum MonetizationPurchaseState: Equatable {
    case loadingStore
    case ready
    case purchasing
    case restoring
    case pendingApproval
    case unlocked
    case unavailable

    var isBusy: Bool {
        switch self {
        case .loadingStore, .purchasing, .restoring, .pendingApproval:
            return true
        case .ready, .unlocked, .unavailable:
            return false
        }
    }

    var displayMessage: String {
        switch self {
        case .loadingStore:
            return "Checking App Store availability."
        case .ready:
            return "One lifetime purchase. No subscription."
        case .purchasing:
            return "Completing your purchase with the App Store."
        case .restoring:
            return "Checking your App Store purchases."
        case .pendingApproval:
            return "Purchase is pending App Store approval."
        case .unlocked:
            return "RPT Pro is unlocked on this device."
        case .unavailable:
            return "RPT Pro is unavailable right now. Check your connection and try again."
        }
    }
}
