//
//  ActiveWorkoutViewModel.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class ActiveWorkoutViewModel: ObservableObject {
    @Published var workout: Workout
    @Published var workoutName: String
    @Published var exerciseGroups: [Exercise: [ExerciseSet]] = [:]
    @Published var exerciseOrder: [Exercise] = [] // Track order of exercises
    @Published var showingRestTimer = false
    @Published var currentRestDuration: Int = 90
    @Published var completedExercises: Set<PersistentIdentifier> = [] // Only manually tracked completions
    @Published var expandedExercises: Set<PersistentIdentifier> = Set() // Track which exercises are expanded
    
    private let workoutManager: WorkoutManager
    private let exerciseManager: ExerciseManager
    
    var hasSets: Bool {
        return !workout.sets.isEmpty
    }
    
    // Add computed property to check if all exercises are completed
    var allExercisesCompleted: Bool {
        guard !exerciseOrder.isEmpty else { return false }
        return exerciseOrder.allSatisfy { isExerciseCompleted($0) }
    }
    
    init(workout: Workout, workoutManager: WorkoutManager? = nil, exerciseManager: ExerciseManager? = nil) {
        self.workout = workout
        self.workoutName = workout.name
        self.workoutManager = workoutManager ?? WorkoutManager.shared
        self.exerciseManager = exerciseManager ?? ExerciseManager.shared
        
        // Initialize exercise groups and order
        updateExerciseGroupsAndOrder()
        
        // Populate with previous weights - but fixed to not auto-complete
        populateWithPreviousWeights()
        
        // Initialize all exercises as expanded by default
        for exercise in exerciseOrder {
            expandedExercises.insert(exercise.id)
        }
    }
    
    // Updated method to populate workout with previous weights without affecting completion
    private func populateWithPreviousWeights() {
        // Only run this if the workout was created from a template
        if workout.startedFromTemplate != nil {
            for exercise in exerciseOrder {
                // Get the workout history for this exercise
                let history = workoutManager.getWorkoutHistory(for: exercise)
                
                // If there's previous workout data
                if !history.isEmpty {
                    // Find the most recent workout that has sets with weight > 0
                    let recentWorkouts = history.filter { workout, sets in
                        sets.contains(where: { $0.weight > 0 })
                    }
                    
                    if let mostRecent = recentWorkouts.first {
                        // Get the sets for the most recent workout, ordered by completion time
                        let sortedSets = mostRecent.sets.sorted(by: { $0.completedAt < $1.completedAt })
                        
                        // Get current sets for this exercise in the current workout
                        if let currentSets = exerciseGroups[exercise]?.sorted(by: { $0.completedAt < $1.completedAt }) {
                            // Apply previous weights to the new sets
                            for (index, currentSet) in currentSets.enumerated() {
                                if let previousSet = sortedSets[safe: index] {
                                    // Apply the weight directly to the set
                                    currentSet.weight = previousSet.weight
                                    
                                    // Use the previous reps if currentSet has 0 reps
                                    if currentSet.reps == 0 {
                                        currentSet.reps = previousSet.reps
                                    }
                                    
                                    // Copy RPE if available
                                    currentSet.rpe = previousSet.rpe
                                }
                            }
                        }
                    }
                }
            }
            
            // Save the workout with the weights but no exercises marked as completed
            saveWorkout()
        }
    }
    
    // MARK: - Workout Management
    
    func updateWorkoutName() {
        workout.name = workoutName
        workoutManager.saveWorkout(workout)
    }
    
    func saveWorkout() {
        workoutManager.saveWorkout(workout)
    }
    
    func completeWorkout() {
        workoutManager.completeWorkout(workout)
    }
    
    func discardWorkout() {
        workoutManager.deleteWorkout(workout)
    }
    
    // MARK: - Exercise Management
    
    func addExerciseToWorkout(_ exercise: Exercise) {
        // Create a new set for this exercise
        let newSet = workout.addSet(
            exercise: exercise,
            weight: 0,
            reps: 8
        )
        
        // Update exercise groups and order
        if exerciseGroups[exercise] != nil {
            exerciseGroups[exercise]?.append(newSet)
        } else {
            exerciseGroups[exercise] = [newSet]
            // Add to order if it's a new exercise
            exerciseOrder.append(exercise)
        }
        
        // Automatically expand the newly added exercise
        expandedExercises.insert(exercise.id)
        
        saveWorkout()
    }
    
    func addSetToExercise(_ exercise: Exercise) {
        // Get existing sets for this exercise in the current workout
        let existingSets = workout.sets.filter { $0.exercise?.id == exercise.id }
        
        var newWeight = 0.0
        var newReps = 8
        
        // Sort by set order (we'll use completedAt as a proxy)
        let sortedSets = existingSets.sorted { set1, set2 in
            return set1.completedAt < set2.completedAt
        }
        
        if let lastSet = sortedSets.last {
            // For RPT, reduce weight by default percentage
            let reductionPercentage = getReductionPercentage(forSetNumber: existingSets.count)
            newWeight = lastSet.weight * (1.0 - reductionPercentage)
            
            // For RPT, often increase reps
            newReps = lastSet.reps + 2
            
            // Ensure reps don't exceed a reasonable limit
            newReps = min(newReps, 15)
        }
        
        // Add the new set
        let newSet = workout.addSet(
            exercise: exercise,
            weight: newWeight,
            reps: newReps
        )
        
        // Update our local exercise groups
        if exerciseGroups[exercise] != nil {
            exerciseGroups[exercise]?.append(newSet)
        } else {
            exerciseGroups[exercise] = [newSet]
            // Add to order if it's a new exercise (shouldn't happen but just in case)
            if !exerciseOrder.contains(exercise) {
                exerciseOrder.append(exercise)
            }
        }
        
        saveWorkout()
    }
    
    func updateSet(_ set: ExerciseSet, weight: Double, reps: Int, rpe: Int?) {
        // Update set details
        set.weight = weight
        set.reps = reps
        set.rpe = rpe
        
        // If the set was never completed (weight is 0), mark it as completed now
        if set.weight == 0 && weight > 0 {
            // Only update completedAt if this is the first time the set is getting a weight
            set.completedAt = Date()
        }
        
        saveWorkout()
        
        // Refresh exercise groups but maintain order
        updateExerciseGroupsAndOrder(maintainOrder: true)
    }
    
    func deleteSet(_ set: ExerciseSet) {
        // Find which exercise this set belongs to
        guard let exercise = set.exercise else { return }
        
        // Remove the set from the workout
        if let index = workout.sets.firstIndex(where: { $0.id == set.id }) {
            workout.sets.remove(at: index)
        }
        
        // Remove from our tracked exercise groups
        exerciseGroups[exercise]?.removeAll(where: { $0.id == set.id })
        
        // If that was the last set for this exercise, remove the exercise from our groups and order
        if exerciseGroups[exercise]?.isEmpty ?? true {
            exerciseGroups.removeValue(forKey: exercise)
            if let index = exerciseOrder.firstIndex(where: { $0.id == exercise.id }) {
                exerciseOrder.remove(at: index)
            }
            
            // Also remove from expanded exercises and completed
            expandedExercises.remove(exercise.id)
            completedExercises.remove(exercise.id)
        }
        
        saveWorkout()
    }
    
    func deleteExerciseFromWorkout(_ exercise: Exercise) {
        // Remove all sets for this exercise
        workout.sets.removeAll(where: { $0.exercise?.id == exercise.id })
        
        // Remove from our tracked exercise groups and order
        exerciseGroups.removeValue(forKey: exercise)
        if let index = exerciseOrder.firstIndex(where: { $0.id == exercise.id }) {
            exerciseOrder.remove(at: index)
        }
        
        // Also remove from expanded exercises and completed
        expandedExercises.remove(exercise.id)
        completedExercises.remove(exercise.id)
        
        saveWorkout()
    }
    
    // MARK: - Exercise Completion and Expansion
    
    func toggleExerciseCompletion(_ exercise: Exercise) {
        if completedExercises.contains(exercise.id) {
            completedExercises.remove(exercise.id)
        } else {
            completedExercises.insert(exercise.id)
        }
    }
    
    func isExerciseCompleted(_ exercise: Exercise) -> Bool {
        // Exercise is completed ONLY if manually marked as completed
        return completedExercises.contains(exercise.id)
    }
    
    func toggleExerciseExpansion(_ exercise: Exercise) {
        if expandedExercises.contains(exercise.id) {
            expandedExercises.remove(exercise.id)
        } else {
            expandedExercises.insert(exercise.id)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getReductionPercentage(forSetNumber setNumber: Int) -> Double {
        // Default reduction percentages
        let defaultDrops = [0.0, 0.1, 0.15, 0.2]
        return defaultDrops[safe: setNumber] ?? 0.1
    }
    
    private func updateExerciseGroupsAndOrder(maintainOrder: Bool = false) {
        // Rebuild exercise groups
        let groups = Dictionary(grouping: workout.sets) { $0.exercise! }
        self.exerciseGroups = groups
        
        if maintainOrder {
            // Keep existing exercise order, just remove any that aren't in groups anymore
            exerciseOrder.removeAll(where: { !groups.keys.contains($0) })
            
            // Add any new exercises that might have been added
            for exercise in groups.keys {
                if !exerciseOrder.contains(exercise) {
                    exerciseOrder.append(exercise)
                }
            }
        } else {
            // Determine initial exercise order based on the first completedAt timestamp for each exercise
            var exerciseFirstTimestamp: [(Exercise, Date)] = []
            
            for (exercise, sets) in groups {
                if let firstSet = sets.min(by: { $0.completedAt < $1.completedAt }) {
                    exerciseFirstTimestamp.append((exercise, firstSet.completedAt))
                }
            }
            
            // Sort exercises by their first set's timestamp
            exerciseOrder = exerciseFirstTimestamp
                .sorted(by: { $0.1 < $1.1 })
                .map { $0.0 }
        }
    }
    
    // Start rest timer after completing a set
    func startRestTimer() {
        // Get rest duration from settings
        let settingsManager = SettingsManager.shared
        currentRestDuration = settingsManager.settings.restTimerDuration
        
        // Show the timer
        showingRestTimer = true
    }
    
    // Cancel rest timer
    func cancelRestTimer() {
        showingRestTimer = false
    }
    
    // MARK: - Progress Tracking
    
    var completedExercisesCount: Int {
        return completedExercises.count
    }
    
    // Total number of exercises
    var totalExercisesCount: Int {
        return exerciseOrder.count
    }
}
