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

        // Initialize data manager first
        _ = DataManager.shared
        
        // Then initialize all other managers
        _ = UserManager.shared
        _ = SettingsManager.shared
        _ = ExerciseManager.shared
        _ = TemplateManager.shared
        _ = WorkoutManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        // Use DataManager's modelContainer for the SwiftUI environment
        .modelContainer(DataManager.shared.getSharedModelContainer())
    }
}
