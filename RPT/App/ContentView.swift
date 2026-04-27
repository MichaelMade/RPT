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
                        guard let workout = activeWorkout else { return nil }
                        return shouldResumeIncompleteWorkout(for: workout) ? workout : nil
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
                        if let workout = activeWorkout, !shouldResumeIncompleteWorkout(for: workout) {
                            return false
                        }
                        return showingActiveWorkoutSheet
                    },
                    set: { newValue in
                        if newValue, let workout = activeWorkout, !shouldResumeIncompleteWorkout(for: workout) {
                            showingActiveWorkoutSheet = false
                        } else {
                            showingActiveWorkoutSheet = newValue
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
            
            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .tag(2)

            TemplatesListView(
                activeWorkoutBinding: Binding(
                    get: {
                        guard let workout = activeWorkout else { return nil }
                        return shouldResumeIncompleteWorkout(for: workout) ? workout : nil
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
                        if let workout = activeWorkout, !shouldResumeIncompleteWorkout(for: workout) {
                            return false
                        }
                        return showingActiveWorkoutSheet
                    },
                    set: { newValue in
                        if newValue, let workout = activeWorkout, !shouldResumeIncompleteWorkout(for: workout) {
                            showingActiveWorkoutSheet = false
                        } else {
                            showingActiveWorkoutSheet = newValue
                        }
                    }
                )
            )
            .tabItem {
                Label("Templates", systemImage: "doc.text")
            }
            .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .fullScreenCover(isPresented: $showingActiveWorkoutSheet) {
            if let workout = activeWorkout {
                ActiveWorkoutView(
                    workout: workout,
                    showCustomBackButton: false,
                    onCompleteWorkout: {
                        if workoutStateManager.wasAnyWorkoutDiscarded() {
                            activeWorkout = nil
                        }
                        showingActiveWorkoutSheet = false
                    }
                )
            } else {
                Text("No active workout")
                    .onAppear { showingActiveWorkoutSheet = false }
            }
        }
        .onChange(of: activeWorkout) { oldValue, newValue in
            if newValue != nil && oldValue == nil && !workoutStateManager.wasAnyWorkoutDiscarded() {
                workoutStateManager.clearDiscardedState()
                showingActiveWorkoutSheet = true
            } else if newValue == nil && oldValue != nil {
                if let workout = oldValue {
                    workoutStateManager.markWorkoutAsDiscarded(workout.id)
                }
                showingActiveWorkoutSheet = false
            }
        }
        .onChange(of: selectedTab) { _, _ in
            restoreResumableWorkoutIfAvailable()
        }
        // Initial setup when ContentView appears
        .onAppear {
            restoreResumableWorkoutIfAvailable()
        }
        .onChange(of: workoutStateManager.workoutWasDiscarded) { _, isDiscarded in
            if isDiscarded {
                showingActiveWorkoutSheet = false
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

    private func shouldResumeIncompleteWorkout(for workout: Workout) -> Bool {
        guard !workout.isCompleted else {
            return false
        }

        let wasAnyWorkoutDiscarded = workoutStateManager.wasAnyWorkoutDiscarded()

        guard wasAnyWorkoutDiscarded else {
            return true
        }

        guard let discardTimestamp = workoutStateManager.discardTimestamp else {
            // Fail open for legacy/corrupted discard state.
            return true
        }

        return workout.date >= discardTimestamp
    }

    private func restoreResumableWorkoutIfAvailable() {
        guard activeWorkout == nil else {
            if let workout = activeWorkout, !shouldResumeIncompleteWorkout(for: workout) {
                showingActiveWorkoutSheet = false

                // Keep completed workouts in local state so we don't accidentally
                // mark them as discarded through the activeWorkout onChange path.
                if !workout.isCompleted {
                    activeWorkout = nil
                }
            }
            return
        }

        guard let lastIncomplete = WorkoutManager.shared.getIncompleteWorkouts().first else {
            return
        }

        if shouldResumeIncompleteWorkout(for: lastIncomplete) {
            activeWorkout = lastIncomplete
        } else {
            showingActiveWorkoutSheet = false
            activeWorkout = nil
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Exercise.self, Workout.self, ExerciseSet.self, WorkoutTemplate.self, UserSettings.self, User.self])
        .environmentObject(SettingsManager.shared)
}
