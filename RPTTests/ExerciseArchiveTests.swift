//
//  ExerciseArchiveTests.swift
//  RPTTests
//
//  Removing a custom exercise from the library must never delete the sets
//  that were logged with it. These tests run against their own in-memory
//  store so they cannot touch, or be affected by, the app's data.
//

import XCTest
import SwiftData
@testable import RPT

@MainActor
final class ExerciseArchiveTests: XCTestCase {
    private final class FailingDataManager: DataManaging {
        private let wrappedContext: ModelContext

        init(context: ModelContext) {
            self.wrappedContext = context
        }

        func getModelContext() -> ModelContext {
            wrappedContext
        }

        func saveChanges() throws {
            throw DataManager.DataError.saveFailed
        }
    }

    private var dataManager: DataManager!
    private var manager: ExerciseManager!

    private var context: ModelContext { dataManager.getModelContext() }

    override func setUp() {
        super.setUp()
        dataManager = DataManager(
            containerFactory: { schema, _ in
                let configuration = ModelConfiguration(
                    isStoredInMemoryOnly: true,
                    allowsSave: true
                )
                return try ModelContainer(for: schema, configurations: configuration)
            },
            seedDefaultData: false
        )
        manager = ExerciseManager(dataManager: dataManager)
    }

    override func tearDown() {
        manager = nil
        dataManager = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    private func insertCustomExercise(named name: String = "Garage Sled Push") -> Exercise {
        let exercise = Exercise(
            name: name,
            category: .compound,
            primaryMuscleGroups: [.quadriceps],
            isCustom: true
        )
        context.insert(exercise)
        return exercise
    }

    /// A finished workout with two logged sets of `exercise`.
    @discardableResult
    private func insertLoggedWorkout(using exercise: Exercise) throws -> Workout {
        let workout = Workout(name: "Leg Day", isCompleted: true)
        context.insert(workout)
        _ = workout.addSet(exercise: exercise, weight: 180, reps: 8)
        _ = workout.addSet(exercise: exercise, weight: 160, reps: 10)
        try context.save()
        return workout
    }

    private func storedExercises() throws -> [Exercise] {
        try context.fetch(FetchDescriptor<Exercise>())
    }

    private func storedSets() throws -> [ExerciseSet] {
        try context.fetch(FetchDescriptor<ExerciseSet>())
    }

    // MARK: - Deleting with history

    func testDeletingExerciseWithLoggedSetsKeepsTheHistory() throws {
        let exercise = insertCustomExercise()
        let workout = try insertLoggedWorkout(using: exercise)

        XCTAssertEqual(manager.deleteExercise(exercise), .success)

        XCTAssertEqual(try storedSets().count, 2, "Logged sets must survive removing their exercise from the library")
        XCTAssertEqual(workout.sets.count, 2)
        XCTAssertEqual(
            workout.sets.map { $0.exercise?.name },
            ["Garage Sled Push", "Garage Sled Push"],
            "History must still be able to name the exercise each set was logged with"
        )
        XCTAssertEqual(workout.totalVolume, 180 * 8 + 160 * 10, accuracy: 0.001)

        let stored = try storedExercises()
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.isArchived, true)
    }

    func testArchivedExerciseLeavesEveryLibraryLookup() throws {
        let exercise = insertCustomExercise()
        try insertLoggedWorkout(using: exercise)

        XCTAssertEqual(manager.deleteExercise(exercise), .success)

        XCTAssertTrue(manager.fetchAllExercises().isEmpty)
        XCTAssertNil(manager.fetchExercise(withName: "Garage Sled Push"))
        XCTAssertNil(manager.fetchExercise(withName: "  garage  sled push "))
        XCTAssertTrue(manager.fetchExercises(byCategory: .compound).isEmpty)
        XCTAssertTrue(manager.fetchExercises(byMuscleGroup: .quadriceps).isEmpty)
        XCTAssertTrue(manager.getMostUsedExercises().isEmpty)
    }

    func testArchivingRemovesPlannedSetsButNotLoggedOnes() throws {
        let exercise = insertCustomExercise()
        try insertLoggedWorkout(using: exercise)

        let draft = Workout(name: "Today")
        context.insert(draft)
        _ = draft.addSet(exercise: exercise, weight: 185, reps: 8)
        _ = draft.addSet(exercise: exercise, weight: 0, reps: 0)
        _ = draft.addSet(exercise: exercise, weight: 0, reps: 0)
        try context.save()

        XCTAssertEqual(manager.deleteExercise(exercise), .success)

        let remaining = try storedSets()
        XCTAssertEqual(remaining.count, 3, "Two finished sets and the one already logged today stay")
        XCTAssertTrue(remaining.allSatisfy(\.isCompletedLoggedSet))
        XCTAssertEqual(draft.sets.map(\.weight), [185], "The set already logged in the open workout is kept")
    }

    // MARK: - Deleting without history

    func testDeletingExerciseWithNoLoggedSetsRemovesItOutright() throws {
        let exercise = insertCustomExercise()
        let draft = Workout(name: "Today")
        context.insert(draft)
        _ = draft.addSet(exercise: exercise, weight: 0, reps: 0)
        try context.save()

        XCTAssertEqual(manager.deleteExercise(exercise), .success)

        XCTAssertTrue(try storedExercises().isEmpty, "Nothing was logged, so there is nothing to archive")
        XCTAssertTrue(try storedSets().isEmpty)
        XCTAssertTrue(draft.sets.isEmpty)
    }

    func testBuiltInExercisesCannotBeDeletedOrArchived() throws {
        let builtIn = Exercise(
            name: "Barbell Squat",
            category: .compound,
            primaryMuscleGroups: [.quadriceps],
            isCustom: false
        )
        context.insert(builtIn)
        try insertLoggedWorkout(using: builtIn)

        XCTAssertEqual(manager.deleteExercise(builtIn), .persistenceFailure)

        XCTAssertFalse(builtIn.isArchived)
        XCTAssertEqual(manager.fetchAllExercises().map(\.name), ["Barbell Squat"])
    }

    // MARK: - Bringing an exercise back

    func testArchivedNameIsFreeToUseAgain() throws {
        let exercise = insertCustomExercise()
        try insertLoggedWorkout(using: exercise)
        XCTAssertEqual(manager.deleteExercise(exercise), .success)

        XCTAssertEqual(
            manager.validateDraft(name: "Garage Sled Push", primaryMuscleGroups: [.quadriceps]),
            .valid,
            "A name whose exercise was removed from the library must not read as a duplicate"
        )
    }

    func testAddingAnArchivedNameRestoresTheExerciseWithItsHistory() throws {
        let exercise = insertCustomExercise()
        try insertLoggedWorkout(using: exercise)
        XCTAssertEqual(manager.deleteExercise(exercise), .success)

        let result = manager.addExercise(
            name: " garage sled  push ",
            category: .isolation,
            primaryMuscleGroups: [.quadriceps, .glutes],
            secondaryMuscleGroups: [.calves],
            instructions: "Low handles."
        )

        XCTAssertEqual(result, .success)

        let stored = try storedExercises()
        XCTAssertEqual(stored.count, 1, "The archived exercise comes back; a second one is not created beside it")

        let restored = try XCTUnwrap(manager.fetchExercise(withName: "Garage Sled Push"))
        XCTAssertFalse(restored.isArchived)
        XCTAssertEqual(restored.name, "garage sled push", "The restored exercise takes the name as it was just entered")
        XCTAssertEqual(restored.category, .isolation)
        XCTAssertEqual(restored.primaryMuscleGroups, [.quadriceps, .glutes])
        XCTAssertEqual(restored.secondaryMuscleGroups, [.calves])
        XCTAssertEqual(restored.instructions, "Low handles.")
        XCTAssertEqual(restored.sets.count, 2, "Its logged history is attached again")
        XCTAssertEqual(manager.fetchAllExercises().count, 1)
    }

    // MARK: - Failure

    func testFailedSaveLeavesTheExerciseInTheLibraryWithAllItsSets() throws {
        let exercise = insertCustomExercise()
        try insertLoggedWorkout(using: exercise)

        let draft = Workout(name: "Today")
        context.insert(draft)
        _ = draft.addSet(exercise: exercise, weight: 0, reps: 0)
        try context.save()

        let failingManager = ExerciseManager(dataManager: FailingDataManager(context: context))

        XCTAssertEqual(failingManager.deleteExercise(exercise), .persistenceFailure)

        XCTAssertFalse(exercise.isArchived, "A delete that did not save must not hide the exercise")
        XCTAssertNotNil(manager.fetchExercise(withName: "Garage Sled Push"))
        XCTAssertEqual(try storedSets().count, 3, "The planned set must come back with the rollback")
    }
}
