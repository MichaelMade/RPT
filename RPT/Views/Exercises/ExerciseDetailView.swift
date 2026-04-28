//
//  ExerciseDetailView.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    @Bindable var exercise: Exercise
    @State private var showingEditSheet = false
    @State private var recentHistory: [(workout: Workout, set: ExerciseSet)] = []
    
    private let exerciseManager = ExerciseManager.shared
    private let workoutManager = WorkoutManager.shared

    static func recentHistoryEntries(from history: [(workout: Workout, sets: [ExerciseSet])]) -> [(workout: Workout, set: ExerciseSet)] {
        history
            .compactMap { workout, sets in
                let completedWorkingSets = sets.filter(\.isCompletedWorkingSet)

                guard let bestSet = completedWorkingSets.max(by: { lhs, rhs in
                    rhs.isBetterPerformance(than: lhs)
                }) else {
                    return nil
                }

                return (workout: workout, set: bestSet)
            }
            .sorted { lhs, rhs in
                if lhs.workout.date != rhs.workout.date {
                    return lhs.workout.date > rhs.workout.date
                }

                return lhs.set.completedAt > rhs.set.completedAt
            }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with icon
                HStack(alignment: .center, spacing: 16) {
                    // Exercise icon
                    ExerciseIconView(category: exercise.category, size: 60)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        // Category and custom badge
                        HStack {
                            ExerciseCategoryTag(category: exercise.category)
                            
                            if exercise.isCustom {
                                Text("Custom")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                        }
                        
                        // Main muscles
                        if !exercise.primaryMuscleGroups.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Primary Muscles")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 4) {
                                    ForEach(exercise.primaryMuscleGroups, id: \.self) { muscle in
                                        MuscleGroupTag(muscleGroup: muscle, isPrimary: true)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Secondary muscles
                        if !exercise.secondaryMuscleGroups.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Secondary Muscles")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 4) {
                                    ForEach(exercise.secondaryMuscleGroups, id: \.self) { muscle in
                                        MuscleGroupTag(muscleGroup: muscle, isPrimary: false)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // Instructions
                if !exercise.instructions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "list.bullet.clipboard")
                                .foregroundColor(exercise.category.style.color)
                            
                            Text("Instructions")
                                .font(.headline)
                        }
                        
                        Text(exercise.instructions)
                            .font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                // View progress charts
                NavigationLink(destination: ExerciseProgressView(exercise: exercise)) {
                    HStack {
                        Image(systemName: "chart.xyaxis.line")
                            .foregroundColor(.white)
                        Text("View Progress")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(exercise.category.style.color)
                    .cornerRadius(12)
                }

                // Recent history
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(exercise.category.style.color)

                        Text("Exercise History")
                            .font(.headline)
                    }
                    
                    if recentHistory.isEmpty {
                        Text("No workout history for this exercise")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(Array(recentHistory.prefix(5).enumerated()), id: \.element.set.id) { _, entry in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(WorkoutDetailView.displayName(for: entry.workout))
                                        .font(.subheadline)
                                    
                                    Text(entry.workout.date, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(entry.set.formattedWeightReps)
                                    .font(.headline)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(UIColor.tertiarySystemBackground))
                            )
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(exercise.name)
        .toolbar {
            if exercise.isCustom {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditExerciseView(exercise: exercise)
        }
        .onAppear {
            loadRecentSets()
        }
    }
    
    // Load recent sets for this exercise
    private func loadRecentSets() {
        let history = workoutManager.getWorkoutHistory(for: exercise)
        recentHistory = Self.recentHistoryEntries(from: history)
    }
}
