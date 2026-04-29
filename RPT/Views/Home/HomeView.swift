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
                    VStack(alignment: .leading, spacing: 10) {
                        let resumableWorkout = viewModel.resumableWorkout(activeWorkout: activeWorkoutBinding)
                        let canContinueWorkout = resumableWorkout != nil

                        Button(action: {
                            if let resumableWorkout {
                                activeWorkoutBinding = resumableWorkout
                            } else {
                                viewModel.startNewWorkout()
                                workoutStateManager.clearDiscardedState()
                                activeWorkoutBinding = viewModel.currentWorkout
                            }

                            showActiveWorkoutSheet = true
                        }) {
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

                        if let resumableWorkout {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.green)
                                    .font(.subheadline)
                                    .padding(.top, 1)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(WorkoutRow.displayName(for: resumableWorkout))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    Text(viewModel.resumableWorkoutSummary(for: resumableWorkout))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
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

                    if let stats = viewModel.userStats {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Progress Snapshot")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)

                            if stats.totalWorkouts > 0 {
                                let weeklyWorkoutCount = viewModel.weeklyWorkoutCount()
                                let weeklyProgress = viewModel.weeklyProgress(forWorkoutCount: weeklyWorkoutCount)

                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 12) {
                                        HomeStatTile(
                                            icon: "figure.strengthtraining.traditional",
                                            title: "Workouts",
                                            value: "\(stats.totalWorkouts)",
                                            subtitle: "logged",
                                            tint: .blue
                                        )

                                        HomeStatTile(
                                            icon: "scalemass",
                                            title: "Volume",
                                            value: viewModel.formatTotalVolume(),
                                            subtitle: "lb lifted",
                                            tint: .purple
                                        )

                                        HomeStatTile(
                                            icon: "flame.fill",
                                            title: "Streak",
                                            value: "\(stats.workoutStreak)",
                                            subtitle: stats.workoutStreak == 1 ? "day" : "days",
                                            tint: .orange
                                        )
                                    }

                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(alignment: .firstTextBaseline) {
                                            Text("Last 7 Days")
                                                .font(.headline)

                                            Spacer()

                                            Text(viewModel.weeklyProgressSummary(forWorkoutCount: weeklyWorkoutCount))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.secondary)
                                        }

                                        ProgressView(value: weeklyProgress)
                                            .tint(.green)

                                        Text(viewModel.weeklyProgressSubtitle(forWorkoutCount: weeklyWorkoutCount))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal)
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.title3)
                                            .foregroundColor(.blue)

                                        Text("No workouts logged yet")
                                            .font(.headline)
                                    }

                                    Text("Finish your first workout to start a streak and unlock lifetime progress on Home.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                    }

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
private struct HomeStatTile: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(tint)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
            }

            Text(value)
                .font(.title3.monospacedDigit())
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

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
