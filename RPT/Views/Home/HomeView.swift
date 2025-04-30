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
                        if let _ = activeWorkoutBinding {
                            // If there's an active workout, show it
                            showActiveWorkoutSheet = true
                        } else {
                            // Create a new workout
                            viewModel.startNewWorkout()
                            // Set it as the active workout which will trigger the sheet
                            activeWorkoutBinding = viewModel.currentWorkout
                        }
                    }) {
                        HStack {
                            Image(systemName: activeWorkoutBinding != nil ? "arrow.clockwise.circle.fill" : "plus.circle.fill")
                                .font(.title2)
                            
                            Text(activeWorkoutBinding != nil ? "Continue Workout" : "Start New Workout")
                                .font(.headline)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(activeWorkoutBinding != nil ? Color.green : Color.blue)
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
                viewModel.loadRecentWorkouts()
                
                // If we have a newly created workout, set it as active
                if let workout = viewModel.currentWorkout, activeWorkoutBinding == nil {
                    activeWorkoutBinding = workout
                }
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
