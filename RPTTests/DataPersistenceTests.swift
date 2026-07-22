//
//  DataPersistenceTests.swift
//  RPTTests
//
//  Created by Michael Moore on 5/2/25.
//

import XCTest
import SwiftData
@testable import RPT

@MainActor
final class DataPersistenceTests: XCTestCase {
    private enum TestContainerError: Error {
        case persistentStoreUnavailable
        case defaultDataUnavailable
    }

    // This test will create a separate test-only ModelContainer
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() async throws {
        // Create an in-memory container for testing
        let schema = Schema([
            Exercise.self,
            Workout.self,
            ExerciseSet.self,
            WorkoutTemplate.self,
            UserSettings.self,
            User.self
        ])
        
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true
        )
        
        modelContainer = try ModelContainer(for: schema, configurations: configuration)
        modelContext = modelContainer.mainContext
    }
    
    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - Persistence Tests
    
    func testWorkoutPersistence() throws {
        // 1. Create a workout
        let workout = Workout(name: "Persistence Test Workout")
        let exercise = Exercise(name: "Test Exercise", category: .compound, primaryMuscleGroups: [.abs])
        
        // Add the exercise to the context
        modelContext.insert(exercise)
        
        // Add the workout to the context
        modelContext.insert(workout)
        
        // Add sets to the workout
        _ = workout.addSet(exercise: exercise, weight: 225, reps: 5)
        _ = workout.addSet(exercise: exercise, weight: 205, reps: 6)
        
        // Save changes
        try modelContext.save()
        
        // 2. Verify workout was saved
        let descriptor = FetchDescriptor<Workout>()
        let workouts = try modelContext.fetch(descriptor)
        
        XCTAssertEqual(workouts.count, 1, "One workout should be saved")
        XCTAssertEqual(workouts[0].name, "Persistence Test Workout", "Workout name should match")
        XCTAssertEqual(workouts[0].sets.count, 2, "Workout should have 2 sets")
        
        // 3. Verify the total volume is calculated correctly
        let expectedVolume: Double = 225.0 * 5.0 + 205.0 * 6.0
        XCTAssertEqual(workouts[0].totalVolume, expectedVolume, "Total volume should be calculated correctly")
    }
    
    func testUserPersistence() throws {
        // 1. Create a user
        let user = User(
            username: "PersistenceTestUser",
            email: "persist@test.com",
            height: 70.0,
            weight: 170.0
        )
        
        // Add user to context
        modelContext.insert(user)
        
        // Save changes
        try modelContext.save()
        
        // 2. Verify user was saved
        let descriptor = FetchDescriptor<User>()
        let users = try modelContext.fetch(descriptor)
        
        XCTAssertEqual(users.count, 1, "One user should be saved")
        XCTAssertEqual(users[0].username, "PersistenceTestUser", "Username should match")
        XCTAssertEqual(users[0].height, 70.0, "Height should match")
        XCTAssertEqual(users[0].weight, 170.0, "Weight should match")
        
        // 3. Update user stats
        let workout = Workout(name: "Stats Test")
        let exercise = Exercise(name: "Stats Exercise", category: .compound, primaryMuscleGroups: [.abs])
        modelContext.insert(exercise)
        modelContext.insert(workout)
        
        _ = workout.addSet(exercise: exercise, weight: 100, reps: 10) // 1000 volume
        
        users[0].updateStats(with: workout)
        
        // Save changes again
        try modelContext.save()
        
        // 4. Verify stats were updated
        let updatedUsers = try modelContext.fetch(descriptor)
        XCTAssertEqual(updatedUsers[0].totalVolume, 1000.0, "Total volume should be updated")
        XCTAssertEqual(updatedUsers[0].totalWorkouts, 1, "Total workouts should be updated")
    }
    
    func testDataPersistenceAfterReload() throws {
        // This test simulates app restart by creating a new context with the same container
        
        // 1. Insert data in the first context
        let workout = Workout(name: "Reload Test")
        let exercise = Exercise(name: "Reload Exercise", category: .compound, primaryMuscleGroups: [.abs])
        
        modelContext.insert(exercise)
        modelContext.insert(workout)
        _ = workout.addSet(exercise: exercise, weight: 100, reps: 5)
        
        try modelContext.save()
        
        // 2. Create a new context from the same container (simulating app restart)
        let newContext = modelContainer.mainContext
        
        // 3. Verify data is still accessible in the new context
        let descriptor = FetchDescriptor<Workout>()
        let workouts = try newContext.fetch(descriptor)
        
        XCTAssertEqual(workouts.count, 1, "Workout should persist in new context")
        XCTAssertEqual(workouts[0].name, "Reload Test", "Workout name should match in new context")
        XCTAssertEqual(workouts[0].sets.count, 1, "Workout sets should persist in new context")
        
        // 4. Verify exercise persists too
        let exerciseDescriptor = FetchDescriptor<Exercise>()
        let exercises = try newContext.fetch(exerciseDescriptor)
        
        XCTAssertGreaterThanOrEqual(exercises.count, 1, "Exercise should persist in new context")
        XCTAssertTrue(exercises.contains(where: { $0.name == "Reload Exercise" }), "Exercise name should match in new context")
    }
    
    // MARK: - Data Manager Storage State

    func testDataManagerSharedContainerUsesPersistentStore() {
        let manager = DataManager.shared

        XCTAssertFalse(manager.isUsingTemporaryStore)
        XCTAssertNil(manager.persistenceFailure)
        XCTAssertNotNil(manager.getSharedModelContainer())
    }

    func testDataManagerPersistentFailureCreatesExplicitBlockedTemporaryState() throws {
        var containerCreationAttempts = 0
        let manager = DataManager(
            containerFactory: { schema, configuration in
                containerCreationAttempts += 1

                if containerCreationAttempts == 1 {
                    throw TestContainerError.persistentStoreUnavailable
                }

                return try ModelContainer(for: schema, configurations: configuration)
            },
            seedDefaultData: false
        )

        XCTAssertEqual(containerCreationAttempts, 2)
        XCTAssertTrue(manager.isUsingTemporaryStore)
        XCTAssertEqual(
            manager.persistenceFailure?.technicalDescription,
            String(describing: TestContainerError.persistentStoreUnavailable)
        )

        let exerciseCount = try manager.getModelContext().fetchCount(FetchDescriptor<Exercise>())
        XCTAssertEqual(exerciseCount, 0, "The recovery store must not be seeded as a usable replacement")
    }

    func testDataManagerDefaultDataFailureCreatesExplicitBlockedState() {
        let manager = DataManager(
            containerFactory: { schema, _ in
                let configuration = ModelConfiguration(
                    isStoredInMemoryOnly: true,
                    allowsSave: true
                )
                return try ModelContainer(for: schema, configurations: configuration)
            },
            seedDefaultData: true,
            defaultDataInitializer: { _ in
                throw TestContainerError.defaultDataUnavailable
            }
        )

        XCTAssertFalse(manager.isUsingTemporaryStore)
        XCTAssertTrue(manager.hasPersistenceFailure)
        XCTAssertEqual(
            manager.persistenceFailure?.technicalDescription,
            String(describing: TestContainerError.defaultDataUnavailable)
        )
    }

    func testTemplateManagerCanStillSeedAnInjectedTestContainer() {
        let dataManager = DataManager(
            containerFactory: { schema, _ in
                let configuration = ModelConfiguration(
                    isStoredInMemoryOnly: true,
                    allowsSave: true
                )
                return try ModelContainer(for: schema, configurations: configuration)
            },
            seedDefaultData: false
        )
        let exerciseManager = ExerciseManager(dataManager: dataManager)

        let unseededManager = TemplateManager(
            dataManager: dataManager,
            exerciseManager: exerciseManager,
            seedDefaultTemplates: false
        )
        XCTAssertTrue(unseededManager.fetchAllTemplates().isEmpty)

        let seededManager = TemplateManager(
            dataManager: dataManager,
            exerciseManager: exerciseManager,
            seedDefaultTemplates: true
        )
        XCTAssertEqual(seededManager.fetchAllTemplates().count, 3)
    }
}
