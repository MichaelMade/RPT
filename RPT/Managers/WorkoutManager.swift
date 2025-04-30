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
            name: name,
            startedFromTemplate: templateName
        )
        
        modelContext.insert(workout)
        try? modelContext.save()
        
        return workout
    }
    
    // Save a workout
    func saveWorkout(_ workout: Workout) {
        // Calculate workout duration if not already set
        if workout.duration == 0 {
            workout.duration = Date().timeIntervalSince(workout.date)
        }
        
        try? modelContext.save()
    }
    
    // Complete a workout
    func completeWorkout(_ workout: Workout) {
        workout.complete()
        
        // Process for user stats and achievements
        userManager.processCompletedWorkout(workout)
        
        try? modelContext.save()
    }
    
    // Delete a workout
    func deleteWorkout(_ workout: Workout) {
        modelContext.delete(workout)
        try? modelContext.save()
    }
    
    // MARK: - Workout Exercise & Set Management
    
    // Add an exercise to a workout
    func addExercise(to workout: Workout, exercise: Exercise) -> ExerciseSet {
        let newSet = ExerciseSet(
            weight: 0,
            reps: 8,
            exercise: exercise,
            workout: workout
        )
        
        workout.sets.append(newSet)
        try? modelContext.save()
        
        return newSet
    }
    
    // Add a set to an exercise in a workout
    func addSet(to workout: Workout, for exercise: Exercise, weight: Double, reps: Int, isWarmup: Bool = false, rpe: Int? = nil) -> ExerciseSet {
        let newSet = ExerciseSet(
            weight: weight,
            reps: reps,
            exercise: exercise,
            workout: workout,
            isWarmup: isWarmup,
            rpe: rpe
        )
        
        workout.sets.append(newSet)
        try? modelContext.save()
        
        return newSet
    }
    
    // Update a set
    func updateSet(_ set: ExerciseSet, weight: Double, reps: Int, rpe: Int?) {
        set.weight = weight
        set.reps = reps
        set.rpe = rpe
        
        // Only update completedAt if this is the first time setting weight
        if set.weight == 0 && weight > 0 {
            set.completedAt = Date()
        }
        
        try? modelContext.save()
    }
    
    // Delete a set
    func deleteSet(_ set: ExerciseSet) {
        modelContext.delete(set)
        try? modelContext.save()
    }
    
    // Remove an exercise from a workout (removes all sets)
    func removeExercise(_ exercise: Exercise, from workout: Workout) {
        // Find and delete all sets for this exercise in the workout
        workout.sets.removeAll { $0.exercise?.id == exercise.id }
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
            let exerciseSets = workout.sets.filter {
                $0.exercise?.id == exercise.id
            }.sorted {
                $0.completedAt < $1.completedAt
            }
            
            if !exerciseSets.isEmpty {
                result.append((workout: workout, sets: exerciseSets))
            }
        }
        
        return result
    }
    
    // MARK: - RPT Functions
    
    // Calculate weights for reverse pyramid training
    func calculateRPTWeights(firstSetWeight: Double, percentageDrops: [Double]) -> [Double] {
        percentageDrops.map { firstSetWeight * (1.0 - $0) }
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
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        case .month:
            startDate = Calendar.current.date(byAdding: .month, value: -1, to: now)!
        case .year:
            startDate = Calendar.current.date(byAdding: .year, value: -1, to: now)!
        case .allTime:
            startDate = Date.distantPast
        }
        
        let workouts = getWorkouts(from: startDate, to: now)
        
        let count = workouts.count
        let totalVolume = workouts.reduce(0) { $0 + $1.totalVolume }
        let totalDuration = workouts.reduce(0) { $0 + $1.duration }
        
        let averageDuration = count > 0 ? totalDuration / Double(count) : 0
        
        return (count, totalVolume, averageDuration)
    }
    
    // Get formatted weight value
    func formatWeight(_ weight: Double) -> String {
        return String(format: "%.1f lb", weight)
    }
    
    // Get formatted volume
    func formatVolume(_ volume: Double) -> String {
        if volume > 1000 {
            return String(format: "%.1fk lb", volume / 1000)
        } else {
            return String(format: "%.1f lb", volume)
        }
    }
    
    // Calculate workout statistics with proper formatting
    func calculateWorkoutStatsFormatted(timeframe: TimeFrame) -> (count: Int, totalVolume: String, averageDuration: String) {
        let stats = calculateWorkoutStats(timeframe: timeframe)
        
        // Format duration
        let durationMinutes = Int(stats.averageDuration / 60)
        let durationSeconds = Int(stats.averageDuration.truncatingRemainder(dividingBy: 60))
        let formattedDuration = String(format: "%d:%02d", durationMinutes, durationSeconds)
        
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
