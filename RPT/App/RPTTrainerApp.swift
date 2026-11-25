//
//  RPTTrainerApp.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData

@main
struct RPTTrainerApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let dataManager: DataManager

    init() {
        #if DEBUG
        // UI-test hook: resets first-run state via the persistent domain.
        // (An `-hasCompletedOnboarding NO` launch argument would pin the
        // value for the whole process and block the onboarding handoff.)
        if ProcessInfo.processInfo.arguments.contains("--uiTestFreshOnboarding") {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.set(RootTab.home.rawValue, forKey: "selectedRootTab")
            UserDefaults.standard.set(false, forKey: "showCreateTemplateAfterOnboarding")
        }
        #endif

        #if DEBUG
        // Hosted unit tests run in this process and read this app's
        // defaults. Without a pin, a simulator last used in kilograms (or
        // onboarded in a metric region) fails every test that asserts
        // pound output. The stored choice itself is left alone.
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil {
            WeightUnit.overrideForTesting = .pounds
        }
        #endif

        #if DEBUG && targetEnvironment(simulator)
        // UI-test hook: the unit choices are cleared before any view reads
        // them. The history itself is seeded below, once the store exists.
        if UITestSupport.wantsPoundHistory {
            UITestSupport.resetUnitChoices()
        }
        #endif

        // The model container is the only dependency required before the
        // first scene. Feature managers initialize lazily with their views.
        self.dataManager = DataManager.shared

        #if DEBUG && targetEnvironment(simulator)
        if UITestSupport.wantsPoundHistory {
            UITestSupport.seedPoundHistory(using: dataManager)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if dataManager.hasPersistenceFailure {
                    StorageUnavailableView()
                } else if hasCompletedOnboarding {
                    ContentView()
                } else {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                }
            }
            .task {
                FunnelAnalytics.shared.trackInstallIfNeeded(
                    hasCompletedOnboarding: hasCompletedOnboarding
                )
                // A rest alert scheduled before the app was closed belongs
                // to a countdown that no longer exists.
                RestAlertManager.shared.cancelRestEnd()
            }
        }
        .modelContainer(dataManager.getSharedModelContainer())
    }
}
