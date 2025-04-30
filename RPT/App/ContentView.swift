//
//  ContentView.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var settingsManager = SettingsManager.shared
    
    // Track active workout
    @State private var activeWorkout: Workout?
    @State private var showingActiveWorkoutSheet = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                activeWorkoutBinding: $activeWorkout,
                showActiveWorkoutSheet: $showingActiveWorkoutSheet
            )
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)
            
            ExercisesView()
                .tabItem {
                    Label("Exercises", systemImage: "figure.strengthtraining.traditional")
                }
                .tag(1)
            
            TemplatesListView(
                activeWorkoutBinding: $activeWorkout,
                showActiveWorkoutSheet: $showingActiveWorkoutSheet
            )
            .tabItem {
                Label("Templates", systemImage: "doc.text")
            }
            .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .fullScreenCover(isPresented: $showingActiveWorkoutSheet) {
            if let workout = activeWorkout {
                ActiveWorkoutView(
                    workout: workout,
                    showCustomBackButton: false,
                    onCompleteWorkout: {
                        // Clear the active workout when completed
                        activeWorkout = nil
                        showingActiveWorkoutSheet = false
                        
                        // Ensure the Home tab is selected when returning
                        selectedTab = 0
                    }
                )
            }
        }
        .onChange(of: activeWorkout) { oldValue, newValue in
            // Show the active workout sheet automatically when a workout becomes active
            if newValue != nil && oldValue == nil {
                showingActiveWorkoutSheet = true
            }
            
            // If the active workout becomes nil, make sure the sheet is dismissed
            if newValue == nil && showingActiveWorkoutSheet {
                showingActiveWorkoutSheet = false
                
                // Navigate to home view when workout is completed or discarded
                selectedTab = 0
            }
        }
        .preferredColorScheme(colorSchemeForPreference(settingsManager.settings.darkModePreference))
    }
    
    private func colorSchemeForPreference(_ preference: DarkModePreference) -> ColorScheme? {
        switch preference {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Exercise.self, Workout.self, ExerciseSet.self, WorkoutTemplate.self, UserSettings.self, User.self])
        .environmentObject(SettingsManager.shared)
}
