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

    private let summaryColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    static func displayName(for workout: Workout) -> String {
        let collapsedName = workout.name
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedName.isEmpty else {
            return "Workout"
        }

        return String(collapsedName.prefix(80))
    }

    static func displayExerciseName(_ exercise: Exercise) -> String {
        let collapsedName = exercise.name
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedName.isEmpty else {
            return "Exercise"
        }

        return String(collapsedName.prefix(80))
    }

    static func displayExerciseCount(for workout: Workout) -> Int {
        let completedExercises = Set(
            workout.sets
                .filter(\.isCompletedWorkingSet)
                .compactMap { $0.exercise }
        ).count

        return completedExercises > 0 ? completedExercises : workout.exerciseCount
    }

    static func displaySetCount(for workout: Workout) -> Int {
        let completedSetCount = workout.workingSetsCount
        if completedSetCount > 0 {
            return completedSetCount
        }

        let nonWarmupSetCount = workout.sets.filter { !$0.isWarmup }.count
        if nonWarmupSetCount > 0 {
            return nonWarmupSetCount
        }

        return workout.sets.count
    }

    static func summaryMetrics(for workout: Workout) -> [(title: String, value: String)] {
        var metrics: [(title: String, value: String)] = [
            (title: "Exercises", value: "\(displayExerciseCount(for: workout))"),
            (title: "Sets", value: "\(displaySetCount(for: workout))"),
            (title: workout.preferredWorkMetricTitle, value: workout.preferredWorkMetricValue)
        ]

        if workout.totalVolume > 0, workout.totalBodyweightReps > 0 {
            metrics.append((title: "Bodyweight Reps", value: workout.formattedTotalBodyweightReps()))
        }

        let safeDuration = workout.duration.isFinite ? max(0, workout.duration) : 0
        if workout.isCompleted, safeDuration > 0 {
            metrics.append((title: "Duration", value: workout.formattedDurationForSummary()))
        }

        return metrics
    }

    static func normalizedNotes(for workout: Workout) -> String? {
        let collapsedNotes = workout.notes
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedNotes.isEmpty else {
            return nil
        }

        return collapsedNotes
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Workout summary card
                VStack(alignment: .leading, spacing: 8) {
                    // Date
                    HStack {
                        Text(WorkoutRow.relativeDateText(for: workout.date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Workout stats
                    LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 12) {
                        ForEach(Self.summaryMetrics(for: workout), id: \.title) { metric in
                            StatBox(
                                title: metric.title,
                                value: metric.value
                            )
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Notes
                    if let normalizedNotes = Self.normalizedNotes(for: workout) {
                        Text("Notes")
                            .font(.headline)
                            .padding(.top, 4)
                        
                        Text(normalizedNotes)
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
        .navigationTitle(Self.displayName(for: workout))
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

    static func setDisplayText(for set: ExerciseSet) -> String {
        set.formattedWeightReps
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Exercise header
            Text(WorkoutDetailView.displayExerciseName(exercise))
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
                        
                        Text(Self.setDisplayText(for: set))
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
