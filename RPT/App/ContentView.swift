//
//  ContentView.swift
//  RPT
//
//  Root tab shell. The single in-progress workout is coordinated by
//  WorkoutSession and presented full-screen from here.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var session = WorkoutSession.shared

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            TemplatesListView()
                .tabItem {
                    Label("Templates", systemImage: "square.grid.2x2.fill")
                }

            ExercisesView()
                .tabItem {
                    Label("Exercises", systemImage: "figure.strengthtraining.traditional")
                }

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .environmentObject(session)
        .tint(Theme.accent)
        .fullScreenCover(isPresented: $session.isPresentingWorkout) {
            if let workout = session.activeWorkout {
                ActiveWorkoutView(workout: workout)
                    .environmentObject(session)
            } else {
                // Defensive: never present an empty workout screen.
                Color.clear
                    .onAppear { session.isPresentingWorkout = false }
            }
        }
        .onAppear {
            session.restoreResumableWorkout()
        }
        .preferredColorScheme(colorScheme(for: settingsManager.settings.darkModePreference))
    }

    private func colorScheme(for preference: DarkModePreference) -> ColorScheme? {
        switch preference {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Exercise.self, Workout.self, ExerciseSet.self, WorkoutTemplate.self, UserSettings.self, User.self])
        .environmentObject(SettingsManager.shared)
}
