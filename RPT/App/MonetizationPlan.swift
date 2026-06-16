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
}
