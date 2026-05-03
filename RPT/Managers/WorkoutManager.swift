//
//  WorkoutManager.swift
//  RPT
//
//  Created by Michael Moore on 4/28/25.
//

import SwiftUI
import SwiftData

@MainActor
class WorkoutManager: ObservableObject {
    private let modelContext: ModelContext
    private let userManager: UserManager
    static let shared = WorkoutManager()
    
    private init() {
        let dataManager = DataManager.shared
        self.modelContext = dataManager.getModelContext()
        self.userManager = UserManager.shared
    }
    
    // MARK: - Workout CRUD Operations
    
    // Create a new workout
    func createWorkout(name: String = "Workout", fromTemplate templateName: String? = nil) -> Workout {
        let workout = Workout(
            name: sanitizedWorkoutName(name),
            startedFromTemplate: templateName
        )
        
        modelContext.insert(workout)
        try? modelContext.save()
        
        return workout
    }
    
    // Save a workout
    func saveWorkout(_ workout: Workout) throws {
        workout.name = sanitizedWorkoutName(workout.name)
        workout.duration = sanitizedDurationForSave(
            isCompleted: workout.isCompleted,
            existingDuration: workout.duration,
            startDate: workout.date
        )

        try modelContext.save()
    }

    func sanitizedDurationSinceWorkoutStart(_ startDate: Date, now: Date = Date()) -> TimeInterval {
        let rawDuration = now.timeIntervalSince(startDate)
        return rawDuration.isFinite ? max(0, rawDuration) : 0
    }

    func sanitizedDurationForSave(
        isCompleted: Bool,
        existingDuration: TimeInterval,
        startDate: Date,
        now: Date = Date()
    ) -> TimeInterval {
        let safeExistingDuration = existingDuration.isFinite ? max(0, existingDuration) : 0

        guard isCompleted else {
            return 0
        }

        if safeExistingDuration > 0 {
            return safeExistingDuration
        }

        return sanitizedDurationSinceWorkoutStart(startDate, now: now)
    }

    func sanitizedWorkoutName(_ name: String) -> String {
        let collapsedName = name
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedName.isEmpty else { return "Workout" }
        return String(collapsedName.prefix(80))
    }
    
    // Non-throwing version for backward compatibility
    func saveWorkoutSafely(_ workout: Workout) -> Bool {
        do {
            try saveWorkout(workout)
            return true
        } catch {
            print("Failed to save workout: \(error)")
            return false
        }
    }
    
    // Complete a workout
    func completeWorkout(_ workout: Workout) throws {
        workout.complete()
        userManager.processCompletedWorkout(workout)
        try modelContext.save()
    }
    
    // Non-throwing version for backward compatibility
    func completeWorkoutSafely(_ workout: Workout) -> Bool {
        do {
            try completeWorkout(workout)
            return true
        } catch {
            print("Failed to complete workout: \(error)")
            return false
        }
    }
    
    // Delete a workout
    func deleteWorkout(_ workout: Workout) throws {
        modelContext.delete(workout)
        try modelContext.save()
    }
    
    // Non-throwing version for backward compatibility
    func deleteWorkoutSafely(_ workout: Workout) -> Bool {
        do {
            try deleteWorkout(workout)
            return true
        } catch {
            print("Failed to delete workout: \(error)")
            return false
        }
    }
    
    // MARK: - Workout Exercise & Set Management
    
    // Add an exercise to a workout
    func addExercise(to workout: Workout, exercise: Exercise) -> ExerciseSet {
        let newSet = ExerciseSet(
            weight: 0,
            reps: 8,
            exercise: exercise,
            workout: workout,
            completedAt: .distantPast
        )
        
        workout.sets.append(newSet)
        try? modelContext.save()
        
        return newSet
    }
    
    // Add a set to an exercise in a workout
    func addSet(to workout: Workout, for exercise: Exercise, weight: Int, reps: Int, isWarmup: Bool = false, rpe: Int? = nil) -> ExerciseSet {
        let sanitized = sanitizedSetInput(weight: weight, reps: reps, rpe: rpe)

        let isComplete = ExerciseSet.hasCompletedValues(
            weight: sanitized.weight,
            reps: sanitized.reps,
            exerciseCategory: exercise.category
        )

        let newSet = ExerciseSet(
            weight: sanitized.weight,
            reps: sanitized.reps,
            exercise: exercise,
            workout: workout,
            completedAt: isComplete ? Date() : .distantPast,
            isWarmup: isWarmup,
            rpe: sanitized.rpe
        )
        
        workout.sets.append(newSet)
        try? modelContext.save()
        
        return newSet
    }
    
    // Update a set
    func updateSet(_ set: ExerciseSet, weight: Int, reps: Int, rpe: Int?) {
        let sanitized = sanitizedSetInput(weight: weight, reps: reps, rpe: rpe)
        let wasIncomplete = !set.hasCompletedValues || set.completedAt == .distantPast

        set.weight = sanitized.weight
        set.reps = sanitized.reps
        set.rpe = sanitized.rpe

        // Keep completion timestamps aligned with completion state
        let isComplete = ExerciseSet.hasCompletedValues(
            weight: sanitized.weight,
            reps: sanitized.reps,
            exerciseCategory: set.exercise?.category
        )
        if !isComplete {
            set.completedAt = .distantPast
        } else if wasIncomplete {
            set.completedAt = Date()
        }

        try? modelContext.save()
    }

    func sanitizedSetInput(weight: Int, reps: Int, rpe: Int?) -> (weight: Int, reps: Int, rpe: Int?) {
        let safeWeight = max(0, weight)
        let safeReps = max(0, reps)

        let safeRPE: Int?
        if let rpe {
            safeRPE = (1...10).contains(rpe) ? rpe : nil
        } else {
            safeRPE = nil
        }

        return (safeWeight, safeReps, safeRPE)
    }
    
    // Delete a set
    func deleteSet(_ set: ExerciseSet) {
        modelContext.delete(set)
        try? modelContext.save()
    }
    
    // Remove an exercise from a workout (removes all sets)
    func removeExercise(_ exercise: Exercise, from workout: Workout) {
        let exerciseId = exercise.id
        let setsToRemove = workout.sets.filter { $0.exercise?.id == exerciseId }
        for set in setsToRemove {
            modelContext.delete(set)
        }
        workout.sets.removeAll { $0.exercise?.id == exerciseId }
        try? modelContext.save()
    }
    
    // MARK: - Workout Queries
    
    // Get recent workouts
    func getRecentWorkouts(limit: Int = 10) -> [Workout] {
        var descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // Get incomplete workouts (saved but not yet completed)
    func getIncompleteWorkouts() -> [Workout] {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { !$0.isCompleted },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // Get workouts by date range
    func getWorkouts(from startDate: Date, to endDate: Date) -> [Workout] {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> {
                $0.date >= startDate && $0.date <= endDate
            },
            sortBy: [SortDescriptor(\.date)]
        )
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // Find workout by ID
    func getWorkout(id: PersistentIdentifier) -> Workout? {
        return modelContext.model(for: id) as? Workout
    }
    
    // Get workout history for specific exercise
    func getWorkoutHistory(for exercise: Exercise) -> [(workout: Workout, sets: [ExerciseSet])] {
        // Fetch all workouts
        let workoutDescriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        guard let allWorkouts = try? modelContext.fetch(workoutDescriptor) else { return [] }
        
        // Filter workouts containing this exercise
        var result: [(workout: Workout, sets: [ExerciseSet])] = []
        
        for workout in allWorkouts {
            let exerciseSets = workout.orderedSets(for: exercise)

            if !exerciseSets.isEmpty {
                result.append((workout: workout, sets: exerciseSets))
            }
        }
        
        return result
    }
    
    // MARK: - RPT Functions
    
    // Calculate weights for reverse pyramid training
    func calculateRPTWeights(firstSetWeight: Double, percentageDrops: [Double]) -> [Double] {
        let safeFirstSetWeight = firstSetWeight.isFinite ? max(0, firstSetWeight) : 0
        var previousDrop = 0.0

        return percentageDrops.map { drop in
            let clampedDrop = drop.isFinite ? min(max(drop, 0), 1) : 0
            let monotonicDrop = max(previousDrop, clampedDrop)
            previousDrop = monotonicDrop
            return safeFirstSetWeight * (1.0 - monotonicDrop)
        }
    }
    
    // Get default RPT percentage drops
    func getDefaultRPTPercentageDrops() -> [Double] {
        let settingsManager = SettingsManager.shared
        return settingsManager.settings.defaultRPTPercentageDrops
    }
    
    // MARK: - Workout Statistics
    
    // Calculate workout statistics by timeframe
    func calculateWorkoutStats(timeframe: TimeFrame) -> (count: Int, totalVolume: Double, averageDuration: TimeInterval) {
        let now = Date()
        var startDate: Date
        
        switch timeframe {
        case .week:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? Date.distantPast
        case .month:
            startDate = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? Date.distantPast
        case .year:
            startDate = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? Date.distantPast
        case .allTime:
            startDate = Date.distantPast
        }
        
        let workouts = getWorkouts(from: startDate, to: now)
        return aggregateCompletedWorkoutStats(from: workouts)
    }

    // Aggregate statistics from workouts, excluding in-progress sessions
    func aggregateCompletedWorkoutStats(from workouts: [Workout]) -> (count: Int, totalVolume: Double, averageDuration: TimeInterval) {
        let completedWorkouts = workouts.filter { $0.isCompleted }

        let count = completedWorkouts.count
        let totalVolume = completedWorkouts.reduce(0.0) { partial, workout in
            let safeVolume = workout.totalVolume.isFinite ? max(0, workout.totalVolume) : 0
            return partial + safeVolume
        }

        let validDurations = completedWorkouts.compactMap { sanitizedCompletedWorkoutDuration($0) }
        let totalDuration = validDurations.reduce(0.0, +)
        let averageDuration = validDurations.isEmpty ? 0 : totalDuration / Double(validDurations.count)

        return (count, totalVolume, averageDuration)
    }
    
    // Get formatted weight value
    func formatWeight(_ weight: Double) -> String {
        let safeWeight = weight.isFinite ? max(0, weight) : 0
        return String(format: "%.1f lb", safeWeight)
    }
    
    // Round to nearest 5 pounds
    func roundToNearest5(_ weight: Double) -> Int {
        let safeWeight = weight.isFinite ? max(0, weight) : 0
        return Int((safeWeight / 5.0).rounded() * 5.0)
    }
    
    // Get formatted volume
    func formatVolume(_ volume: Double) -> String {
        let safeVolume = volume.isFinite ? max(0, volume) : 0
        let truncatedVolume = floor(safeVolume * 10) / 10

        if truncatedVolume >= 1_000_000 {
            let millions = truncatedVolume / 1_000_000
            let truncatedMillions = floor(millions * 10) / 10
            let isWholeMillions = truncatedMillions.truncatingRemainder(dividingBy: 1) == 0

            return isWholeMillions
                ? "\(Int(truncatedMillions))M lb"
                : String(format: "%.1fM lb", truncatedMillions)
        }

        if truncatedVolume >= 1000 {
            let thousands = truncatedVolume / 1000
            let truncatedThousands = floor(thousands * 10) / 10
            let isWholeThousands = truncatedThousands.truncatingRemainder(dividingBy: 1) == 0

            return isWholeThousands
                ? "\(Int(truncatedThousands))k lb"
                : String(format: "%.1fk lb", truncatedThousands)
        }

        let isWholeNumber = truncatedVolume.truncatingRemainder(dividingBy: 1) == 0
        return isWholeNumber
            ? "\(Int(truncatedVolume)) lb"
            : String(format: "%.1f lb", truncatedVolume)
    }
    
    func sanitizedCompletedWorkoutDuration(_ workout: Workout) -> TimeInterval? {
        guard workout.isCompleted else {
            return nil
        }

        let safeDuration = workout.duration.isFinite ? max(0, workout.duration) : 0
        return safeDuration > 0 ? safeDuration : nil
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let safeDuration = duration.isFinite ? max(0, duration) : 0
        let totalSeconds = Int(floor(safeDuration))

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            if seconds > 0 {
                return "\(hours)h \(minutes)m \(seconds)s"
            }

            return "\(hours)h \(minutes)m"
        }

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }

        return "\(seconds)s"
    }

    // Calculate workout statistics with proper formatting
    func calculateWorkoutStatsFormatted(timeframe: TimeFrame) -> (count: Int, totalVolume: String, averageDuration: String) {
        let stats = calculateWorkoutStats(timeframe: timeframe)

        // Format duration
        let formattedDuration = formatDuration(stats.averageDuration)

        // Format volume
        let formattedVolume = formatVolume(stats.totalVolume)

        return (stats.count, formattedVolume, formattedDuration)
    }
    
    // Time frame enum for statistics
    enum TimeFrame {
        case week
        case month
        case year
        case allTime
    }
}
