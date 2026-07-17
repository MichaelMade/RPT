//
//  ActiveWorkoutViewModel.swift
//  RPT
//
//  State and persistence for a live workout session: exercise/set CRUD
//  with rollback on failed saves, RPT back-off weight suggestions, and
//  rest-timer state.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class ActiveWorkoutViewModel: ObservableObject {
    enum WorkoutError: Error, Equatable {
        case saveFailure
        case completeFailure
        case nothingLogged
        case deleteFailure
        case exerciseNotFound
        case invalidExerciseData
        case invalidSetData
        case duplicateExercise
        case operationFailed

        var description: String {
            switch self {
            case .saveFailure: return "Couldn’t save this workout. Keep it open, then try again."
            case .completeFailure: return "Couldn’t complete this workout. Keep it open, then try again."
            case .nothingLogged: return "No sets are logged yet. Check off at least one set, or save this workout for later or discard it."
            case .deleteFailure: return "Couldn’t discard this workout. Keep it open, then try again."
            case .exerciseNotFound: return "Exercise not found in workout."
            case .invalidExerciseData: return "Invalid exercise data."
            case .invalidSetData: return "Invalid set data."
            case .duplicateExercise: return "This exercise is already in the workout."
            case .operationFailed: return "Something went wrong. Please try again."
            }
        }
    }

    @Published var workout: Workout
    @Published var workoutName: String
    /// Sets grouped by their exercise's persistent identifier. Keyed by ID
    /// rather than the model object so mutable models never act as hash keys.
    @Published var exerciseGroups: [PersistentIdentifier: [ExerciseSet]] = [:]
    @Published var exerciseOrder: [Exercise] = []
    @Published var showingRestTimer = false
    @Published var currentRestDuration: Int = 180
    @Published var completedExercises: Set<PersistentIdentifier> = []
    @Published var expandedExercises: Set<PersistentIdentifier> = Set()
    @Published var errorMessage: String?
    @Published var errorAlertTitle: String = "Workout Action Failed"

    private let workoutManager: WorkoutManager
    private let exerciseManager: ExerciseManager
    private let settingsManager: SettingsManager

    var hasSets: Bool {
        !workout.sets.isEmpty
    }

    var allExercisesCompleted: Bool {
        guard !exerciseOrder.isEmpty else { return false }
        return exerciseOrder.allSatisfy { isExerciseCompleted($0) }
    }

    var remainingExercises: [Exercise] {
        exerciseOrder.filter { !isExerciseCompleted($0) }
    }

    var completedExercisesCount: Int {
        completedExercises.count
    }

    var totalExercisesCount: Int {
        exerciseOrder.count
    }

    var displayName: String {
        WorkoutNameFormatter.displayName(for: workout)
    }

    var autoStartRestTimerEnabled: Bool {
        settingsManager.settings.autoStartRestTimerEnabled
    }

    init(workout: Workout, workoutManager: WorkoutManager? = nil, exerciseManager: ExerciseManager? = nil, settingsManager: SettingsManager? = nil) {
        self.workout = workout
        self.workoutName = WorkoutNameFormatter.displayName(for: workout.name)
        self.workoutManager = workoutManager ?? WorkoutManager.shared
        self.exerciseManager = exerciseManager ?? ExerciseManager.shared
        self.settingsManager = settingsManager ?? SettingsManager.shared

        updateExerciseGroupsAndOrder()

        do {
            try populateWithPreviousWeights()
        } catch {
            setError(title: "Couldn’t Load Previous Weights", message: WorkoutError.saveFailure.description)
        }

        for exercise in exerciseOrder {
            expandedExercises.insert(exercise.id)
        }

        currentRestDuration = self.settingsManager.settings.restTimerDuration
    }

    // MARK: - Template Autofill

    /// Pre-fills template-created sets with the weights from the most recent
    /// completed session of each exercise, without marking anything logged.
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
            let history = workoutManager.getWorkoutHistory(for: exercise)

            let recentWorkouts = history.filter { workout, sets in
                workout.isCompleted && sets.contains(where: \.isCompletedWorkingSet)
            }

            guard let mostRecent = recentWorkouts.first else { continue }

            let previousSets = orderSetsForDisplay(mostRecent.sets.filter(\.isCompletedWorkingSet))
            guard let currentSets = exerciseGroups[exercise.id].map(orderSetsForDisplay) else { continue }

            for (index, currentSet) in currentSets.enumerated() {
                guard let previousSet = previousSets[safe: index] else { continue }

                if snapshots[currentSet.id] == nil {
                    snapshots[currentSet.id] = SetSnapshot(
                        set: currentSet,
                        weight: currentSet.weight,
                        reps: currentSet.reps,
                        rpe: currentSet.rpe,
                        completedAt: currentSet.completedAt
                    )
                }

                currentSet.weight = previousSet.weight
                if currentSet.reps == 0 {
                    currentSet.reps = previousSet.reps
                }
                currentSet.rpe = previousSet.rpe
            }
        }

        do {
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

    // MARK: - Workout Lifecycle

    func updateWorkoutName() throws {
        let originalWorkoutName = workout.name
        let sanitizedName = workoutManager.sanitizedWorkoutName(workoutName)
        workoutName = sanitizedName
        workout.name = sanitizedName

        do {
            try workoutManager.saveWorkout(workout)
        } catch {
            workout.name = originalWorkoutName
            workoutName = WorkoutNameFormatter.displayName(for: originalWorkoutName)
            throw error
        }
    }

    func updateWorkoutNameSafely() -> Bool {
        do {
            try updateWorkoutName()
            return true
        } catch {
            setError(title: "Couldn’t Rename Workout", message: WorkoutError.saveFailure.description)
            return false
        }
    }

    func updateNotesSafely(_ notes: String) -> Bool {
        let originalNotes = workout.notes
        workout.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try saveWorkout()
            return true
        } catch {
            workout.notes = originalNotes
            setError(title: "Couldn’t Save Notes", message: WorkoutError.saveFailure.description)
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

    func saveWorkoutSafely() -> Bool {
        do {
            try saveWorkout()
            return true
        } catch {
            setError(title: "Couldn’t Save Workout", message: WorkoutError.saveFailure.description)
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
        } catch WorkoutManager.CompletionError.noLoggedSets {
            throw WorkoutError.nothingLogged
        } catch {
            throw WorkoutError.completeFailure
        }
    }

    func completeWorkoutSafely() -> Bool {
        do {
            try completeWorkout()
            return true
        } catch WorkoutError.nothingLogged {
            setError(title: "Nothing Logged Yet", message: WorkoutError.nothingLogged.description)
            return false
        } catch {
            setError(title: "Couldn’t Complete Workout", message: WorkoutError.completeFailure.description)
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

    func discardWorkoutSafely() -> Bool {
        do {
            try discardWorkout()
            return true
        } catch {
            setError(title: "Couldn’t Discard Workout", message: WorkoutError.deleteFailure.description)
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

        let newSet = workout.addSet(exercise: exercise, weight: 0, reps: 8)
        newSet.completedAt = .distantPast

        if exerciseGroups[exercise.id] != nil {
            exerciseGroups[exercise.id]?.append(newSet)
        } else {
            exerciseGroups[exercise.id] = [newSet]
            exerciseOrder.append(exercise)
        }

        expandedExercises.insert(exercise.id)

        do {
            try saveWorkout()
        } catch {
            rollbackInsertedSet(newSet, for: exercise)
            throw error
        }
    }

    func addExerciseToWorkoutSafely(_ exercise: Exercise) -> Bool {
        do {
            try addExerciseToWorkout(exercise)
            return true
        } catch let error as WorkoutError {
            setError(title: "Couldn’t Add \(exercise.displayName)", message: error.description)
            return false
        } catch {
            setError(title: "Couldn’t Add \(exercise.displayName)", message: WorkoutError.saveFailure.description)
            return false
        }
    }

    func deleteExerciseFromWorkout(_ exercise: Exercise) throws {
        guard exerciseGroups[exercise.id] != nil else {
            throw WorkoutError.exerciseNotFound
        }

        // Delete through manager so backing ExerciseSet records are removed,
        // not just detached from this workout.
        try workoutManager.removeExercise(exercise, from: workout)
        updateExerciseGroupsAndOrder(maintainOrder: true)

        expandedExercises.remove(exercise.id)
        completedExercises.remove(exercise.id)
    }

    func deleteExerciseFromWorkoutSafely(_ exercise: Exercise) -> Bool {
        do {
            try deleteExerciseFromWorkout(exercise)
            return true
        } catch {
            setError(title: "Couldn’t Delete \(exercise.displayName)", message: WorkoutError.deleteFailure.description)
            return false
        }
    }

    // MARK: - Set Management

    /// Adds the next RPT back-off set. The suggested weight always drops
    /// from the exercise's top (first completed working) set, so back-off
    /// percentages never compound on each other.
    func addSetToExercise(_ exercise: Exercise) throws {
        let existingSets = workout.sets.filter { $0.exercise?.id == exercise.id }
        let orderedExistingSets = orderSetsForDisplay(existingSets)
        let completedWorkingSets = orderedExistingSets.filter(\.isCompletedWorkingSet)

        var newWeight = 0
        var newReps = 8

        if let topSet = completedWorkingSets.first {
            let reductionPercentage = min(max(reductionPercentage(forSetIndex: completedWorkingSets.count), 0), 1)
            let safeTopWeight = max(0, topSet.weight)
            newWeight = max(0, workoutManager.roundToNearest5(Double(safeTopWeight) * (1.0 - reductionPercentage)))

            let safeLastReps = max(0, completedWorkingSets.last?.reps ?? 0)
            if safeLastReps > 0 {
                newReps = min(safeLastReps + 2, 15)
            }
        } else if let lastSet = orderedExistingSets.last {
            // Nothing logged yet — mirror the most recent placeholder.
            newWeight = max(0, lastSet.weight)
            let safeLastReps = max(0, lastSet.reps)
            if safeLastReps > 0 {
                newReps = safeLastReps
            }
        }

        let newSet = workout.addSet(exercise: exercise, weight: newWeight, reps: newReps)
        newSet.completedAt = .distantPast

        if exerciseGroups[exercise.id] != nil {
            exerciseGroups[exercise.id]?.append(newSet)
        } else {
            exerciseGroups[exercise.id] = [newSet]
            if !exerciseOrder.contains(where: { $0.id == exercise.id }) {
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

    func addSetToExerciseSafely(_ exercise: Exercise) -> Bool {
        do {
            try addSetToExercise(exercise)
            return true
        } catch {
            setError(title: "Couldn’t Add Set", message: WorkoutError.saveFailure.description)
            return false
        }
    }

    /// Adds a warm-up set ahead of the working sets.
    func addWarmupSet(to exercise: Exercise, weight: Int, reps: Int) throws {
        let sanitized = workoutManager.sanitizedSetInput(weight: weight, reps: reps, rpe: nil)
        let newSet = workout.addSet(
            exercise: exercise,
            weight: sanitized.weight,
            reps: sanitized.reps,
            isWarmup: true
        )
        newSet.completedAt = .distantPast

        if exerciseGroups[exercise.id] != nil {
            exerciseGroups[exercise.id]?.append(newSet)
        } else {
            exerciseGroups[exercise.id] = [newSet]
            if !exerciseOrder.contains(where: { $0.id == exercise.id }) {
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

    func addWarmupSetSafely(to exercise: Exercise, weight: Int, reps: Int) -> Bool {
        do {
            try addWarmupSet(to: exercise, weight: weight, reps: reps)
            return true
        } catch {
            setError(title: "Couldn’t Add Warm-up Set", message: WorkoutError.saveFailure.description)
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
        set.weight = weight
        set.reps = reps
        set.rpe = rpe

        // Logging is an explicit action (`toggleSetLogged`); editing values
        // never logs a set. It can only UN-log one whose values are no
        // longer complete, since a logged set must stay valid.
        let isComplete = ExerciseSet.hasCompletedValues(
            weight: weight,
            reps: reps,
            exerciseCategory: set.exercise?.category
        )
        if !isComplete {
            set.completedAt = .distantPast
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

    func updateSetSafely(_ set: ExerciseSet, weight: Int, reps: Int, rpe: Int?) -> Bool {
        do {
            try updateSet(set, weight: weight, reps: reps, rpe: rpe)
            return true
        } catch {
            setError(title: "Couldn’t Update Set", message: WorkoutError.saveFailure.description)
            return false
        }
    }

    func deleteSet(_ set: ExerciseSet) throws {
        guard let exercise = set.exercise else {
            throw WorkoutError.invalidSetData
        }

        // Delete through manager so SwiftData does not keep orphaned sets
        // linked to exercises after workout-only removal.
        try workoutManager.deleteSet(set)
        updateExerciseGroupsAndOrder(maintainOrder: true)

        if exerciseGroups[exercise.id] == nil {
            expandedExercises.remove(exercise.id)
            completedExercises.remove(exercise.id)
        }
    }

    func deleteSetSafely(_ set: ExerciseSet) -> Bool {
        do {
            try deleteSet(set)
            return true
        } catch {
            setError(title: "Couldn’t Delete Set", message: WorkoutError.deleteFailure.description)
            return false
        }
    }

    enum SetLogResult: Equatable {
        /// The set is now logged (counts toward volume, PRs, and back-off math).
        case logged
        /// The set is now unlogged; its values are preserved.
        case unlogged
        /// The set can't be logged yet because weight/reps are incomplete.
        case needsValues
        case failed
    }

    /// Explicitly logs or unlogs a set — the tap target on every set row.
    /// Logging stamps the completion time without touching the set's values,
    /// so template-pre-filled sets can be checked off as planned.
    func toggleSetLogged(_ set: ExerciseSet) throws -> SetLogResult {
        let originalCompletedAt = set.completedAt

        if set.isCompletedLoggedSet {
            set.completedAt = .distantPast
        } else {
            guard set.hasCompletedValues else {
                return .needsValues
            }
            set.completedAt = Date()
        }

        do {
            try saveWorkout()
        } catch {
            set.completedAt = originalCompletedAt
            throw error
        }

        updateExerciseGroupsAndOrder(maintainOrder: true)
        return set.isCompletedLoggedSet ? .logged : .unlogged
    }

    func toggleSetLoggedSafely(_ set: ExerciseSet) -> SetLogResult {
        do {
            return try toggleSetLogged(set)
        } catch {
            setError(title: "Couldn’t Update Set", message: WorkoutError.saveFailure.description)
            return .failed
        }
    }

    /// Recalculates back-off set weights from a new top-set weight using the
    /// configured RPT percentage drops.
    func updateDropSetSuggestions(for exercise: Exercise, firstSetWeight: Int) throws {
        let sets = orderedSetsForDisplay(in: exercise).filter { !$0.isWarmup }
        guard sets.count > 1 else { return }

        let dropPercentages = settingsManager.settings.defaultRPTPercentageDrops
        let affectedSetCount = min(sets.count, dropPercentages.count)
        guard affectedSetCount > 1 else { return }

        struct SetSnapshot {
            let set: ExerciseSet
            let weight: Int
            let completedAt: Date
        }

        let snapshots = (1..<affectedSetCount).map { index in
            SetSnapshot(set: sets[index], weight: sets[index].weight, completedAt: sets[index].completedAt)
        }

        for index in 1..<affectedSetCount {
            let dropPercentage = min(max(dropPercentages[index], 0), 1)
            let calculatedWeight = Double(firstSetWeight) * (1.0 - dropPercentage)
            let roundedWeight = max(0, workoutManager.roundToNearest5(calculatedWeight))
            let set = sets[index]

            set.weight = roundedWeight

            // Suggestions only adjust the planned load — they must never log
            // a set the user hasn't performed. Logging happens via the
            // explicit check-off or the user's own value edits. A set whose
            // values become incomplete does get unlogged.
            let isComplete = ExerciseSet.hasCompletedValues(
                weight: roundedWeight,
                reps: set.reps,
                exerciseCategory: set.exercise?.category
            )
            if !isComplete {
                set.completedAt = .distantPast
            }
        }

        do {
            try saveWorkout()
        } catch {
            for snapshot in snapshots {
                snapshot.set.weight = snapshot.weight
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
            setError(title: "Couldn’t Update Back-off Sets", message: WorkoutError.saveFailure.description)
            return false
        }
    }

    // MARK: - Completion & Expansion

    func toggleExerciseCompletion(_ exercise: Exercise) {
        if completedExercises.contains(exercise.id) {
            completedExercises.remove(exercise.id)
        } else {
            completedExercises.insert(exercise.id)
        }
    }

    func isExerciseCompleted(_ exercise: Exercise) -> Bool {
        completedExercises.contains(exercise.id)
    }

    func toggleExerciseExpansion(_ exercise: Exercise) {
        if expandedExercises.contains(exercise.id) {
            expandedExercises.remove(exercise.id)
        } else {
            expandedExercises.insert(exercise.id)
        }
    }

    // MARK: - Rest Timer

    func startRestTimer() {
        currentRestDuration = settingsManager.settings.restTimerDuration
        showingRestTimer = true
    }

    func cancelRestTimer() {
        showingRestTimer = false
    }

    // MARK: - Errors

    func clearError() {
        errorAlertTitle = "Workout Action Failed"
        errorMessage = nil
    }

    private func setError(title: String, message: String) {
        errorAlertTitle = title
        errorMessage = message
    }

    // MARK: - Ordering Helpers

    func orderedSetsForDisplay(in exercise: Exercise) -> [ExerciseSet] {
        orderSetsForDisplay(exerciseGroups[exercise.id] ?? [])
    }

    private func orderSetsForDisplay(_ sets: [ExerciseSet]) -> [ExerciseSet] {
        sets.sorted { lhs, rhs in
            // Warm-ups always lead into the working sets.
            if lhs.isWarmup != rhs.isWarmup {
                return lhs.isWarmup
            }

            // Persisted logged position first — the relationship array
            // itself is unordered across saves.
            if lhs.orderIndex != rhs.orderIndex {
                return lhs.orderIndex < rhs.orderIndex
            }

            if lhs.completedAt != rhs.completedAt {
                return lhs.completedAt < rhs.completedAt
            }

            // Legacy data (all orderIndex == 0, same timestamps): fall back
            // to current array position.
            return setArrayIndex(lhs) < setArrayIndex(rhs)
        }
    }

    private func setArrayIndex(_ set: ExerciseSet) -> Int {
        set.workout?.sets.firstIndex(where: { $0.id == set.id }) ?? Int.max
    }

    private func updateExerciseGroupsAndOrder(maintainOrder: Bool = false) {
        let setsWithExercise = workout.sets.compactMap { set -> (Exercise, ExerciseSet)? in
            guard let exercise = set.exercise else { return nil }
            return (exercise, set)
        }
        exerciseGroups = Dictionary(grouping: setsWithExercise, by: { $0.0.id }).mapValues { $0.map { $0.1 } }

        // Exercises present in the workout, deduplicated in first-appearance order.
        var groupedExercises: [Exercise] = []
        for (exercise, _) in setsWithExercise where !groupedExercises.contains(where: { $0.id == exercise.id }) {
            groupedExercises.append(exercise)
        }

        if maintainOrder {
            let groupKeyIds = Set(exerciseGroups.keys)
            exerciseOrder.removeAll(where: { !groupKeyIds.contains($0.id) })

            for exercise in groupedExercises where !exerciseOrder.contains(where: { $0.id == exercise.id }) {
                exerciseOrder.append(exercise)
            }
        } else {
            // Canonical insertion order avoids unstable ordering when several
            // sets share `.distantPast` completion timestamps.
            exerciseOrder = groupedExercises
        }
    }

    private func rollbackInsertedSet(_ set: ExerciseSet, for exercise: Exercise) {
        exerciseGroups[exercise.id]?.removeAll { $0.id == set.id }

        if exerciseGroups[exercise.id]?.isEmpty == true {
            exerciseGroups.removeValue(forKey: exercise.id)
            exerciseOrder.removeAll { $0.id == exercise.id }
            expandedExercises.remove(exercise.id)
            completedExercises.remove(exercise.id)
        }

        // Linking the set to a persisted workout auto-inserted it into the
        // context, so it must also be deleted there — detaching alone would
        // let the next successful save persist an orphaned row.
        let context = set.modelContext
        workout.sets.removeAll { $0.id == set.id }
        exercise.sets.removeAll { $0.id == set.id }
        set.workout = nil
        set.exercise = nil
        context?.delete(set)
    }

    private func reductionPercentage(forSetIndex setIndex: Int) -> Double {
        let settingsDrops = settingsManager.settings.defaultRPTPercentageDrops

        if setIndex < settingsDrops.count {
            return settingsDrops[setIndex]
        }

        // Past the configured drops, keep the deepest configured drop.
        return settingsDrops.last ?? 0.1
    }
}
