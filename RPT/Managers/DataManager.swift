//
//  DataManager.swift
//  RPT
//
//  Created by Michael Moore on 4/28/25.
//

import Foundation
import SwiftData

@MainActor
class DataManager {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    
    // Shared instance for app-wide use
    static let shared = DataManager()
    
    private init() {
        do {
            let schema = Schema([
                Exercise.self,
                Workout.self,
                ExerciseSet.self,
                WorkoutTemplate.self,
                UserSettings.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            self.modelContainer = try ModelContainer(for: schema, configurations: modelConfiguration)
            self.modelContext = self.modelContainer.mainContext
            
            // Initialize default data if needed
            initializeDefaultData()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    // MARK: - Context Access
    
    func getModelContext() -> ModelContext {
        return modelContext
    }
    
    // MARK: - Data Initialization
    
    private func initializeDefaultData() {
        initializeSettings()
        initializeExercises()
        initializeTemplates()
    }
    
    private func initializeSettings() {
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        
        if let count = try? modelContext.fetchCount(descriptor), count == 0 {
            let defaultSettings = UserSettings()
            modelContext.insert(defaultSettings)
            saveChanges()
        }
    }
    
    private func initializeExercises() {
        var descriptor = FetchDescriptor<Exercise>()
        descriptor.fetchLimit = 1
        
        // Check if any exercises exist
        if let count = try? modelContext.fetchCount(descriptor), count > 0 {
            return // Exercises already exist
        }
        
        // Create default exercises
        let defaultExercises: [(String, ExerciseCategory, [MuscleGroup], [MuscleGroup], String)] = [
            // Compound exercises
            ("Barbell Bench Press", .compound, [.chest], [.triceps, .shoulders], "Lie on a bench and press the barbell from chest to full extension."),
            ("Barbell Squat", .compound, [.quadriceps], [.glutes, .hamstrings, .lowerBack], "Place bar on upper back, squat down until thighs are parallel to floor, then stand up."),
            ("Deadlift", .compound, [.back, .hamstrings], [.glutes, .quadriceps, .traps, .forearms], "Bend at hips and knees to grab bar, then stand up straight while keeping back flat."),
            ("Overhead Press", .compound, [.shoulders], [.triceps, .traps], "Press barbell from shoulders to overhead with straight arms."),
            ("Pull-up", .compound, [.back], [.biceps, .shoulders], "Hang from bar and pull yourself up until chin is over the bar."),
            ("Barbell Row", .compound, [.back], [.biceps, .shoulders, .traps], "Bend at hips with back flat, pull barbell to lower chest."),
            ("Dip", .compound, [.chest, .triceps], [.shoulders], "Support yourself on parallel bars, lower body until upper arms are parallel to floor, then push up."),
            
            // Isolation exercises
            ("Bicep Curl", .isolation, [.biceps], [.forearms], "Curl weight from full extension to full flexion."),
            ("Tricep Extension", .isolation, [.triceps], [], "Extend arms from flexed position to straight position."),
            ("Leg Extension", .isolation, [.quadriceps], [], "Extend knees from 90 degrees to full extension."),
            ("Leg Curl", .isolation, [.hamstrings], [], "Curl legs from straight position to full flexion."),
            ("Lateral Raise", .isolation, [.shoulders], [], "Raise arms out to sides until parallel with floor."),
            ("Calf Raise", .isolation, [.calves], [], "Raise heels off ground by extending ankles."),
            
            // Bodyweight exercises
            ("Push-up", .bodyweight, [.chest], [.triceps, .shoulders], "Lower body to ground and push back up with arms."),
            ("Body Weight Squat", .bodyweight, [.quadriceps], [.glutes, .hamstrings], "Squat down until thighs are parallel to floor, then stand up."),
            ("Lunge", .bodyweight, [.quadriceps], [.glutes, .hamstrings], "Step forward and lower body until both knees are at 90 degrees, then push back up.")
        ]
        
        for (name, category, primary, secondary, instructions) in defaultExercises {
            let exercise = Exercise(
                name: name,
                category: category,
                primaryMuscleGroups: primary,
                secondaryMuscleGroups: secondary,
                instructions: instructions,
                isCustom: false
            )
            modelContext.insert(exercise)
        }
        
        saveChanges()
    }
    
    private func initializeTemplates() {
        var descriptor = FetchDescriptor<WorkoutTemplate>()
        descriptor.fetchLimit = 1
        
        if let count = try? modelContext.fetchCount(descriptor), count == 0 {
            // Create default templates
            let upperBodyRPT = WorkoutTemplate(
                name: "Upper Body RPT",
                exercises: [
                    TemplateExercise(
                        exerciseName: "Barbell Bench Press",
                        suggestedSets: 3,
                        repRanges: [
                            TemplateRepRange(setNumber: 1, minReps: 4, maxReps: 6, percentageOfFirstSet: 1.0),
                            TemplateRepRange(setNumber: 2, minReps: 6, maxReps: 8, percentageOfFirstSet: 0.9),
                            TemplateRepRange(setNumber: 3, minReps: 8, maxReps: 10, percentageOfFirstSet: 0.8)
                        ],
                        notes: "Focus on chest contraction"
                    )
                ],
                notes: "Upper body RPT workout focusing on strength"
            )
            
            modelContext.insert(upperBodyRPT)
            saveChanges()
        }
    }
    
    // MARK: - CRUD Operations
    
    func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save changes: \(error)")
        }
    }
    
    // MARK: - Data Export/Import
    
    func exportData() -> Data? {
        // Implementation for data export functionality
        return nil
    }
    
    func importData(from data: Data) -> Bool {
        // Implementation for data import functionality
        return false
    }
    
    // MARK: - Common Queries
    
    func fetchRecentWorkouts(limit: Int = 5) -> [Workout] {
        var descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func findExercise(byName name: String) -> Exercise? {
        var descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate<Exercise> { $0.name == name }
        )
        descriptor.fetchLimit = 1
        
        return try? modelContext.fetch(descriptor).first
    }
    
    func fetchExerciseSets(for exercise: Exercise, timeFrame: DateInterval? = nil) -> [ExerciseSet] {
        do {
            // Create basic descriptor and fetch all sets
            let descriptor = FetchDescriptor<ExerciseSet>()
            let allSets = try modelContext.fetch(descriptor)
            
            // Filter in memory
            return allSets.filter { set in
                // Check for exercise match
                guard let setExercise = set.exercise, setExercise.id == exercise.id else { return false }
                
                // Apply timeframe filter if needed
                if let interval = timeFrame {
                    return set.completedAt >= interval.start && set.completedAt <= interval.end
                }
                
                return true
            }.sorted { $0.completedAt < $1.completedAt }
        } catch {
            print("Error fetching exercise sets: \(error)")
            return []
        }
    }
    
    // MARK: - Data Analysis
    
    func calculateVolumeProgress(for exercise: Exercise, over timeFrame: DateInterval? = nil) -> [(date: Date, value: Double)] {
        let sets = fetchExerciseSets(for: exercise, timeFrame: timeFrame)
        
        // Group by day
        let calendar = Calendar.current
        let groupedByDay = Dictionary(grouping: sets) { set in
            calendar.startOfDay(for: set.completedAt)
        }
        
        // Calculate daily volume
        return groupedByDay.map { (date, sets) in
            let dailyVolume = sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
            return (date: date, value: dailyVolume)
        }.sorted { $0.date < $1.date }
    }
    
    func calculateOneRepMax(for exercise: Exercise) -> Double {
        let sets = fetchExerciseSets(for: exercise)
        
        // Calculate 1RM for each set using Brzycki formula
        let oneRepMaxes = sets.map { set in
            let reps = min(max(1, set.reps), 10) // Formula less accurate beyond 10 reps
            return set.weight * (36.0 / (37.0 - Double(reps)))
        }
        
        // Return the highest estimated 1RM
        return oneRepMaxes.max() ?? 0
    }
}
