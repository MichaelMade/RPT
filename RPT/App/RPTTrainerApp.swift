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

        // The model container is the only dependency required before the
        // first scene. Feature managers initialize lazily with their views.
        self.dataManager = DataManager.shared
    }

    var body: some Scene {
        WindowGroup {
            if dataManager.hasPersistenceFailure {
                StorageUnavailableView()
            } else if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .modelContainer(dataManager.getSharedModelContainer())
    }
}
