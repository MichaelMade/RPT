//
//  WorkoutDetailView.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let workout: Workout
    private let workoutManager = WorkoutManager.shared
    
    @State private var exerciseGroups: [Exercise: [ExerciseSet]] = [:]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Workout summary card
                VStack(alignment: .leading, spacing: 8) {
                    // Date and duration
                    HStack {
                        Text(workout.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if workout.duration > 0 {
                            Text(formatDuration(workout.duration))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Workout stats
                    HStack(spacing: 16) {
                        StatBox(
                            title: "Exercises",
                            value: "\(workout.exerciseCount)"
                        )
                        
                        StatBox(
                            title: "Sets",
                            value: "\(workout.workingSetsCount)"
                        )
                        
                        StatBox(
                            title: "Volume",
                            value: workout.formattedTotalVolume()
                        )
                    }
                    .padding(.vertical, 8)
                    
                    // Notes
                    if !workout.notes.isEmpty {
                        Text("Notes")
                            .font(.headline)
                            .padding(.top, 4)
                        
                        Text(workout.notes)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Exercise sections
                ForEach(Array(exerciseGroups.keys.sorted(by: { $0.name < $1.name })), id: \.self) { exercise in
                    if let sets = exerciseGroups[exercise] {
                        ExerciseSection(
                            exercise: exercise,
                            sets: sets.sorted(by: { $0.completedAt < $1.completedAt })
                        )
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Load exercise groups when view appears
            exerciseGroups = workout.exerciseGroups
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%d sec", seconds)
        }
    }
}

// Stats box for summary
struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

// Exercise section component
struct ExerciseSection: View {
    let exercise: Exercise
    let sets: [ExerciseSet]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Exercise header
            Text(exercise.name)
                .font(.headline)
            
            // Sets
            VStack(spacing: 6) {
                ForEach(sets.indices, id: \.self) { index in
                    let set = sets[index]
                    
                    HStack {
                        Text("Set \(index + 1)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(set.weight, specifier: "%.1f") lb × \(set.reps) reps")
                            .font(.subheadline)
                        
                        if let rpe = set.rpe {
                            Text("RPE: \(rpe)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(set.isWarmup ? Color.yellow.opacity(0.1) : Color.clear)
                    .cornerRadius(6)
                }
            }
            .padding(12)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(8)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}
