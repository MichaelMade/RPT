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
