//
//  HomeView.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var showingRPTCalculator = false
    @State private var showingPlateCalculator = false
    @State private var selectedWorkout: Workout?
    @StateObject private var workoutStateManager = WorkoutStateManager.shared
    
    // Bindings for active workout
    @Binding var activeWorkoutBinding: Workout?
    @Binding var showActiveWorkoutSheet: Bool
    
    // Default initializer with empty bindings for previews
    init() {
        self._activeWorkoutBinding = .constant(nil)
        self._showActiveWorkoutSheet = .constant(false)
    }
    
    // Custom initializer with bindings
    init(activeWorkoutBinding: Binding<Workout?>, showActiveWorkoutSheet: Binding<Bool>) {
        self._activeWorkoutBinding = activeWorkoutBinding
        self._showActiveWorkoutSheet = showActiveWorkoutSheet
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with welcome message
                    VStack(alignment: .leading) {
                        Text("RPT Trainer")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Start your reverse pyramid training session")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Start/Continue workout button
                    Button(action: {
                        let resumableWorkout = viewModel.resumableWorkout(activeWorkout: activeWorkoutBinding)

                        if let resumableWorkout {
                            activeWorkoutBinding = resumableWorkout
                        } else {
                            viewModel.startNewWorkout()
                            workoutStateManager.clearDiscardedState()
                            activeWorkoutBinding = viewModel.currentWorkout
                        }

                        showActiveWorkoutSheet = true
                    }) {
                        let canContinueWorkout = viewModel.canContinueWorkout(activeWorkout: activeWorkoutBinding)

                        HStack {
                            Image(systemName: canContinueWorkout ? "arrow.clockwise.circle.fill" : "plus.circle.fill")
                                .font(.title2)

                            Text(canContinueWorkout ? "Continue Workout" : "Start New Workout")
                                .font(.headline)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(canContinueWorkout ? Color.green : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        Button(action: { showingRPTCalculator = true }) {
                            VStack(spacing: 6) {
                                Image(systemName: "function")
                                    .font(.title2)
                                Text("RPT Calculator")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        Button(action: { showingPlateCalculator = true }) {
                            VStack(spacing: 6) {
                                Image(systemName: "scalemass")
                                    .font(.title2)
                                Text("Plate Calculator")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.indigo)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    // Recent workouts section
                    if !viewModel.recentWorkouts.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Recent Workouts")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ForEach(viewModel.recentWorkouts) { workout in
                                Button(action: {
                                    selectedWorkout = workout
                                }) {
                                    WorkoutRow(workout: workout)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .sheet(isPresented: $showingRPTCalculator) {
                RPTCalculatorView()
            }
            .sheet(isPresented: $showingPlateCalculator) {
                PlateCalculatorView()
            }
            .navigationDestination(item: $selectedWorkout) { workout in
                WorkoutDetailView(workout: workout)
            }
            .onAppear {
                viewModel.loadRecentWorkouts()
                activeWorkoutBinding = viewModel.currentWorkout
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .modelContainer(for: [Exercise.self, Workout.self, ExerciseSet.self, WorkoutTemplate.self, UserSettings.self, User.self])
    }
}

// Preview with active workout
#Preview("With Active Workout") {
    let workout = Workout(date: Date(), name: "Active Workout")
    return NavigationStack {
        HomeView(
            activeWorkoutBinding: .constant(workout),
            showActiveWorkoutSheet: .constant(false)
        )
        .modelContainer(for: [Workout.self, ExerciseSet.self, Exercise.self])
    }
}
