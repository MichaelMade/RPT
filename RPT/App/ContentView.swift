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
    @StateObject private var workoutStateManager = WorkoutStateManager.shared
    
    // Track active workout
    @State private var activeWorkout: Workout?
    @State private var showingActiveWorkoutSheet = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                activeWorkoutBinding: Binding(
                    get: { 
                        // If a workout was discarded, don't show it
                        if workoutStateManager.wasAnyWorkoutDiscarded() {
                            return nil
                        }
                        return activeWorkout
                    },
                    set: { newWorkout in
                        if newWorkout != nil {
                            // Setting a new workout - clear any discard state
                            workoutStateManager.clearDiscardedState()
                            activeWorkout = newWorkout
                        } else if activeWorkout != nil {
                            // Setting to nil - mark as discarded
                            if let workout = activeWorkout {
                                workoutStateManager.markWorkoutAsDiscarded(workout.id)
                            }
                            activeWorkout = nil
                        }
                    }
                ),
                showActiveWorkoutSheet: Binding(
                    get: { 
                        // Don't show sheet if workout was discarded
                        return !workoutStateManager.wasAnyWorkoutDiscarded() && showingActiveWorkoutSheet
                    },
                    set: { newValue in
                        if workoutStateManager.wasAnyWorkoutDiscarded() && newValue == true {
                            // Block showing the sheet if workout was discarded
                            showingActiveWorkoutSheet = false
                        } else {
                            showingActiveWorkoutSheet = newValue
                            
                            // Force update sheet presentation with a slight delay to overcome race conditions
                            if newValue == true {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showingActiveWorkoutSheet = true
                                }
                            }
                        }
                    }
                )
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
                activeWorkoutBinding: Binding(
                    get: { 
                        // If a workout was discarded, don't show it
                        if workoutStateManager.wasAnyWorkoutDiscarded() {
                            return nil
                        }
                        return activeWorkout
                    },
                    set: { newWorkout in
                        if newWorkout != nil {
                            // Setting a new workout - clear any discard state
                            workoutStateManager.clearDiscardedState()
                            activeWorkout = newWorkout
                        } else if activeWorkout != nil {
                            // Setting to nil - mark as discarded
                            if let workout = activeWorkout {
                                workoutStateManager.markWorkoutAsDiscarded(workout.id)
                            }
                            activeWorkout = nil
                        }
                    }
                ),
                showActiveWorkoutSheet: Binding(
                    get: { 
                        // Don't show sheet if workout was discarded
                        return !workoutStateManager.wasAnyWorkoutDiscarded() && showingActiveWorkoutSheet
                    },
                    set: { newValue in
                        if workoutStateManager.wasAnyWorkoutDiscarded() && newValue == true {
                            // Block showing the sheet if workout was discarded
                            showingActiveWorkoutSheet = false
                        } else {
                            showingActiveWorkoutSheet = newValue
                            
                            // Force update sheet presentation with a slight delay to overcome race conditions
                            if newValue == true {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showingActiveWorkoutSheet = true
                                }
                            }
                        }
                    }
                )
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
                        // If we've already marked it as saved in the ActiveWorkoutView,
                        // the workout state manager will know that. Otherwise assume discard.
                        if !workoutStateManager.wasAnyWorkoutDiscarded() {
                            // The workout was saved, not discarded - keep the reference but close sheet
                            showingActiveWorkoutSheet = false
                        } else {
                            // Mark the workout as discarded in our state manager
                            if let workout = activeWorkout {
                                workoutStateManager.markWorkoutAsDiscarded(workout.id)
                            }
                            
                            // Clear workout state immediately for discarded workouts
                            activeWorkout = nil 
                            showingActiveWorkoutSheet = false
                            
                            // Add an async update to be extra safe
                            DispatchQueue.main.async {
                                // Force another reset
                                showingActiveWorkoutSheet = false
                                if workoutStateManager.wasAnyWorkoutDiscarded() {
                                    activeWorkout = nil
                                }
                            }
                        }
                    }
                )
            } else {
                // Defensive programming - if there's no active workout, dismiss the sheet
                Text("No active workout")
                    .onAppear {
                        showingActiveWorkoutSheet = false
                    }
            }
        }
        .onChange(of: activeWorkout) { oldValue, newValue in
            // Reset the discarded flag whenever a brand new workout is started
            if newValue != nil && oldValue == nil && !workoutStateManager.wasAnyWorkoutDiscarded() {
                // Only show the sheet if the workout wasn't recently discarded
                workoutStateManager.clearDiscardedState()
                showingActiveWorkoutSheet = true
            } else if newValue == nil && oldValue != nil {
                // Workout was completed or discarded - hide sheet
                if let workout = oldValue {
                    workoutStateManager.markWorkoutAsDiscarded(workout.id)
                }
                showingActiveWorkoutSheet = false
                
                // Removed automatic navigation to home tab
                
                // Forcefully update on next run loop to ensure changes are applied
                DispatchQueue.main.async {
                    showingActiveWorkoutSheet = false
                }
            }
        }
        // Handle tab changes for workout state management
        .onChange(of: selectedTab) { _, _ in
            // If a workout was ever discarded, make sure the sheet stays dismissed
            if workoutStateManager.wasAnyWorkoutDiscarded() {
                showingActiveWorkoutSheet = false
                
                // Update on next run loop for extra safety
                DispatchQueue.main.async {
                    showingActiveWorkoutSheet = false
                }
            }
            // Check for incomplete workouts when changing tabs if no workout is being tracked
            else if activeWorkout == nil && !workoutStateManager.wasAnyWorkoutDiscarded() {
                // Load any incomplete workout from the database 
                let incompleteWorkouts = WorkoutManager.shared.getIncompleteWorkouts()
                
                if let lastIncomplete = incompleteWorkouts.first {
                    // Set as active workout so it can be continued
                    activeWorkout = lastIncomplete
                }
            }
        }
        // Initial setup when ContentView appears
        .onAppear {
            // If a workout was discarded, make sure the sheet stays closed
            if workoutStateManager.wasAnyWorkoutDiscarded() {
                showingActiveWorkoutSheet = false
                activeWorkout = nil
            } 
            // Check for incomplete workouts on app start if no workout is being tracked
            else if activeWorkout == nil {
                // Load any incomplete workout from the database
                let incompleteWorkouts = WorkoutManager.shared.getIncompleteWorkouts()
                
                if let lastIncomplete = incompleteWorkouts.first {
                    // Set as active workout so it can be continued
                    activeWorkout = lastIncomplete
                }
            }
            
            // Timer to continuously enforce the discarded state
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                // If a workout was discarded but the sheet is shown, forcibly close it
                if workoutStateManager.wasAnyWorkoutDiscarded() && showingActiveWorkoutSheet {
                    showingActiveWorkoutSheet = false
                }
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
