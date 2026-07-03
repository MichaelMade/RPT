//
//  AppStoreReleasePlan.swift
//  RPT
//
//  First-pass App Store packaging plan kept in code so release copy,
//  screenshot planning, and monetization positioning do not drift.
//

import Foundation

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
