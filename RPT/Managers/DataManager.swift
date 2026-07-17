//
//  DataManager.swift
//  RPT
//
//  Created by Michael Moore on 4/28/25.
//

import Foundation
import SwiftData

@MainActor
protocol DataManaging {
    func getModelContext() -> ModelContext
    func saveChanges() throws
}

@MainActor
class DataManager: DataManaging {
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
                for template in TemplateManager.makeDefaultTemplates() {
                    modelContext.insert(template)
                }
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
        case fetchFailed
        case invalidData

        var description: String {
            switch self {
            case .saveFailed: return "Failed to save changes to database"
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
    
}
