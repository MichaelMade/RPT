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
final class DataManager: DataManaging {
    typealias ModelContainerFactory = (Schema, ModelConfiguration) throws -> ModelContainer
    typealias DefaultDataInitializer = (ModelContext) throws -> Void

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    /// True only when the on-disk store could not be opened. The temporary
    /// container exists solely so SwiftUI can render StorageUnavailableView;
    /// the app never exposes normal data entry while this is true.
    private(set) var isUsingTemporaryStore: Bool
    private(set) var persistenceFailure: PersistenceFailure?

    var hasPersistenceFailure: Bool {
        persistenceFailure != nil
    }

    static let shared = DataManager(
        containerFactory: { schema, configuration in
            try ModelContainer(for: schema, configurations: configuration)
        },
        seedDefaultData: true
    )

    init(
        containerFactory: ModelContainerFactory,
        seedDefaultData: Bool,
        defaultDataInitializer: DefaultDataInitializer? = nil
    ) {
        let schema = Self.makeSchema()

        do {
            let modelConfiguration = ModelConfiguration(
                isStoredInMemoryOnly: false,
                allowsSave: true
            )

            self.modelContainer = try containerFactory(schema, modelConfiguration)
            self.modelContext = self.modelContainer.mainContext
            self.isUsingTemporaryStore = false
            self.persistenceFailure = nil
        } catch {
            print("SwiftData Error: \(error)")

            // Keep the failed on-disk store untouched. An isolated temporary
            // container lets the app render a blocking recovery screen without
            // pretending that edits are being persisted. SwiftData cannot open
            // an in-memory container read-only, so the app-level block is what
            // prevents this container from receiving user writes.
            do {
                let memoryConfig = ModelConfiguration(
                    isStoredInMemoryOnly: true,
                    allowsSave: true
                )

                self.modelContainer = try containerFactory(schema, memoryConfig)
                self.modelContext = self.modelContainer.mainContext
                self.isUsingTemporaryStore = true
                self.persistenceFailure = PersistenceFailure(
                    technicalDescription: String(describing: error)
                )
            } catch let temporaryStoreError {
                fatalError(
                    "Critical failure: Could not create the recovery ModelContainer. "
                        + "Error: \(temporaryStoreError)"
                )
            }
        }

        if seedDefaultData && !hasPersistenceFailure {
            do {
                if let defaultDataInitializer {
                    try defaultDataInitializer(modelContext)
                } else {
                    try initializeDefaultData()
                }
            } catch {
                // A container that opens but cannot complete its first reads
                // or writes is not safe to expose as a working store.
                persistenceFailure = PersistenceFailure(
                    technicalDescription: String(describing: error)
                )
            }
        }
    }

    private static func makeSchema() -> Schema {
        Schema([
            Exercise.self,
            Workout.self,
            ExerciseSet.self,
            WorkoutTemplate.self,
            UserSettings.self,
            User.self
        ])
    }
    
    // MARK: - Context Access
    
    func getModelContext() -> ModelContext {
        return modelContext
    }
    
    func getSharedModelContainer() -> ModelContainer {
        return modelContainer
    }
    
    // MARK: - Data Initialization
    
    private func initializeDefaultData() throws {
        try initializeSettings()
        try initializeExercises()
        try initializeTemplates()
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
