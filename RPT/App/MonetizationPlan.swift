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
        summary: "Log workouts, follow the starter template, and build momentum without a signup.",
        features: [
            "Unlimited workout logging",
            "Starter template plus basic progress stats",
            "On-device data with no account required"
        ]
    )

    static let proTier = MonetizationTier(
        name: "RPT Pro",
        summary: "Unlock advanced analytics, unlimited templates, and CSV export once the App Store upgrade goes live.",
        features: [
            "Advanced analytics and personal-record trends",
            "Unlimited custom templates",
            "CSV export for your complete training history"
        ]
    )

    static let launchPrice = "$9.99"
    static let launchOfferTitle = "Lifetime unlock"
    static let launchOfferSummary = "One-time purchase planned for the first App Store release."
    static let upgradeCTA = "RPT Pro unlocks advanced analytics, unlimited templates, and CSV export."
    static let storeKitNote = "StoreKit purchase flow will be verified on Mac before the App Store build ships."

    static let freeCustomTemplateLimit = 1
    static let starterTemplateName = "Upper Body RPT"
    static let templateLimitTitle = "Unlock Unlimited Templates"
    static let templateLimitSummary = "RPT Free includes the starter template plus one custom routine. RPT Pro unlocks unlimited custom templates for every split you run."
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
        case .loadingStore, .purchasing, .restoring:
            return true
        case .ready, .pendingApproval, .unlocked, .unavailable:
            return false
        }
    }

    var displayMessage: String {
        switch self {
        case .loadingStore:
            return "Loading the RPT Pro upgrade from the App Store."
        case .ready:
            return "StoreKit is ready for the lifetime RPT Pro upgrade."
        case .purchasing:
            return "Opening the App Store purchase sheet."
        case .restoring:
            return "Checking your App Store purchases."
        case .pendingApproval:
            return "Purchase is pending App Store approval."
        case .unlocked:
            return "RPT Pro is unlocked on this device."
        case .unavailable:
            return "RPT Pro is not available from the App Store yet."
        }
    }
}
