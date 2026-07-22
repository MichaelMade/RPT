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
    @AppStorage("selectedRootTab") private var selectedRootTabRawValue = RootTab.home.rawValue

    var body: some View {
        if settingsManager.initializationFailureDescription != nil {
            StorageUnavailableView()
        } else {
            tabShell
        }
    }

    private var tabShell: some View {
        TabView(selection: selectedRootTabBinding) {
            HomeView()
                .tag(RootTab.home)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            TemplatesListView()
                .tag(RootTab.templates)
                .tabItem {
                    Label("Templates", systemImage: "square.grid.2x2.fill")
                }

            ExercisesView()
                .tag(RootTab.exercises)
                .tabItem {
                    Label("Exercises", systemImage: "figure.strengthtraining.traditional")
                }

            StatsView()
                .tag(RootTab.stats)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tag(RootTab.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .environmentObject(session)
        .tint(Theme.primary)
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
            session.rearmPresentationAfterRootSwap()
        }
        .task {
            await StoreKitPurchaseManager.shared.prepareEntitlements()
        }
        .preferredColorScheme(colorScheme(for: settingsManager.darkModePreference))
        #if DEBUG
        .overlay(alignment: .topLeading) {
            AppearanceProbe()
        }
        #endif
    }

    private func colorScheme(for preference: DarkModePreference) -> ColorScheme? {
        switch preference {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    private var selectedRootTabBinding: Binding<RootTab> {
        Binding(
            get: { RootTab(rawValue: selectedRootTabRawValue) ?? .home },
            set: { selectedRootTabRawValue = $0.rawValue }
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Exercise.self, Workout.self, ExerciseSet.self, WorkoutTemplate.self, UserSettings.self, User.self])
        .environmentObject(SettingsManager.shared)
}
