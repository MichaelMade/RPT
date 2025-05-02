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
                        if workoutStateManager.wasAnyWorkoutDiscarded() {
                            // If a workout was ever discarded, force creating a new one
                            viewModel.startNewWorkout()
                            // Reset discard state
                            workoutStateManager.clearDiscardedState()
                            // Set new workout
                            activeWorkoutBinding = viewModel.currentWorkout
                            
                            // Also show the sheet
                            DispatchQueue.main.async {
                                showActiveWorkoutSheet = true
                            }
                        } else if activeWorkoutBinding != nil {
                            // Normal continue flow when we have an active workout
                            showActiveWorkoutSheet = true
                            
                            // Add an async call to ensure it happens
                            DispatchQueue.main.async {
                                showActiveWorkoutSheet = true
                            }
                        } else {
                            // Normal new workout flow
                            viewModel.startNewWorkout()
                            activeWorkoutBinding = viewModel.currentWorkout
                            
                            // Also show the sheet
                            DispatchQueue.main.async {
                                showActiveWorkoutSheet = true
                            }
                        }
                    }) {
                        HStack {
                            // Check for active workout but not if it was discarded
                            let canContinueWorkout = activeWorkoutBinding != nil && 
                                                    !workoutStateManager.wasAnyWorkoutDiscarded()
                            
                            // Use the appropriate icon and text based on whether we can continue
                            Image(systemName: canContinueWorkout ? "arrow.clockwise.circle.fill" : "plus.circle.fill")
                                .font(.title2)
                            
                            Text(canContinueWorkout ? "Continue Workout" : "Start New Workout")
                                .font(.headline)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(activeWorkoutBinding != nil && 
                                    !workoutStateManager.wasAnyWorkoutDiscarded() ? 
                                     Color.green : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        showingRPTCalculator = true
                    }) {
                        HStack {
                            Image(systemName: "function")
                                .font(.title2)
                            
                            Text("RPT Calculator")
                                .font(.headline)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
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
            .navigationDestination(item: $selectedWorkout) { workout in
                WorkoutDetailView(workout: workout)
            }
            .onAppear {
                // Reload data from workout manager, including any incomplete workouts
                viewModel.loadRecentWorkouts()
                
                // Debug to help understand state
                print("HomeView appear - activeWorkoutBinding: \(activeWorkoutBinding != nil)")
                print("HomeView appear - currentWorkout: \(viewModel.currentWorkout != nil)")
                print("HomeView appear - wasDiscarded: \(workoutStateManager.wasAnyWorkoutDiscarded())")
                
                if workoutStateManager.wasAnyWorkoutDiscarded() {
                    
                    // Don't allow showing the sheet while navigating back to this view
                    DispatchQueue.main.async {
                        // Double check
                        activeWorkoutBinding = nil
                        showActiveWorkoutSheet = false
                    }
                } 
                // Handle the case where we have a current workout in the ViewModel but no active binding
                else if viewModel.currentWorkout != nil {
                    // This ensures "Continue Workout" shows properly when returning to HomeView
                    activeWorkoutBinding = viewModel.currentWorkout
                    
                    // Debug
                    print("HomeView - Setting activeWorkoutBinding from currentWorkout: \(viewModel.currentWorkout?.name ?? "unnamed")")
                }
                
                // Final debug check
                print("HomeView after checks - activeWorkoutBinding: \(activeWorkoutBinding != nil)")
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
    let modelContainer = try! ModelContainer(for: Workout.self, ExerciseSet.self, Exercise.self)
    let workout = Workout(date: Date(), name: "Active Workout")
    
    NavigationStack {
        HomeView(
            activeWorkoutBinding: .constant(workout),
            showActiveWorkoutSheet: .constant(false)
        )
        .modelContainer(modelContainer)
    }
}
