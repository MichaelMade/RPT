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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Workout summary card
                VStack(alignment: .leading, spacing: 8) {
                    // Date
                    HStack {
                        Text(workout.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
                ForEach(workout.orderedExerciseGroups, id: \.exercise) { group in
                    ExerciseSection(
                        exercise: group.exercise,
                        sets: group.sets
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let modelContainer = try! ModelContainer(for: Workout.self, ExerciseSet.self, Exercise.self)
    
    // Create a sample workout for the preview
    let workout = Workout(date: Date(), name: "Chest Day")
    let benchPress = Exercise(
        name: "Bench Press",
        category: .compound,
        primaryMuscleGroups: [.chest],
        secondaryMuscleGroups: [.triceps, .shoulders]
    )
    
    // Add some sets
    let set1 = ExerciseSet(weight: 225, reps: 5, exercise: benchPress, workout: workout)
    let set2 = ExerciseSet(weight: 205, reps: 7, exercise: benchPress, workout: workout)
    let set3 = ExerciseSet(weight: 185, reps: 9, exercise: benchPress, workout: workout)
    workout.sets.append(contentsOf: [set1, set2, set3])
    
    // Complete the workout
    workout.complete()
    
    return NavigationStack {
        WorkoutDetailView(workout: workout)
    }
    .modelContainer(modelContainer)
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
                .padding(.leading, 8)
            
            
            // Sets
            VStack(spacing: 6) {
                ForEach(sets.indices, id: \.self) { index in
                    let set = sets[index]
                    
                    HStack {
                        Text("Set \(index + 1)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(set.weight) lb × \(set.reps) reps")
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
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}
