//
//  ExerciseSectionView.swift
//  RPT
//
//  Created by Michael Moore on 5/2/25.
//

import SwiftUI
import SwiftData

struct ExerciseSectionView: View {
    @ObservedObject var viewModel: ActiveWorkoutViewModel
    let exercise: Exercise
    let sets: [ExerciseSet]
    
    // We now use the viewModel properties for delete confirmation
    
    var body: some View {
        Section {
            // Exercise header with the new component
            ExerciseHeaderView(
                exercise: exercise,
                isCompleted: viewModel.isExerciseCompleted(exercise),
                onDelete: {
                    viewModel.exerciseToDelete = exercise
                    viewModel.showingDeleteExerciseConfirmation = true
                },
                onToggleCompletion: {
                    viewModel.toggleExerciseCompletion(exercise)
                },
                onToggleDetails: {
                    viewModel.toggleExerciseExpansion(exercise)
                }
            )
            
            // Only show sets if the exercise is expanded
            if viewModel.expandedExercises.contains(exercise.id) {
                // Sort sets by completion date to maintain set order
                ForEach(sets.sorted(by: { $0.completedAt < $1.completedAt }), id: \.id) { set in
                    ExerciseSetRowView(
                        set: set,
                        isFirstSet: sets.firstIndex(where: { $0.id == set.id }) == 0, // Determine if this is the first set
                        onUpdate: { weight, reps, rpe in
                            // Weight is already an int and we expect it to be rounded to the nearest 5
                            _ = viewModel.updateSetSafely(set, weight: weight, reps: reps, rpe: rpe)
                        },
                        onDelete: {
                            _ = viewModel.deleteSetSafely(set)
                        },
                        onStartRestTimer: {
                            viewModel.startRestTimer()
                        },
                        onUpdateDropSets: { firstSetWeight in
                            // If this is the first set, update subsequent sets based on RPT drops
                            let sortedSets = sets.sorted(by: { $0.completedAt < $1.completedAt })
                            updateDropSets(exercise: exercise, firstSetWeight: firstSetWeight, sets: sortedSets)
                        }
                    )
                }
                
                // Add set button
                Button(action: {
                    _ = viewModel.addSetToExerciseSafely(exercise)
                }) {
                    Label("Add Set", systemImage: "plus.circle")
                        .foregroundColor(exercise.category.style.color)
                }
                .padding(.vertical, 4)
            }
        }
        // Dialog moved to the parent view to avoid duplication
    }
    
    // Method to update drop sets based on first set weight - updated to round to nearest 5 pounds
    private func updateDropSets(exercise: Exercise, firstSetWeight: Int, sets: [ExerciseSet]) {
        // Only update if there are multiple sets
        guard sets.count > 1 else { return }
        
        // Get settings manager to access drop percentages
        let settingsManager = SettingsManager.shared
        let dropPercentages = settingsManager.settings.defaultRPTPercentageDrops
        let workoutManager = WorkoutManager.shared
        
        // Update each subsequent set based on the drop percentages
        for index in 1..<min(sets.count, dropPercentages.count) {
            if let dropPercentage = dropPercentages[safe: index] {
                let calculatedWeight = Double(firstSetWeight) * (1.0 - dropPercentage)
                
                // Round to nearest 5 pounds for practical weight values in the gym
                let roundedWeight = workoutManager.roundToNearest5(calculatedWeight)
                
                // Update the set
                _ = viewModel.updateSetSafely(
                    sets[index],
                    weight: roundedWeight,
                    reps: sets[index].reps,
                    rpe: sets[index].rpe
                )
            }
        }
    }
}

#Preview {
    // Create a model container for previews
    let modelContainer = try! ModelContainer(for: Exercise.self, ExerciseSet.self, Workout.self)
    
    // Create a mock exercise
    let benchPress = Exercise(
        name: "Bench Press",
        category: .compound,
        primaryMuscleGroups: [.chest],
        secondaryMuscleGroups: [.triceps, .shoulders]
    )
    
    // Create mock workout
    let workout = Workout(date: Date(), name: "Chest Day")
    
    // Create mock sets
    let set1 = ExerciseSet(weight: 225, reps: 5, exercise: benchPress, workout: workout)
    let set2 = ExerciseSet(weight: 200, reps: 8, exercise: benchPress, workout: workout)
    let set3 = ExerciseSet(weight: 185, reps: 10, exercise: benchPress, workout: workout, rpe: 8)
    
    // Create a mock viewModel
    let viewModel = ActiveWorkoutViewModel(workout: workout)
    
    // Add the exercise to the expanded set
    viewModel.expandedExercises.insert(benchPress.id)
    
    // Apply sorting to the sets for proper preview
    let sortedSets = [set1, set2, set3].sorted(by: { $0.completedAt < $1.completedAt })
    
    return List {
        ExerciseSectionView(
            viewModel: viewModel,
            exercise: benchPress,
            sets: sortedSets
        )
    }
    .listStyle(.insetGrouped)
    .modelContainer(modelContainer)
}