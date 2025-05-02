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
            // Step 1: Define the store URL, but don't delete it
            // Removing this code that was deleting the database on every launch
            // let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
            // try? FileManager.default.removeItem(at: storeURL)
            
            // Step 2: Define the schema
            let schema = Schema([
                Exercise.self,
                Workout.self,
                ExerciseSet.self,
                WorkoutTemplate.self,
                UserSettings.self,
                User.self
            ])
            
            // Step 3: Configure the model
            let modelConfiguration = ModelConfiguration(
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            // Step 4: Create the container
            self.modelContainer = try ModelContainer(for: schema, configurations: modelConfiguration)
            self.modelContext = self.modelContainer.mainContext
            
            // Step 5: Initialize default data
            initializeDefaultData()
        } catch {
            print("SwiftData Error: \(error)")
            
            // Step 6: If we can't create the container, try with in-memory storage
            do {
                let schema = Schema([
                    Exercise.self,
                    Workout.self,
                    ExerciseSet.self,
                    WorkoutTemplate.self,
                    UserSettings.self,
                    User.self
                ])
                
                let memoryConfig = ModelConfiguration(
                    isStoredInMemoryOnly: true, // Use in-memory as a fallback
                    allowsSave: true
                )
                
                self.modelContainer = try ModelContainer(for: schema, configurations: memoryConfig)
                self.modelContext = self.modelContainer.mainContext
                
                // Initialize default data
                initializeDefaultData()
            } catch {
                fatalError("Critical failure: Could not create ModelContainer in memory mode. Error: \(error)")
            }
        }
    }
    
    // MARK: - Context Access
    
    func getModelContext() -> ModelContext {
        return modelContext
    }
    
    func getSharedModelContainer() -> ModelContainer {
        return modelContainer
    }
    
    // MARK: - Data Initialization
    
    private func initializeDefaultData() {
        do {
            try initializeSettings()
            try initializeExercises()
            try initializeTemplates()
        } catch {
            print("Error initializing default data: \(error)")
        }
    }
    
    private func initializeSettings() throws {
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        
        do {
            let count = try modelContext.fetchCount(descriptor)
            if count == 0 {
                let defaultSettings = UserSettings()
                modelContext.insert(defaultSettings)
                try saveChanges()
            }
        } catch {
            print("Error initializing settings: \(error)")
            throw DataError.saveFailed
        }
    }
    
    private func initializeExercises() throws {
        var descriptor = FetchDescriptor<Exercise>()
        descriptor.fetchLimit = 1
        
        do {
            // Check if any exercises exist
            let count = try modelContext.fetchCount(descriptor)
            if count > 0 {
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
            
            try saveChanges()
        } catch {
            print("Error initializing exercises: \(error)")
            throw DataError.saveFailed
        }
    }
    
    private func initializeTemplates() throws {
        var descriptor = FetchDescriptor<WorkoutTemplate>()
        descriptor.fetchLimit = 1
        
        do {
            let count = try modelContext.fetchCount(descriptor)
            if count == 0 {
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
                        ),
                        TemplateExercise(
                            exerciseName: "Pull-up",
                            suggestedSets: 3,
                            repRanges: [
                                TemplateRepRange(setNumber: 1, minReps: 6, maxReps: 8, percentageOfFirstSet: 1.0),
                                TemplateRepRange(setNumber: 2, minReps: 8, maxReps: 10, percentageOfFirstSet: 0.9),
                                TemplateRepRange(setNumber: 3, minReps: 10, maxReps: 12, percentageOfFirstSet: 0.8)
                            ],
                            notes: "Add weight if needed"
                        )
                    ],
                    notes: "Upper body RPT workout focusing on strength"
                )
                
                modelContext.insert(upperBodyRPT)
                try saveChanges()
            }
        } catch {
            print("Error initializing templates: \(error)")
            throw DataError.saveFailed
        }
    }
    
    // MARK: - CRUD Operations
    
    enum DataError: Error {
        case saveFailed
        case exportFailed
        case importFailed
        case fetchFailed
        case invalidData
        
        var description: String {
            switch self {
            case .saveFailed: return "Failed to save changes to database"
            case .exportFailed: return "Failed to export data"
            case .importFailed: return "Failed to import data"
            case .fetchFailed: return "Failed to fetch data"
            case .invalidData: return "Data is invalid or corrupted"
            }
        }
    }
    
    func saveChanges() throws {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save changes: \(error)")
            throw DataError.saveFailed
        }
    }
    
    // Safe version that doesn't throw (for backward compatibility)
    func saveChangesSafely() -> Bool {
        do {
            try saveChanges()
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Data Export/Import
    
    func exportData() throws -> Data {
        // Implementation for data export functionality
        do {
            // Replace with actual implementation
            throw DataError.exportFailed
        } catch {
            throw DataError.exportFailed
        }
    }
    
    func importData(from data: Data) throws -> Bool {
        // Implementation for data import functionality
        do {
            // Replace with actual implementation
            throw DataError.importFailed
        } catch {
            throw DataError.importFailed
        }
    }
    
    // MARK: - Common Queries
    
    func fetchRecentWorkouts(limit: Int = 5) throws -> [Workout] {
        var descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching recent workouts: \(error)")
            throw DataError.fetchFailed
        }
    }
    
    // Non-throwing version for backward compatibility
    func fetchRecentWorkoutsSafely(limit: Int = 5) -> [Workout] {
        do {
            return try fetchRecentWorkouts(limit: limit)
        } catch {
            return []
        }
    }
    
    func findExercise(byName name: String) throws -> Exercise? {
        var descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate<Exercise> { $0.name == name }
        )
        descriptor.fetchLimit = 1
        
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("Error finding exercise by name: \(error)")
            throw DataError.fetchFailed
        }
    }
    
    // Non-throwing version for backward compatibility
    func findExerciseSafely(byName name: String) -> Exercise? {
        do {
            return try findExercise(byName: name)
        } catch {
            return nil
        }
    }
    
    func fetchExerciseSets(for exercise: Exercise, timeFrame: DateInterval? = nil) throws -> [ExerciseSet] {
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
            throw DataError.fetchFailed
        }
    }
    
    // Non-throwing version for backward compatibility
    func fetchExerciseSetsSafely(for exercise: Exercise, timeFrame: DateInterval? = nil) -> [ExerciseSet] {
        do {
            return try fetchExerciseSets(for: exercise, timeFrame: timeFrame)
        } catch {
            return []
        }
    }
    
    // MARK: - Data Analysis
    
    func calculateVolumeProgress(for exercise: Exercise, over timeFrame: DateInterval? = nil) throws -> [(date: Date, value: Double)] {
        let sets: [ExerciseSet]
        
        do {
            sets = try fetchExerciseSets(for: exercise, timeFrame: timeFrame)
        } catch {
            throw error
        }
        
        // Group by day
        let calendar = Calendar.current
        let groupedByDay = Dictionary(grouping: sets) { set in
            calendar.startOfDay(for: set.completedAt)
        }
        
        // Calculate daily volume
        return groupedByDay.map { (date, sets) in
            let dailyVolume = sets.reduce(0) { $0 + (Double($1.weight) * Double($1.reps)) }
            return (date: date, value: dailyVolume)
        }.sorted { $0.date < $1.date }
    }
    
    // Non-throwing version for backward compatibility
    func calculateVolumeProgressSafely(for exercise: Exercise, over timeFrame: DateInterval? = nil) -> [(date: Date, value: Double)] {
        do {
            return try calculateVolumeProgress(for: exercise, over: timeFrame)
        } catch {
            return []
        }
    }
    
    func calculateOneRepMax(for exercise: Exercise) throws -> Double {
        let sets: [ExerciseSet]
        
        do {
            sets = try fetchExerciseSets(for: exercise)
        } catch {
            throw error
        }
        
        guard !sets.isEmpty else {
            return 0
        }
        
        // Calculate 1RM for each set using Brzycki formula
        let oneRepMaxes = sets.map { set in
            let reps = min(max(1, set.reps), 10) // Formula less accurate beyond 10 reps
            return Double(set.weight) * (36.0 / (37.0 - Double(reps)))
        }
        
        // Return the highest estimated 1RM
        return oneRepMaxes.max() ?? 0
    }
    
    // Non-throwing version for backward compatibility
    func calculateOneRepMaxSafely(for exercise: Exercise) -> Double {
        do {
            return try calculateOneRepMax(for: exercise)
        } catch {
            return 0
        }
    }
}
