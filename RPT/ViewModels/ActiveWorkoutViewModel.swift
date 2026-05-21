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
    enum WorkoutError: Error, Equatable {
        case saveFailure
        case completeFailure
        case deleteFailure
        case exerciseNotFound
        case invalidExerciseData
        case invalidSetData
        case duplicateExercise
        case operationFailed

        var description: String {
            switch self {
            case .saveFailure: return "Failed to save workout"
            case .completeFailure: return "Failed to complete workout"
            case .deleteFailure: return "Failed to delete workout"
            case .exerciseNotFound: return "Exercise not found in workout"
            case .invalidExerciseData: return "Invalid exercise data"
            case .invalidSetData: return "Invalid set data"
            case .duplicateExercise: return "Exercise already added to this workout"
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
    @Published var errorAlertTitle: String = "Workout Action Failed"
    
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

    var remainingExercises: [Exercise] {
        exerciseOrder.filter { !isExerciseCompleted($0) }
    }

    var finishHelperText: String? {
        helperTextForIncompleteExercises(enableActionLabel: finishButtonTitle())
    }

    var exitDialogHelperText: String {
        helperTextForIncompleteExercises(enableActionLabel: completeWorkoutButtonTitle())
        ?? "Save for later keeps it as a draft. Complete marks it as finished."
    }

    var canCompleteWorkoutFromExitDialog: Bool {
        allExercisesCompleted
    }

    func discardWorkoutAlertTitle() -> String {
        guard let displayName = specificWorkoutDisplayName else {
            return "Discard Current Workout?"
        }

        return "Discard “\(displayName)”?"
    }

    func discardWorkoutButtonTitle() -> String {
        guard let displayName = specificWorkoutDisplayName else {
            return "Discard Current Workout"
        }

        return "Discard “\(displayName)”"
    }

    func discardWorkoutMessage() -> String {
        guard let displayName = specificWorkoutDisplayName else {
            return "Are you sure you want to discard your current workout? This action cannot be undone."
        }

        return "Are you sure you want to discard \(displayName)? This action cannot be undone."
    }

    func completeWorkoutAlertTitle() -> String {
        guard let displayName = specificWorkoutDisplayName else {
            return "Complete Current Workout?"
        }

        return "Complete “\(displayName)”?"
    }

    func finishButtonTitle() -> String {
        guard let displayName = specificWorkoutDisplayName else {
            return "Finish Current Workout"
        }

        return "Finish “\(displayName)”"
    }

    func completeWorkoutButtonTitle() -> String {
        guard let displayName = specificWorkoutDisplayName else {
            return "Complete Current Workout & Save"
        }

        return "Complete “\(displayName)” & Save"
    }

    func continueWorkoutButtonTitle() -> String {
        guard let displayName = specificWorkoutDisplayName else {
            return "Continue Current Workout"
        }

        return "Continue “\(displayName)”"
    }

    func saveForLaterButtonTitle() -> String {
        guard let displayName = specificWorkoutDisplayName else {
            return "Save Current Workout for Later"
        }

        return "Save “\(displayName)” for Later"
    }

    func exitWorkoutMenuTitle() -> String {
        guard let displayName = specificWorkoutDisplayName else {
            return "Exit Current Workout"
        }

        return "Exit “\(displayName)”"
    }

    func discardWorkoutMenuTitle() -> String {
        guard let displayName = specificWorkoutDisplayName else {
            return "Discard Current Workout"
        }

        return "Discard “\(displayName)”"
    }

    func completeWorkoutMessage() -> String {
        guard let displayName = specificWorkoutDisplayName else {
            return "Would you like to complete and save your current workout?"
        }

        return "Would you like to complete and save \(displayName)?"
    }

    func deleteExerciseAlertTitle(for exercise: Exercise?) -> String {
        guard let displayName = exercise?.specificDisplayName else {
            return "Delete Exercise?"
        }

        return "Delete “\(displayName)” from Workout?"
    }

    func deleteExerciseButtonTitle(for exercise: Exercise) -> String {
        guard let displayName = exercise.specificDisplayName else {
            return "Delete Exercise"
        }

        return "Delete “\(displayName)”"
    }

    func deleteExerciseMessage(for exercise: Exercise?) -> String {
        guard let exercise else {
            return "Are you sure you want to remove this exercise from the workout? All sets for this exercise will be deleted."
        }

        let impactSummary = deleteExerciseImpactSummary(for: exercise)

        guard let displayName = exercise.specificDisplayName else {
            return "Are you sure you want to remove this exercise from the workout? \(impactSummary)"
        }

        return "Are you sure you want to remove “\(displayName)” from this workout? \(impactSummary)"
    }

    private func deleteExerciseImpactSummary(for exercise: Exercise) -> String {
        let matchingSets = workout.sets.filter { $0.exercise?.id == exercise.id }

        guard !matchingSets.isEmpty else {
            return "All sets for this exercise will be deleted."
        }

        let totalSetCount = matchingSets.count
        let loggedSetCount = matchingSets.filter(\.isCompletedLoggedSet).count
        let totalSetSummary = totalSetCount == 1 ? "1 set" : "\(totalSetCount) sets"

        guard loggedSetCount > 0 else {
            return "This will remove \(totalSetSummary) from the workout."
        }

        let loggedSetSummary = loggedSetCount == 1 ? "1 logged set" : "\(loggedSetCount) logged sets"
        return "This will remove \(totalSetSummary) from the workout, including \(loggedSetSummary)."
    }
    
    init(workout: Workout, workoutManager: WorkoutManager? = nil, exerciseManager: ExerciseManager? = nil, settingsManager: SettingsManager? = nil) {
        self.workout = workout
        self.workoutName = workout.name
        self.workoutManager = workoutManager ?? WorkoutManager.shared
        self.exerciseManager = exerciseManager ?? ExerciseManager.shared
        self.settingsManager = settingsManager ?? SettingsManager.shared
        
        // Initialize exercise groups and order
        updateExerciseGroupsAndOrder()
        
        do {
            try populateWithPreviousWeights()
        } catch {
            setError(
                title: workoutFailureAlertTitle(action: "Load"),
                message: "Error loading previous weights: \(error.localizedDescription)"
            )
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
        guard workout.startedFromTemplate != nil else {
            return
        }

        struct SetSnapshot {
            let set: ExerciseSet
            let weight: Int
            let reps: Int
            let rpe: Int?
            let completedAt: Date
        }

        var snapshots: [PersistentIdentifier: SetSnapshot] = [:]

        for exercise in exerciseOrder {
            // Get the workout history for this exercise - Safe to use without try because the method handles errors internally
            let history = workoutManager.getWorkoutHistory(for: exercise)

            // If there's previous workout data
            if !history.isEmpty {
                // Find the most recent workout that has completed working sets
                let recentWorkouts = history.filter { workout, sets in
                    workout.isCompleted && sets.contains(where: Self.shouldUseForTemplateAutofill)
                }

                if let mostRecent = recentWorkouts.first {
                    // Use completed working sets only (exclude warmups/placeholders)
                    let sortedSets = orderSetsForDisplay(
                        mostRecent.sets.filter(Self.shouldUseForTemplateAutofill)
                    )

                    // Get current sets for this exercise in the current workout
                    if let currentSets = exerciseGroups[exercise].map(orderSetsForDisplay) {
                        // Apply previous weights to the new sets
                        for (index, currentSet) in currentSets.enumerated() {
                            if let previousSet = sortedSets[safe: index] {
                                if snapshots[currentSet.id] == nil {
                                    snapshots[currentSet.id] = SetSnapshot(
                                        set: currentSet,
                                        weight: currentSet.weight,
                                        reps: currentSet.reps,
                                        rpe: currentSet.rpe,
                                        completedAt: currentSet.completedAt
                                    )
                                }

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

        do {
            // Save the workout with the weights but no exercises marked as completed
            try saveWorkout()
        } catch {
            for snapshot in snapshots.values {
                snapshot.set.weight = snapshot.weight
                snapshot.set.reps = snapshot.reps
                snapshot.set.rpe = snapshot.rpe
                snapshot.set.completedAt = snapshot.completedAt
            }
            throw error
        }
    }
    
    // MARK: - Workout Management
    
    func updateWorkoutName() throws {
        let originalWorkoutName = workout.name
        let originalFieldValue = workoutName
        let sanitizedName = workoutManager.sanitizedWorkoutName(workoutName)
        workoutName = sanitizedName
        workout.name = sanitizedName

        do {
            try workoutManager.saveWorkout(workout)
        } catch {
            workout.name = originalWorkoutName
            workoutName = originalFieldValue
            throw error
        }
    }
    
    // Safe version that doesn't throw
    func updateWorkoutNameSafely() -> Bool {
        do {
            try updateWorkoutName()
            return true
        } catch {
            setError(
                title: workoutFailureAlertTitle(action: "Rename"),
                message: "Failed to update workout name: \(error.localizedDescription)"
            )
            return false
        }
    }
    
    func saveWorkout() throws {
        do {
            try workoutManager.saveWorkout(workout)
        } catch {
            throw WorkoutError.saveFailure
        }
    }

    // Safe version that doesn't throw
    func saveWorkoutSafely() -> Bool {
        do {
            try saveWorkout()
            return true
        } catch {
            setError(
                title: workoutFailureAlertTitle(action: "Save"),
                message: "Failed to save workout: \(error.localizedDescription)"
            )
            return false
        }
    }

    func saveWorkoutForLaterSafely() -> Bool {
        guard saveWorkoutSafely() else {
            return false
        }

        WorkoutStateManager.shared.markWorkoutAsSaved(workout.id)
        return true
    }

    func completeWorkout() throws {
        do {
            try workoutManager.completeWorkout(workout)
        } catch {
            throw WorkoutError.completeFailure
        }
    }

    // Safe version that doesn't throw
    func completeWorkoutSafely() -> Bool {
        do {
            try completeWorkout()
            return true
        } catch {
            setError(
                title: workoutFailureAlertTitle(action: "Complete"),
                message: "Failed to complete workout: \(error.localizedDescription)"
            )
            return false
        }
    }

    func completeAndMarkSavedSafely() -> Bool {
        guard completeWorkoutSafely() else {
            return false
        }

        WorkoutStateManager.shared.markWorkoutAsSaved(workout.id)
        return true
    }

    func discardWorkout() throws {
        do {
            try workoutManager.deleteWorkout(workout)
        } catch {
            throw WorkoutError.deleteFailure
        }
    }
    
    // Safe version that doesn't throw
    func discardWorkoutSafely() -> Bool {
        do {
            try discardWorkout()
            return true
        } catch {
            setError(
                title: workoutFailureAlertTitle(action: "Discard"),
                message: "Failed to discard workout: \(error.localizedDescription)"
            )
            return false
        }
    }

    func discardAndMarkDiscardedSafely() -> Bool {
        guard discardWorkoutSafely() else {
            return false
        }

        WorkoutStateManager.shared.markWorkoutAsDiscarded(workout.id)
        return true
    }
    
    // MARK: - Exercise Management
    
    func addExerciseToWorkout(_ exercise: Exercise) throws {
        guard !exerciseOrder.contains(where: { $0.id == exercise.id }) else {
            throw WorkoutError.duplicateExercise
        }

        // Create a new set for this exercise
        let newSet = workout.addSet(
            exercise: exercise,
            weight: 0,
            reps: 8
        )
        // Newly inserted sets should start incomplete until explicitly logged.
        newSet.completedAt = .distantPast
        
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

        do {
            try saveWorkout()
        } catch {
            rollbackInsertedSet(newSet, for: exercise)
            throw error
        }
    }
    
    // Safe version that doesn't throw
    func addExerciseToWorkoutSafely(_ exercise: Exercise) -> Bool {
        do {
            try addExerciseToWorkout(exercise)
            return true
        } catch let error as WorkoutError {
            let title = exerciseFailureAlertTitle(action: "Add", exercise: exercise)
            setError(title: title, message: error.description)
            return false
        } catch {
            setError(
                title: exerciseFailureAlertTitle(action: "Add", exercise: exercise),
                message: "Failed to add exercise: \(error.localizedDescription)"
            )
            return false
        }
    }
    
    func addSetToExercise(_ exercise: Exercise) throws {
        // Get existing sets for this exercise in the current workout
        let existingSets = workout.sets.filter { $0.exercise?.id == exercise.id }
        let orderedExistingSets = orderSetsForDisplay(existingSets)
        let completedWorkingSets = orderedExistingSets.filter(\.isCompletedWorkingSet)
        
        var newWeight = 0
        var newReps = 8
        
        // Keep progression tied to canonical insertion order, but only count
        // completed working sets for drop-index math so warmups/incomplete
        // placeholders never shift top/back-off progression.
        if let lastSet = completedWorkingSets.last ?? orderedExistingSets.last {
            // For RPT, reduce weight by default percentage.
            // Clamp to a safe range so malformed settings never yield invalid math.
            let reductionPercentage = min(max(getReductionPercentage(forSetNumber: completedWorkingSets.count), 0), 1)
            let safeLastWeight = max(0, lastSet.weight)
            let calculatedWeight = Double(safeLastWeight) * (1.0 - reductionPercentage)
            // Round to nearest 5 and keep suggestions non-negative.
            newWeight = max(0, workoutManager.roundToNearest5(calculatedWeight))

            // For RPT, usually increase reps from the prior completed value.
            // Keep the default starter reps when prior reps are zero/corrupted.
            let safeLastReps = max(0, lastSet.reps)
            if safeLastReps > 0 {
                newReps = min(safeLastReps + 2, 15)
            }
        }
        
        // Add the new set
        let newSet = workout.addSet(
            exercise: exercise,
            weight: newWeight,
            reps: newReps
        )
        // Auto-generated set suggestions should remain incomplete until user confirms/logs them.
        newSet.completedAt = .distantPast
        
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

        do {
            try saveWorkout()
        } catch {
            rollbackInsertedSet(newSet, for: exercise)
            throw error
        }
    }
    
    // Safe version that doesn't throw
    func addSetToExerciseSafely(_ exercise: Exercise) -> Bool {
        do {
            try addSetToExercise(exercise)
            return true
        } catch {
            setError(
                title: exerciseFailureAlertTitle(action: "Add", exercise: exercise),
                message: "Failed to add set: \(error.localizedDescription)"
            )
            return false
        }
    }
    
    func updateSet(_ set: ExerciseSet, weight: Int, reps: Int, rpe: Int?) throws {
        guard weight >= 0, reps >= 0 else {
            throw WorkoutError.invalidSetData
        }
        if let rpeValue = rpe, !(1...10).contains(rpeValue) {
            throw WorkoutError.invalidSetData
        }

        let originalWeight = set.weight
        let originalReps = set.reps
        let originalRPE = set.rpe
        let originalCompletedAt = set.completedAt
        let wasIncomplete = !set.hasCompletedValues || set.completedAt == .distantPast
        set.weight = weight
        set.reps = reps
        set.rpe = rpe

        let isComplete = ExerciseSet.hasCompletedValues(
            weight: weight,
            reps: reps,
            exerciseCategory: set.exercise?.category
        )
        if !isComplete {
            set.completedAt = .distantPast
        } else if wasIncomplete {
            set.completedAt = Date()
        }

        do {
            try saveWorkout()
        } catch {
            set.weight = originalWeight
            set.reps = originalReps
            set.rpe = originalRPE
            set.completedAt = originalCompletedAt
            throw error
        }

        updateExerciseGroupsAndOrder(maintainOrder: true)
    }
    
    // Safe version that doesn't throw
    func updateSetSafely(_ set: ExerciseSet, weight: Int, reps: Int, rpe: Int?) -> Bool {
        do {
            try updateSet(set, weight: weight, reps: reps, rpe: rpe)
            return true
        } catch {
            setError(
                title: exerciseFailureAlertTitle(action: "Update", exercise: set.exercise),
                message: "Failed to update set: \(error.localizedDescription)"
            )
            return false
        }
    }
    
    func deleteSet(_ set: ExerciseSet) throws {
        // Find which exercise this set belongs to
        guard let exercise = set.exercise else {
            throw WorkoutError.invalidSetData
        }

        // Delete through manager so SwiftData does not keep orphaned sets
        // linked to exercises after workout-only removal.
        try workoutManager.deleteSet(set)
        updateExerciseGroupsAndOrder(maintainOrder: true)

        // If that was the last set for this exercise, clear UI state too.
        if !exerciseGroups.keys.contains(where: { $0.id == exercise.id }) {
            expandedExercises.remove(exercise.id)
            completedExercises.remove(exercise.id)
        }
    }
    
    // Safe version that doesn't throw
    func deleteSetSafely(_ set: ExerciseSet) -> Bool {
        do {
            try deleteSet(set)
            return true
        } catch {
            setError(
                title: exerciseFailureAlertTitle(action: "Delete", exercise: set.exercise),
                message: "Failed to delete set: \(error.localizedDescription)"
            )
            return false
        }
    }
    
    func deleteExerciseFromWorkout(_ exercise: Exercise) throws {
        // Validate that the exercise exists in the workout
        guard exerciseGroups.keys.contains(where: { $0.id == exercise.id }) else {
            throw WorkoutError.exerciseNotFound
        }

        // Delete through manager so backing ExerciseSet records are removed,
        // not just detached from this workout.
        try workoutManager.removeExercise(exercise, from: workout)
        updateExerciseGroupsAndOrder(maintainOrder: true)

        // Also remove from expanded exercises and completed
        expandedExercises.remove(exercise.id)
        completedExercises.remove(exercise.id)
    }
    
    // Safe version that doesn't throw
    func deleteExerciseFromWorkoutSafely(_ exercise: Exercise) -> Bool {
        do {
            try deleteExerciseFromWorkout(exercise)
            return true
        } catch {
            setError(
                title: exerciseFailureAlertTitle(action: "Delete", exercise: exercise),
                message: "Failed to delete exercise: \(error.localizedDescription)"
            )
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

    private var specificWorkoutDisplayName: String? {
        let displayName = WorkoutRow.displayName(for: workout)
        return displayName == "Workout" ? nil : displayName
    }

    private func rollbackInsertedSet(_ set: ExerciseSet, for exercise: Exercise) {
        exerciseGroups[exercise]?.removeAll { $0.id == set.id }

        if exerciseGroups[exercise]?.isEmpty == true {
            exerciseGroups.removeValue(forKey: exercise)
            exerciseOrder.removeAll { $0.id == exercise.id }
            expandedExercises.remove(exercise.id)
            completedExercises.remove(exercise.id)
        }

        workout.sets.removeAll { $0.id == set.id }
        exercise.sets.removeAll { $0.id == set.id }
        set.workout = nil
        set.exercise = nil
    }

    private func setError(title: String, message: String) {
        errorAlertTitle = title
        errorMessage = message
    }

    private func workoutFailureAlertTitle(action: String) -> String {
        guard let displayName = specificWorkoutDisplayName else {
            return genericWorkoutFailureAlertTitle(action: action)
        }

        return "Couldn’t \(action) “\(displayName)”"
    }

    private func exerciseFailureAlertTitle(action: String, exercise: Exercise?) -> String {
        guard let displayName = exercise?.specificDisplayName else {
            return genericExerciseFailureAlertTitle(action: action)
        }

        return "Couldn’t \(action) “\(displayName)”"
    }

    private func genericWorkoutFailureAlertTitle(action: String) -> String {
        switch action {
        case "Load":
            return "Couldn’t Load Current Workout"
        case "Rename":
            return "Couldn’t Rename Current Workout"
        case "Save":
            return "Couldn’t Save Current Workout"
        case "Complete":
            return "Couldn’t Complete Current Workout"
        case "Discard":
            return "Couldn’t Discard Current Workout"
        default:
            return "Workout Action Failed"
        }
    }

    private func genericExerciseFailureAlertTitle(action: String) -> String {
        switch action {
        case "Add":
            return "Couldn’t Add This Exercise"
        case "Update":
            return "Couldn’t Update This Exercise"
        case "Delete":
            return "Couldn’t Delete This Exercise"
        default:
            return "Workout Action Failed"
        }
    }

    private func helperTextForIncompleteExercises(enableActionLabel: String) -> String? {
        guard !exerciseOrder.isEmpty, !allExercisesCompleted else {
            return nil
        }

        let remainingNames = remainingExercises.map(\.displayName)
        let remainingCount = remainingNames.count

        switch remainingCount {
        case 1:
            return "1 exercise left: \(remainingNames[0]). Tap the circle beside it when you're done to enable \(enableActionLabel)."
        case 2:
            return "2 exercises left: \(remainingNames[0]) and \(remainingNames[1]). Tap each circle when you're done to enable \(enableActionLabel)."
        default:
            let previewNames = remainingNames.prefix(2).joined(separator: ", ")
            let extraCount = remainingCount - 2
            return "\(remainingCount) exercises left: \(previewNames), +\(extraCount) more. Tap each circle when you're done to enable \(enableActionLabel)."
        }
    }

    private static func shouldUseForTemplateAutofill(_ set: ExerciseSet) -> Bool {
        set.isCompletedWorkingSet
    }
    
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
        // Rebuild exercise groups, filtering out sets without exercises
        let setsWithExercise = workout.sets.compactMap { set -> (Exercise, ExerciseSet)? in
            guard let exercise = set.exercise else { return nil }
            return (exercise, set)
        }
        let groups = Dictionary(grouping: setsWithExercise, by: { $0.0 }).mapValues { $0.map { $0.1 } }
        self.exerciseGroups = groups
        
        if maintainOrder {
            let groupKeyIds = Set(groups.keys.map { $0.id })
            exerciseOrder.removeAll(where: { !groupKeyIds.contains($0.id) })

            for exercise in groups.keys where !exerciseOrder.contains(where: { $0.id == exercise.id }) {
                exerciseOrder.append(exercise)
            }
        } else {
            // Determine initial exercise order from canonical workout insertion order.
            // This avoids unstable ordering when multiple sets share `.distantPast`.
            var orderedExercises: [Exercise] = []

            for set in workout.sets {
                guard let exercise = set.exercise else { continue }
                if !orderedExercises.contains(where: { $0.id == exercise.id }) {
                    orderedExercises.append(exercise)
                }
            }

            // Keep any group keys that may not be represented in `workout.sets` yet.
            for exercise in groups.keys where !orderedExercises.contains(where: { $0.id == exercise.id }) {
                orderedExercises.append(exercise)
            }

            exerciseOrder = orderedExercises
        }
    }

    private func orderSetsForDisplay(_ sets: [ExerciseSet]) -> [ExerciseSet] {
        sets.sorted { lhs, rhs in
            let lhsOrder = setOrderIndex(lhs)
            let rhsOrder = setOrderIndex(rhs)

            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }

            return lhs.completedAt < rhs.completedAt
        }
    }

    func orderedSetsForDisplay(in exercise: Exercise) -> [ExerciseSet] {
        orderSetsForDisplay(exerciseGroups[exercise] ?? [])
    }

    func updateDropSetSuggestions(for exercise: Exercise, firstSetWeight: Int) throws {
        let sets = orderedSetsForDisplay(in: exercise)
        guard sets.count > 1 else { return }

        let dropPercentages = settingsManager.settings.defaultRPTPercentageDrops
        let affectedSetCount = min(sets.count, dropPercentages.count)
        guard affectedSetCount > 1 else { return }

        struct SetSnapshot {
            let set: ExerciseSet
            let weight: Int
            let reps: Int
            let rpe: Int?
            let completedAt: Date
        }

        let snapshots = (1..<affectedSetCount).map { index in
            let set = sets[index]
            return SetSnapshot(
                set: set,
                weight: set.weight,
                reps: set.reps,
                rpe: set.rpe,
                completedAt: set.completedAt
            )
        }

        for index in 1..<affectedSetCount {
            let dropPercentage = min(max(dropPercentages[index], 0), 1)
            let calculatedWeight = Double(firstSetWeight) * (1.0 - dropPercentage)
            let roundedWeight = max(0, workoutManager.roundToNearest5(calculatedWeight))
            let set = sets[index]
            let wasIncomplete = !set.hasCompletedValues || set.completedAt == .distantPast

            set.weight = roundedWeight

            let isComplete = ExerciseSet.hasCompletedValues(
                weight: roundedWeight,
                reps: set.reps,
                exerciseCategory: set.exercise?.category
            )
            if !isComplete {
                set.completedAt = .distantPast
            } else if wasIncomplete {
                set.completedAt = Date()
            }
        }

        do {
            try saveWorkout()
        } catch {
            for snapshot in snapshots {
                snapshot.set.weight = snapshot.weight
                snapshot.set.reps = snapshot.reps
                snapshot.set.rpe = snapshot.rpe
                snapshot.set.completedAt = snapshot.completedAt
            }
            throw error
        }

        updateExerciseGroupsAndOrder(maintainOrder: true)
    }

    func updateDropSetSuggestionsSafely(for exercise: Exercise, firstSetWeight: Int) -> Bool {
        do {
            try updateDropSetSuggestions(for: exercise, firstSetWeight: firstSetWeight)
            return true
        } catch {
            setError(
                title: exerciseFailureAlertTitle(action: "Update", exercise: exercise),
                message: "Failed to update drop sets: \(error.localizedDescription)"
            )
            return false
        }
    }

    private func setOrderIndex(_ set: ExerciseSet) -> Int {
        set.workout?.sets.firstIndex(where: { $0.id == set.id }) ?? Int.max
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
        errorAlertTitle = "Workout Action Failed"
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
