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
    enum WorkoutError: Error {
        case saveFailure
        case exerciseNotFound
        case invalidExerciseData
        case invalidSetData
        case operationFailed
        
        var description: String {
            switch self {
            case .saveFailure: return "Failed to save workout"
            case .exerciseNotFound: return "Exercise not found in workout"
            case .invalidExerciseData: return "Invalid exercise data"
            case .invalidSetData: return "Invalid set data"
            case .operationFailed: return "Operation failed"
            }
        }
    }
    
    @Published var workout: Workout
    @Published var workoutName: String
    @Published var exerciseGroups: [Exercise: [ExerciseSet]] = [:]
    @Published var exerciseOrder: [Exercise] = [] // Track order of exercises
    @Published var showingRestTimer = false
    @Published var currentRestDuration: Int = 180
    @Published var completedExercises: Set<PersistentIdentifier> = [] // Only manually tracked completions
    @Published var expandedExercises: Set<PersistentIdentifier> = Set() // Track which exercises are expanded
    @Published var errorMessage: String?
    
    // State for confirmation dialogs
    @Published var exerciseToDelete: Exercise? = nil
    @Published var showingDeleteExerciseConfirmation = false
    
    private let workoutManager: WorkoutManager
    private let exerciseManager: ExerciseManager
    private let settingsManager: SettingsManager
    
    var hasSets: Bool {
        return !workout.sets.isEmpty
    }
    
    // Add computed property to check if all exercises are completed
    var allExercisesCompleted: Bool {
        guard !exerciseOrder.isEmpty else { return false }
        return exerciseOrder.allSatisfy { isExerciseCompleted($0) }
    }
    
    init(workout: Workout, workoutManager: WorkoutManager? = nil, exerciseManager: ExerciseManager? = nil, settingsManager: SettingsManager? = nil) {
        self.workout = workout
        self.workoutName = workout.name
        self.workoutManager = workoutManager ?? WorkoutManager.shared
        self.exerciseManager = exerciseManager ?? ExerciseManager.shared
        self.settingsManager = settingsManager ?? SettingsManager.shared
        
        // Initialize exercise groups and order
        updateExerciseGroupsAndOrder()
        
        // Populate with previous weights - but fixed to not auto-complete
        do {
            try populateWithPreviousWeights()
        } catch {
            errorMessage = "Error loading previous weights: \(error.localizedDescription)"
        }
        
        // Initialize all exercises as expanded by default
        for exercise in exerciseOrder {
            expandedExercises.insert(exercise.id)
        }
        
        // Set rest duration from settings
        currentRestDuration = self.settingsManager.settings.restTimerDuration
    }
    
    // Updated method to populate workout with previous weights without affecting completion
    private func populateWithPreviousWeights() throws {
        // Only run this if the workout was created from a template
        if workout.startedFromTemplate != nil {
            for exercise in exerciseOrder {
                // Get the workout history for this exercise - Safe to use without try because the method handles errors internally
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
            try saveWorkout()
        }
    }
    
    // MARK: - Workout Management
    
    func updateWorkoutName() throws {
        workout.name = workoutName
        try workoutManager.saveWorkout(workout)
    }
    
    // Safe version that doesn't throw
    func updateWorkoutNameSafely() -> Bool {
        do {
            try updateWorkoutName()
            return true
        } catch {
            errorMessage = "Failed to update workout name: \(error.localizedDescription)"
            return false
        }
    }
    
    // Error enum for WorkoutManager methods
    enum WorkoutManagerError: Error {
        case saveFailure
        case completeFailure
        case deleteFailure
        
        var description: String {
            switch self {
            case .saveFailure: return "Failed to save workout"
            case .completeFailure: return "Failed to complete workout"
            case .deleteFailure: return "Failed to delete workout"
            }
        }
    }
    
    func saveWorkout() throws {
        do {
            try workoutManager.saveWorkout(workout)
        } catch {
            print("Error saving workout: \(error)")
            throw WorkoutError.saveFailure
        }
    }
    
    // Safe version that doesn't throw
    func saveWorkoutSafely() -> Bool {
        do {
            try saveWorkout()
            return true
        } catch {
            errorMessage = "Failed to save workout: \(error.localizedDescription)"
            return false
        }
    }
    
    func completeWorkout() throws {
        do {
            try workoutManager.completeWorkout(workout)
        } catch {
            print("Error completing workout: \(error)")
            throw WorkoutManagerError.completeFailure
        }
    }
    
    // Safe version that doesn't throw
    func completeWorkoutSafely() -> Bool {
        do {
            try completeWorkout()
            return true
        } catch {
            errorMessage = "Failed to complete workout: \(error.localizedDescription)"
            return false
        }
    }
    
    func discardWorkout() throws {
        do {
            try workoutManager.deleteWorkout(workout)
        } catch {
            print("Error discarding workout: \(error)")
            throw WorkoutManagerError.deleteFailure
        }
    }
    
    // Safe version that doesn't throw
    func discardWorkoutSafely() -> Bool {
        do {
            try discardWorkout()
            return true
        } catch {
            errorMessage = "Failed to discard workout: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Exercise Management
    
    func addExerciseToWorkout(_ exercise: Exercise) throws {
        
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
        
        try saveWorkout()
    }
    
    // Safe version that doesn't throw
    func addExerciseToWorkoutSafely(_ exercise: Exercise) -> Bool {
        do {
            try addExerciseToWorkout(exercise)
            return true
        } catch {
            errorMessage = "Failed to add exercise: \(error.localizedDescription)"
            return false
        }
    }
    
    func addSetToExercise(_ exercise: Exercise) throws {
        // Get existing sets for this exercise in the current workout
        let existingSets = workout.sets.filter { $0.exercise?.id == exercise.id }
        
        var newWeight = 0
        var newReps = 8
        
        // Sort by set order (we'll use completedAt as a proxy)
        let sortedSets = existingSets.sorted { set1, set2 in
            return set1.completedAt < set2.completedAt
        }
        
        if let lastSet = sortedSets.last {
            // For RPT, reduce weight by default percentage
            let reductionPercentage = getReductionPercentage(forSetNumber: existingSets.count)
            let calculatedWeight = Double(lastSet.weight) * (1.0 - reductionPercentage)
            // Round to nearest 5
            newWeight = workoutManager.roundToNearest5(calculatedWeight)
            
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
        
        try saveWorkout()
    }
    
    // Safe version that doesn't throw
    func addSetToExerciseSafely(_ exercise: Exercise) -> Bool {
        do {
            try addSetToExercise(exercise)
            return true
        } catch {
            errorMessage = "Failed to add set: \(error.localizedDescription)"
            return false
        }
    }
    
    func updateSet(_ set: ExerciseSet, weight: Int, reps: Int, rpe: Int?) throws {
        // Validate input
        guard weight >= 0, reps >= 0, rpe == nil || (rpe! >= 0 && rpe! <= 10) else {
            throw WorkoutError.invalidSetData
        }
        
        // Update set details
        set.weight = weight
        set.reps = reps
        set.rpe = rpe
        
        // If the set was never completed (weight is 0), mark it as completed now
        if set.weight == 0 && weight > 0 {
            // Only update completedAt if this is the first time the set is getting a weight
            set.completedAt = Date()
        }
        
        try saveWorkout()
        
        // Refresh exercise groups but maintain order
        updateExerciseGroupsAndOrder(maintainOrder: true)
    }
    
    // Safe version that doesn't throw
    func updateSetSafely(_ set: ExerciseSet, weight: Int, reps: Int, rpe: Int?) -> Bool {
        do {
            try updateSet(set, weight: weight, reps: reps, rpe: rpe)
            return true
        } catch {
            errorMessage = "Failed to update set: \(error.localizedDescription)"
            return false
        }
    }
    
    func deleteSet(_ set: ExerciseSet) throws {
        // Find which exercise this set belongs to
        guard let exercise = set.exercise else {
            throw WorkoutError.invalidSetData
        }
        
        // Remove the set from the workout
        if let index = workout.sets.firstIndex(where: { $0.id == set.id }) {
            workout.sets.remove(at: index)
        } else {
            throw WorkoutError.invalidSetData
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
        
        try saveWorkout()
    }
    
    // Safe version that doesn't throw
    func deleteSetSafely(_ set: ExerciseSet) -> Bool {
        do {
            try deleteSet(set)
            return true
        } catch {
            errorMessage = "Failed to delete set: \(error.localizedDescription)"
            return false
        }
    }
    
    func deleteExerciseFromWorkout(_ exercise: Exercise) throws {
        // Validate that the exercise exists in the workout
        guard exerciseGroups.keys.contains(where: { $0.id == exercise.id }) else {
            throw WorkoutError.exerciseNotFound
        }
        
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
        
        try saveWorkout()
    }
    
    // Safe version that doesn't throw
    func deleteExerciseFromWorkoutSafely(_ exercise: Exercise) -> Bool {
        do {
            try deleteExerciseFromWorkout(exercise)
            return true
        } catch {
            errorMessage = "Failed to delete exercise: \(error.localizedDescription)"
            return false
        }
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
        // Get reduction percentages from settings
        let settingsDrops = settingsManager.settings.defaultRPTPercentageDrops
        
        if setNumber < settingsDrops.count {
            return settingsDrops[setNumber]
        }
        
        // Fallback to default if settings don't have enough drops
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
        currentRestDuration = settingsManager.settings.restTimerDuration
        
        // Show the timer
        showingRestTimer = true
    }
    
    // Cancel rest timer
    func cancelRestTimer() {
        showingRestTimer = false
    }
    
    // Clear any error message
    func clearError() {
        errorMessage = nil
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
