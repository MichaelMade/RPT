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
}

struct AppStoreScreenshotShot: Equatable {
    let title: String
    let caption: String
    let targetScreen: String
}

enum AppStoreReleasePlan {
    static let appName = "RPT"
    static let subtitle = "Reverse pyramid training log"
    static let promotionalText = "Log heavy top sets first, get RPT back-off guidance, and track strength trends without an account."
    static let shortDescription = "A focused strength-training log for reverse pyramid training, progressive overload, and private on-device workout history."

    static let keywordPhrases = [
        "rpt",
        "strength log",
        "workout tracker",
        "progressive overload",
        "weight lifting",
        "gym planner",
        "rest timer",
        "1rm"
    ]

    static let releasePositioningBullets = [
        "Built for lifters who train heavy first instead of chasing generic workout templates.",
        "Keeps the core training loop free: logging, starter template, and basic stats need no signup.",
        "RPT Pro is positioned as a one-time lifetime upgrade for deeper analytics, unlimited templates, and CSV export.",
        "Private by design: training data stays on device unless the user exports it."
    ]

    static let screenshotPlan = [
        AppStoreScreenshotShot(
            title: "Start Heavy",
            caption: "Open with your top set, then let RPT calculate every back-off set.",
            targetScreen: "Active workout logging"
        ),
        AppStoreScreenshotShot(
            title: "Plan the Session",
            caption: "Reusable templates, warm-up ramps, plate math, and RPT weight drops stay one tap away.",
            targetScreen: "Templates and workout tools"
        ),
        AppStoreScreenshotShot(
            title: "Track Progress",
            caption: "See volume, consistency, PRs, and estimated 1RM trends from completed working sets.",
            targetScreen: "Stats dashboard"
        ),
        AppStoreScreenshotShot(
            title: "Stay Private",
            caption: "No account, no tracking, on-device history, and CSV export when you unlock RPT Pro.",
            targetScreen: "Settings and export"
        ),
        AppStoreScreenshotShot(
            title: "Unlock RPT Pro",
            caption: "A lifetime upgrade for advanced analytics, unlimited custom templates, and full CSV export.",
            targetScreen: "RPT Pro upgrade"
        )
    ]

    static let supportURL = URL(string: "https://github.com/MichaelMade/RPT/issues")!
    static let privacyURL = URL(string: "https://github.com/MichaelMade/RPT/blob/master/Privacy%20Policy")!

    static var keywordCharacterCount: Int {
        keywordPhrases.joined(separator: ",").count
    }

    static var hasAppStoreSafeKeywordLength: Bool {
        keywordCharacterCount <= 100
    }
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
