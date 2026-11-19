//
//  StoreMigrationTests.swift
//  RPTTests
//
//  Proves that a store written by a shipped version of the app still opens,
//  with its data intact, under the current models.
//
//  RPT relies on SwiftData's automatic lightweight migration: there is no
//  staged migration plan. That only holds while every model change is
//  additive (a new attribute that is optional or has an inline default).
//  These tests write a real on-disk store with a frozen copy of the shipped
//  model shapes, then reopen it with today's models. See
//  docs/data-migrations.md before changing a model.
//

import XCTest
import SwiftData
@testable import RPT

/// The stored shape of every model as shipped in RPT 2.2.1 (build 5).
///
/// Frozen on purpose: do NOT edit these to match a model change. If a model
/// gains or changes a stored property, the app's model changes and this
/// copy stays, which is what lets the test catch a change that an existing
/// user's store cannot absorb.
enum ShippedSchema_2_2_1 {
    @Model
    final class Exercise {
        var name: String
        var category: ExerciseCategory
        var primaryMuscleGroups: [MuscleGroup]
        var secondaryMuscleGroups: [MuscleGroup]
        var instructions: String
        var isCustom: Bool

        @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.exercise)
        var sets: [ExerciseSet]

        init(name: String, category: ExerciseCategory, primaryMuscleGroups: [MuscleGroup], isCustom: Bool) {
            self.name = name
            self.category = category
            self.primaryMuscleGroups = primaryMuscleGroups
            self.secondaryMuscleGroups = []
            self.instructions = ""
            self.isCustom = isCustom
            self.sets = []
        }
    }

    @Model
    final class ExerciseSet {
        var weight: Int
        var reps: Int
        var completedAt: Date
        var isWarmup: Bool
        var rpe: Int?
        var notes: String
        var orderIndex: Int = 0

        @Relationship(deleteRule: .nullify)
        var exercise: Exercise?

        @Relationship(deleteRule: .nullify)
        var workout: Workout?

        init(weight: Int, reps: Int, exercise: Exercise, workout: Workout, completedAt: Date, rpe: Int?, orderIndex: Int) {
            self.weight = weight
            self.reps = reps
            self.exercise = exercise
            self.workout = workout
            self.completedAt = completedAt
            self.isWarmup = false
            self.rpe = rpe
            self.notes = ""
            self.orderIndex = orderIndex
        }
    }

    @Model
    final class Workout {
        var date: Date
        var name: String
        var notes: String
        var duration: TimeInterval
        var isCompleted: Bool
        var startedFromTemplate: String?
        var startedFromTemplateID: String?

        @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workout)
        var sets: [ExerciseSet]

        @Relationship(deleteRule: .nullify)
        var user: User?

        init(date: Date, name: String, duration: TimeInterval, isCompleted: Bool) {
            self.date = date
            self.name = name
            self.notes = ""
            self.duration = duration
            self.isCompleted = isCompleted
            self.startedFromTemplate = nil
            self.startedFromTemplateID = nil
            self.sets = []
        }
    }

    @Model
    final class WorkoutTemplate {
        @Attribute(.unique) var id: String
        var name: String
        var exercises: [TemplateExercise]
        var notes: String

        init(id: String, name: String, exercises: [TemplateExercise]) {
            self.id = id
            self.name = name
            self.exercises = exercises
            self.notes = ""
        }
    }

    @Model
    final class UserSettings {
        var restTimerDuration: Int
        var defaultRPTPercentageDropsString: String = "0.000,0.100,0.150"
        var showRPE: Bool
        var darkModePreference: DarkModePreference
        var autoStartRestTimerEnabled: Bool = true
        var weeklyWorkoutGoal: Int = 3

        init(restTimerDuration: Int, drops: String, showRPE: Bool, darkModePreference: DarkModePreference) {
            self.restTimerDuration = restTimerDuration
            self.defaultRPTPercentageDropsString = drops
            self.showRPE = showRPE
            self.darkModePreference = darkModePreference
        }
    }

    @Model
    final class User {
        var id: UUID
        var username: String
        var email: String
        var dateJoined: Date
        var height: Double?
        var weight: Double?
        var birthdate: Date?
        var profileImageName: String?
        var settings: UserSettings?
        var lastActive: Date
        var workoutStreak: Int
        var totalWorkouts: Int
        var totalVolume: Double
        var personalBests: [String: Int]

        @Relationship(deleteRule: .cascade, inverse: \Workout.user)
        var workouts: [Workout]

        init(username: String, totalWorkouts: Int, totalVolume: Double, personalBests: [String: Int]) {
            self.id = UUID()
            self.username = username
            self.email = ""
            self.dateJoined = Date(timeIntervalSince1970: 1_750_000_000)
            self.lastActive = Date(timeIntervalSince1970: 1_760_000_000)
            self.workoutStreak = 2
            self.totalWorkouts = totalWorkouts
            self.totalVolume = totalVolume
            self.personalBests = personalBests
            self.workouts = []
        }
    }

    static var models: [any PersistentModel.Type] {
        [Exercise.self, Workout.self, ExerciseSet.self, WorkoutTemplate.self, UserSettings.self, User.self]
    }
}

@MainActor
final class StoreMigrationTests: XCTestCase {
    /// Lets a manager work on a context opened straight from the store file.
    private final class ContextDataManager: DataManaging {
        private let context: ModelContext

        init(context: ModelContext) {
            self.context = context
        }

        func getModelContext() -> ModelContext {
            context
        }

        func saveChanges() throws {
            try context.save()
        }
    }

    private var storeDirectory: URL!
    private var storeURL: URL { storeDirectory.appendingPathComponent("RPT.store") }

    private let workoutDate = Date(timeIntervalSince1970: 1_760_000_000)

    override func setUpWithError() throws {
        storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rpt-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let storeDirectory {
            try? FileManager.default.removeItem(at: storeDirectory)
        }
        storeDirectory = nil
    }

    /// Writes a store exactly as RPT 2.2.1 would have, then lets go of it.
    private func writeStoreWithShippedSchema() throws {
        // The pool makes sure the old-shape container has let go of the file
        // before a test reopens it with today's models.
        try autoreleasepool {
            try writeShippedStore()
        }
    }

    /// Opens the store the way the app does: the app's own schema, no
    /// migration plan.
    private func openStoreWithCurrentModels() throws -> ModelContainer {
        let schema = DataManager.makeSchema()
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, url: storeURL)
        )
    }

    private func writeShippedStore() throws {
        let schema = Schema(ShippedSchema_2_2_1.models)
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)

        let bench = ShippedSchema_2_2_1.Exercise(
            name: "Barbell Bench Press",
            category: .compound,
            primaryMuscleGroups: [.chest],
            isCustom: false
        )
        let ringDip = ShippedSchema_2_2_1.Exercise(
            name: "Ring Dip",
            category: .bodyweight,
            primaryMuscleGroups: [.chest, .triceps],
            isCustom: true
        )
        context.insert(bench)
        context.insert(ringDip)

        let workout = ShippedSchema_2_2_1.Workout(
            date: workoutDate,
            name: "RPT Day 2 - Bench",
            duration: 3_000,
            isCompleted: true
        )
        context.insert(workout)

        let loggedAt = workoutDate.addingTimeInterval(600)
        let benchSets: [(weight: Int, reps: Int, rpe: Int)] = [(185, 6, 9), (165, 8, 8), (155, 10, 8)]
        for (index, plan) in benchSets.enumerated() {
            let secondsIntoWorkout = TimeInterval(index * 240)
            context.insert(
                ShippedSchema_2_2_1.ExerciseSet(
                    weight: plan.weight,
                    reps: plan.reps,
                    exercise: bench,
                    workout: workout,
                    completedAt: loggedAt.addingTimeInterval(secondsIntoWorkout),
                    rpe: plan.rpe,
                    orderIndex: index
                )
            )
        }
        context.insert(
            ShippedSchema_2_2_1.ExerciseSet(
                weight: 0,
                reps: 10,
                exercise: ringDip,
                workout: workout,
                completedAt: loggedAt.addingTimeInterval(1_200),
                rpe: nil,
                orderIndex: 3
            )
        )

        context.insert(
            ShippedSchema_2_2_1.WorkoutTemplate(
                id: "template-bench-day",
                name: "Bench Day",
                exercises: [
                    TemplateExercise(
                        exerciseName: "Barbell Bench Press",
                        suggestedSets: 3,
                        repRanges: [
                            TemplateRepRange(setNumber: 1, minReps: 5, maxReps: 7, percentageOfFirstSet: 1.0),
                            TemplateRepRange(setNumber: 2, minReps: 7, maxReps: 9, percentageOfFirstSet: 0.9),
                            TemplateRepRange(setNumber: 3, minReps: 9, maxReps: 11, percentageOfFirstSet: 0.85)
                        ]
                    )
                ]
            )
        )

        context.insert(
            ShippedSchema_2_2_1.UserSettings(
                restTimerDuration: 150,
                drops: "0.000,0.100,0.200",
                showRPE: false,
                darkModePreference: .dark
            )
        )

        let user = ShippedSchema_2_2_1.User(
            username: "Lifter",
            totalWorkouts: 1,
            totalVolume: 3_980,
            personalBests: ["Barbell Bench Press": 185]
        )
        context.insert(user)
        workout.user = user

        try context.save()
    }

    func testStoreFromShippedVersionOpensWithCurrentModelsAndKeepsItsData() throws {
        try writeStoreWithShippedSchema()

        let container = try openStoreWithCurrentModels()
        let context = ModelContext(container)

        // Exercises
        let exercises = try context.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))
        XCTAssertEqual(exercises.map(\.name), ["Barbell Bench Press", "Ring Dip"])
        let bench = try XCTUnwrap(exercises.first)
        let ringDip = try XCTUnwrap(exercises.last)
        XCTAssertEqual(bench.category, .compound)
        XCTAssertEqual(bench.primaryMuscleGroups, [.chest])
        XCTAssertFalse(bench.isCustom)
        XCTAssertEqual(ringDip.category, .bodyweight)
        XCTAssertEqual(ringDip.primaryMuscleGroups, [.chest, .triceps])
        XCTAssertTrue(ringDip.isCustom)

        // Workout and its logged sets
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(workouts.count, 1)
        let workout = try XCTUnwrap(workouts.first)
        XCTAssertEqual(workout.name, "RPT Day 2 - Bench")
        XCTAssertEqual(workout.date, workoutDate)
        XCTAssertEqual(workout.duration, 3_000)
        XCTAssertTrue(workout.isCompleted)

        let sets = workout.setsInLoggedOrder
        XCTAssertEqual(sets.map(\.weight), [185, 165, 155, 0])
        XCTAssertEqual(sets.map(\.reps), [6, 8, 10, 10])
        let expectedRPE: [Int?] = [9, 8, 8, nil]
        XCTAssertEqual(sets.map(\.rpe), expectedRPE)
        let expectedExercises: [String?] = [
            "Barbell Bench Press", "Barbell Bench Press", "Barbell Bench Press", "Ring Dip"
        ]
        XCTAssertEqual(sets.map { $0.exercise?.name }, expectedExercises)
        XCTAssertTrue(sets.allSatisfy(\.isCompletedLoggedSet), "Logged history must still read as logged")
        // 185x6 + 165x8 + 155x10; the bodyweight set adds no load.
        let expectedVolume: Double = 3_980
        XCTAssertEqual(workout.totalVolume, expectedVolume, accuracy: 0.001)

        // Template
        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        XCTAssertEqual(templates.map(\.id), ["template-bench-day"])
        let template = try XCTUnwrap(templates.first)
        XCTAssertEqual(template.name, "Bench Day")
        XCTAssertEqual(template.exercises.map(\.exerciseName), ["Barbell Bench Press"])
        XCTAssertEqual(template.exercises.first?.repRanges.map(\.minReps), [5, 7, 9])

        // Settings
        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<UserSettings>()).first)
        XCTAssertEqual(settings.restTimerDuration, 150)
        XCTAssertEqual(settings.defaultRPTPercentageDrops, [0.0, 0.10, 0.20])
        XCTAssertFalse(settings.showRPE)
        XCTAssertEqual(settings.darkModePreference, .dark)

        // User
        let user = try XCTUnwrap(try context.fetch(FetchDescriptor<User>()).first)
        XCTAssertEqual(user.username, "Lifter")
        XCTAssertEqual(user.totalWorkouts, 1)
        XCTAssertEqual(user.personalBests, ["Barbell Bench Press": 185])
        XCTAssertEqual(user.workouts.count, 1)
        XCTAssertEqual(workout.user?.username, "Lifter")
    }

    func testAttributesAddedSinceTheShippedVersionTakeTheirDefaults() throws {
        try writeStoreWithShippedSchema()

        let container = try openStoreWithCurrentModels()
        let context = ModelContext(container)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.count, 2)
        XCTAssertTrue(
            exercises.allSatisfy { !$0.isArchived },
            "No exercise from an existing store may come back archived (hidden from the library)"
        )

        // Units: every set logged before they existed is whole pounds, and
        // must keep reading as exactly the load that was stored.
        let sets = try context.fetch(FetchDescriptor<ExerciseSet>())
        XCTAssertEqual(sets.count, 4)
        XCTAssertTrue(sets.allSatisfy { $0.loadValue == nil && $0.loadUnitRaw == nil })
        XCTAssertTrue(sets.allSatisfy { $0.loadUnit == .pounds })
        XCTAssertTrue(sets.allSatisfy { $0.exactPounds == Double($0.weight) })

        // Relabeling: no set from an existing store may come back marked as
        // already relabeled, or an undo would have something to rewrite.
        XCTAssertTrue(sets.allSatisfy { $0.relabeledFromPounds == nil })
    }

    func testMigratedStoreAcceptsAKilogramSetAndReadsItBackExactly() throws {
        try writeStoreWithShippedSchema()

        try autoreleasepool {
            let container = try openStoreWithCurrentModels()
            let context = ModelContext(container)
            let bench = try XCTUnwrap(
                try context.fetch(FetchDescriptor<Exercise>()).first { $0.name == "Barbell Bench Press" }
            )

            let workout = Workout(
                date: workoutDate.addingTimeInterval(7 * 24 * 60 * 60),
                name: "First Kilogram Session"
            )
            context.insert(workout)
            let set = workout.addSet(exercise: bench, weight: 0, reps: 5)
            set.setLoad(61.25, in: .kilograms)
            workout.isCompleted = true
            try context.save()
        }

        let reopened = try openStoreWithCurrentModels()
        let workouts = try ModelContext(reopened).fetch(FetchDescriptor<Workout>())
        let kilogramWorkout = try XCTUnwrap(workouts.first { $0.name == "First Kilogram Session" })
        let kilogramSet = try XCTUnwrap(kilogramWorkout.sets.first)

        XCTAssertEqual(kilogramSet.load(in: .kilograms), 61.25)
        XCTAssertEqual(kilogramSet.loadUnit, .kilograms)
        XCTAssertEqual(kilogramSet.weight, 135)

        let originalWorkout = try XCTUnwrap(workouts.first { $0.name == "RPT Day 2 - Bench" })
        let expectedPounds: [Int] = [185, 165, 155, 0]
        XCTAssertEqual(originalWorkout.setsInLoggedOrder.map(\.weight), expectedPounds)
    }

    /// Relabeling earlier workouts as kilograms rewrites logged sets in
    /// bulk, so it is proven on the real thing: a store written by the
    /// shipped app, on disk, closed and reopened between each step.
    func testMigratedStoreCanBeRelabeledAsKilogramsAndPutBackExactly() throws {
        try writeStoreWithShippedSchema()

        let suiteName = "StoreMigrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // 185x6 + 165x8 + 155x10, as the shipped store recorded it.
        let shippedVolume: Double = 3_980

        try autoreleasepool {
            let container = try openStoreWithCurrentModels()
            let relabeler = LoadHistoryRelabeler(
                dataManager: ContextDataManager(context: ModelContext(container)),
                defaults: defaults
            )

            XCTAssertEqual(relabeler.status(for: .pounds), .nothingToOffer)
            XCTAssertEqual(
                relabeler.status(for: .kilograms),
                .readAsPounds(
                    KilogramRelabelPolicy.Preview(setCount: 3, exerciseName: "Barbell Bench Press", number: 155)
                )
            )
            XCTAssertEqual(relabeler.relabelEarlierSetsAsKilograms(), .changed(sets: 3))
        }

        try autoreleasepool {
            let container = try openStoreWithCurrentModels()
            let context = ModelContext(container)
            let workout = try XCTUnwrap(try context.fetch(FetchDescriptor<Workout>()).first)
            let user = try XCTUnwrap(try context.fetch(FetchDescriptor<User>()).first)

            let expectedKilograms: [Double] = [185, 165, 155, 0]
            let expectedMarks: [Int?] = [185, 165, 155, nil]
            XCTAssertEqual(workout.setsInLoggedOrder.map { $0.load(in: .kilograms) }, expectedKilograms)
            XCTAssertEqual(workout.setsInLoggedOrder.map(\.relabeledFromPounds), expectedMarks)
            XCTAssertEqual(workout.setsInLoggedOrder.last?.weight, 0, "A bodyweight set has no number to relabel")

            let relabeledVolume = WeightUnit.pounds.converting(shippedVolume, from: .kilograms)
            XCTAssertEqual(user.totalVolume, relabeledVolume, accuracy: 0.01)
            XCTAssertEqual(user.personalBests, ["Barbell Bench Press": 408])

            let relabeler = LoadHistoryRelabeler(
                dataManager: ContextDataManager(context: context),
                defaults: defaults
            )
            XCTAssertEqual(relabeler.status(for: .pounds), .relabeled(setCount: 3))
            XCTAssertEqual(relabeler.undoRelabel(), .changed(sets: 3))
        }

        let reopened = try openStoreWithCurrentModels()
        let context = ModelContext(reopened)
        let workout = try XCTUnwrap(try context.fetch(FetchDescriptor<Workout>()).first)
        let user = try XCTUnwrap(try context.fetch(FetchDescriptor<User>()).first)

        let expectedPounds: [Int] = [185, 165, 155, 0]
        XCTAssertEqual(workout.setsInLoggedOrder.map(\.weight), expectedPounds)
        XCTAssertTrue(
            workout.sets.allSatisfy { $0.loadValue == nil && $0.loadUnitRaw == nil && $0.relabeledFromPounds == nil },
            "After an undo the store holds exactly what the shipped app wrote"
        )
        XCTAssertEqual(user.totalVolume, shippedVolume, accuracy: 0.01)
        XCTAssertEqual(user.personalBests, ["Barbell Bench Press": 185])
    }

    func testMigratedStoreAcceptsNewWritesAndReopens() throws {
        try writeStoreWithShippedSchema()

        try autoreleasepool {
            let container = try openStoreWithCurrentModels()
            let context = ModelContext(container)
            let bench = try XCTUnwrap(
                try context.fetch(FetchDescriptor<Exercise>()).first { $0.name == "Barbell Bench Press" }
            )

            let workout = Workout(
                date: workoutDate.addingTimeInterval(7 * 24 * 60 * 60),
                name: "After Update"
            )
            context.insert(workout)
            _ = workout.addSet(exercise: bench, weight: 190, reps: 6)
            workout.isCompleted = true
            try context.save()
        }

        let reopened = try openStoreWithCurrentModels()
        let workouts = try ModelContext(reopened).fetch(
            FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date)])
        )

        XCTAssertEqual(workouts.map(\.name), ["RPT Day 2 - Bench", "After Update"])
        XCTAssertEqual(workouts.last?.sets.map(\.weight), [190])
        XCTAssertEqual(workouts.first?.sets.count, 4, "The original history is still there after a second launch")
    }
}
