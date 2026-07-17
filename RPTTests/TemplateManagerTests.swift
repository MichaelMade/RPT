//
//  TemplateManagerTests.swift
//  RPTTests
//
//  Core template logic: validation, CRUD, duplicate handling, workout
//  creation, and source-template resolution.
//

import XCTest
@testable import RPT

@MainActor
final class TemplateManagerTests: XCTestCase {
    private var manager: TemplateManager!
    private var createdTemplateNames: [String] = []
    private var createdWorkouts: [Workout] = []

    // Self-contained library exercise: depending on the seeded defaults
    // couples these tests to whatever other suites do to the shared store.
    // Letters-only suffix so digit queries can't accidentally match it.
    private var testExerciseName: String = ""

    override func setUp() {
        super.setUp()
        manager = TemplateManager.shared
        createdTemplateNames = []
        createdWorkouts = []

        testExerciseName = "Template Suite Bench \(UUID().uuidString.filter(\.isLetter))"
        _ = ExerciseManager.shared.addExercise(
            name: testExerciseName,
            category: .compound,
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [],
            instructions: ""
        )
    }

    override func tearDown() {
        for name in createdTemplateNames {
            if let template = manager.fetchTemplateByName(name) {
                _ = manager.deleteTemplate(template)
            }
        }
        for workout in createdWorkouts {
            _ = WorkoutManager.shared.deleteWorkoutSafely(workout)
        }
        if let exercise = ExerciseManager.shared.fetchExercise(withName: testExerciseName) {
            _ = ExerciseManager.shared.deleteExercise(exercise)
        }
        manager = nil
        super.tearDown()
    }

    private func uniqueName(_ base: String) -> String {
        let name = "\(base) \(UUID().uuidString.prefix(8))"
        createdTemplateNames.append(name)
        return name
    }

    private func benchExercise() -> TemplateExercise {
        TemplateExercise(
            exerciseName: testExerciseName,
            suggestedSets: 3,
            repRanges: [
                TemplateRepRange(setNumber: 1, minReps: 4, maxReps: 6, percentageOfFirstSet: 1.0),
                TemplateRepRange(setNumber: 2, minReps: 6, maxReps: 8, percentageOfFirstSet: 0.9),
                TemplateRepRange(setNumber: 3, minReps: 8, maxReps: 10, percentageOfFirstSet: 0.8)
            ]
        )
    }

    // MARK: - Static Helpers

    func testSanitizeTemplateName() {
        XCTAssertEqual(TemplateManager.sanitizeTemplateName("  Upper   A  "), "Upper A")
        XCTAssertEqual(TemplateManager.sanitizeTemplateName(""), "Template")
    }

    func testNamesCollideIsCaseAndDiacriticInsensitive() {
        XCTAssertTrue(TemplateManager.namesCollide("Upper A", "upper a"))
        XCTAssertTrue(TemplateManager.namesCollide("Push Día", "push dia"))
        XCTAssertFalse(TemplateManager.namesCollide("Upper A", "Upper B"))
    }

    func testHasDuplicateExerciseNames() {
        let exercises = [
            TemplateExercise(exerciseName: "Bench Press", suggestedSets: 3, repRanges: []),
            TemplateExercise(exerciseName: "bench press", suggestedSets: 3, repRanges: [])
        ]
        XCTAssertTrue(TemplateManager.hasDuplicateExerciseNames(exercises))
        XCTAssertFalse(TemplateManager.hasDuplicateExerciseNames([exercises[0]]))
    }

    func testInitialCompletedAt() {
        let fallback = Date()
        XCTAssertEqual(TemplateManager.initialCompletedAt(weight: 100, reps: 5, fallbackDate: fallback), fallback)
        XCTAssertEqual(TemplateManager.initialCompletedAt(weight: 0, reps: 5, fallbackDate: fallback), .distantPast)
        XCTAssertEqual(TemplateManager.initialCompletedAt(weight: 100, reps: 0, fallbackDate: fallback), .distantPast)
    }

    // MARK: - Default Templates

    func testMakeDefaultTemplatesMatchesClassicThreeDaySplit() {
        let templates = TemplateManager.makeDefaultTemplates()

        XCTAssertEqual(
            templates.map(\.name),
            ["RPT Day 1 - Deadlift", "RPT Day 2 - Bench", "RPT Day 3 - Squat"]
        )

        guard templates.count == 3 else {
            return XCTFail("Expected the classic three-day split")
        }

        let deadliftDay = templates[0]
        XCTAssertEqual(
            deadliftDay.exercises.map(\.exerciseName),
            ["Deadlift", "Barbell Row", "Bicep Curl"]
        )
        XCTAssertEqual(deadliftDay.exercises.map(\.suggestedSets), [2, 3, 2])
        XCTAssertEqual(
            deadliftDay.exercises.first?.repRanges.map(\.percentageOfFirstSet),
            [1.0, 0.9]
        )

        let benchDay = templates[1]
        XCTAssertEqual(
            benchDay.exercises.map(\.exerciseName),
            ["Barbell Bench Press", "Overhead Press", "Tricep Extension"]
        )
        XCTAssertEqual(benchDay.exercises.map(\.suggestedSets), [3, 3, 2])
        XCTAssertEqual(
            benchDay.exercises.first?.repRanges.map(\.percentageOfFirstSet),
            [1.0, 0.95, 0.9]
        )

        let squatDay = templates[2]
        XCTAssertEqual(
            squatDay.exercises.map(\.exerciseName),
            ["Barbell Squat", "Pull-up", "Calf Raise"]
        )
        XCTAssertEqual(squatDay.exercises.map(\.suggestedSets), [3, 3, 2])
        XCTAssertEqual(
            squatDay.exercises.first?.repRanges.map(\.percentageOfFirstSet),
            [1.0, 0.9, 0.8]
        )

        for template in templates {
            XCTAssertFalse(TemplateManager.hasDuplicateExerciseNames(template.exercises))
            for exercise in template.exercises {
                XCTAssertEqual(exercise.repRanges.count, exercise.suggestedSets)
            }
        }
    }

    func testDefaultTemplateExercisesResolveInExerciseLibrary() {
        for template in TemplateManager.makeDefaultTemplates() {
            for templateExercise in template.exercises {
                XCTAssertNotNil(
                    ExerciseManager.shared.fetchExercise(withName: templateExercise.exerciseName),
                    "\(template.name) references \(templateExercise.exerciseName), which is missing from the default library"
                )
            }
        }
    }

    // MARK: - Validation

    func testValidateDraftRequiresNameAndExercises() {
        XCTAssertEqual(manager.validateDraft(name: "  ", exercises: [benchExercise()]), .missingName)
        XCTAssertEqual(manager.validateDraft(name: "Plan", exercises: []), .noExercises)
        XCTAssertEqual(
            manager.validateDraft(name: "Plan", exercises: [benchExercise(), benchExercise()]),
            .duplicateExercise
        )
    }

    func testValidateDraftRejectsDuplicateTemplateName() {
        let name = uniqueName("Dup Check")
        XCTAssertEqual(manager.createTemplate(name: name, exercises: [benchExercise()]), .success)

        XCTAssertEqual(
            manager.validateDraft(name: name.uppercased(), exercises: [benchExercise()]),
            .duplicateName
        )
    }

    // MARK: - CRUD

    func testCreateUpdateDeleteTemplate() {
        let name = uniqueName("CRUD Plan")

        XCTAssertEqual(manager.createTemplate(name: name, exercises: [benchExercise()], notes: "note"), .success)

        guard let template = manager.fetchTemplateByName(name) else {
            return XCTFail("Template should exist after creation")
        }
        XCTAssertEqual(template.exercises.count, 1)
        XCTAssertEqual(template.notes, "note")

        let renamed = uniqueName("CRUD Plan Renamed")
        XCTAssertEqual(
            manager.updateTemplate(template, name: renamed, exercises: template.exercises, notes: "updated"),
            .success
        )
        XCTAssertEqual(template.name, renamed)
        XCTAssertEqual(template.notes, "updated")

        XCTAssertEqual(manager.deleteTemplate(template), .success)
        XCTAssertNil(manager.fetchTemplateByName(renamed))
    }

    // MARK: - Workout Creation

    func testCreateWorkoutFromTemplateBuildsSets() {
        let name = uniqueName("Start Plan")
        XCTAssertEqual(manager.createTemplate(name: name, exercises: [benchExercise()]), .success)

        guard let template = manager.fetchTemplateByName(name) else {
            return XCTFail("Template should exist")
        }

        guard let workout = manager.createWorkoutFromTemplate(template) else {
            return XCTFail("Workout should be created from a startable template")
        }
        createdWorkouts.append(workout)

        XCTAssertEqual(workout.startedFromTemplateID, template.id)
        XCTAssertEqual(workout.sets.count, 3, "One set per rep range")

        // Target reps default to the middle of each range, in logged order.
        XCTAssertEqual(workout.setsInLoggedOrder.map(\.reps), [5, 7, 9])

        // Template-created sets start unlogged.
        XCTAssertTrue(workout.sets.allSatisfy { !$0.isCompletedLoggedSet })
    }

    func testCreateWorkoutSkipsDuplicateAndMissingExercises() {
        let missing = TemplateExercise(
            exerciseName: "Nonexistent Movement \(UUID().uuidString.prefix(6))",
            suggestedSets: 2,
            repRanges: [
                TemplateRepRange(setNumber: 1, minReps: 5, maxReps: 5, percentageOfFirstSet: 1.0),
                TemplateRepRange(setNumber: 2, minReps: 5, maxReps: 5, percentageOfFirstSet: 0.9)
            ]
        )

        let name = uniqueName("Partial Plan")
        XCTAssertEqual(manager.createTemplate(name: name, exercises: [benchExercise(), missing]), .success)

        guard let template = manager.fetchTemplateByName(name) else {
            return XCTFail("Template should exist")
        }

        XCTAssertEqual(manager.unavailableExerciseNames(in: template), [missing.exerciseName])
        XCTAssertEqual(manager.availableExerciseCount(in: template), 1)
        XCTAssertTrue(manager.canStartWorkout(for: template))

        guard let workout = manager.createWorkoutFromTemplate(template) else {
            return XCTFail("Partially available template should still start")
        }
        createdWorkouts.append(workout)

        XCTAssertEqual(workout.sets.count, 3, "Only the available exercise contributes sets")
        XCTAssertTrue(workout.sets.allSatisfy { $0.exercise?.name == testExerciseName })
    }

    func testDuplicateExerciseNamesDetection() {
        let exercises = [
            TemplateExercise(exerciseName: "Bench Press", suggestedSets: 1, repRanges: []),
            TemplateExercise(exerciseName: "BENCH press", suggestedSets: 1, repRanges: []),
            TemplateExercise(exerciseName: "Squat", suggestedSets: 1, repRanges: [])
        ]

        XCTAssertEqual(manager.duplicateExerciseNames(in: exercises), ["Bench Press"])
    }

    // MARK: - Source Template Resolution

    func testSourceTemplateResolvedByStableID() {
        let name = uniqueName("Source Plan")
        XCTAssertEqual(manager.createTemplate(name: name, exercises: [benchExercise()]), .success)

        guard let template = manager.fetchTemplateByName(name) else {
            return XCTFail("Template should exist")
        }

        guard let workout = manager.createWorkoutFromTemplate(template) else {
            return XCTFail("Workout should start")
        }
        createdWorkouts.append(workout)

        // Rename the template; ID-based lookup should still resolve it.
        let renamed = uniqueName("Source Plan Renamed")
        XCTAssertEqual(
            manager.updateTemplate(template, name: renamed, exercises: template.exercises, notes: ""),
            .success
        )

        XCTAssertEqual(manager.sourceTemplate(for: workout)?.id, template.id)
    }
}

// MARK: - Template Duplicate Naming (ViewModel)

@MainActor
final class TemplateDuplicateNamingTests: XCTestCase {
    func testDuplicateNamingAvoidsNestedCopySuffixes() {
        let viewModel = TemplateViewModel()

        XCTAssertEqual(viewModel.preferredDuplicateName(for: "Upper Body"), "Upper Body Copy")
        XCTAssertEqual(viewModel.preferredDuplicateName(for: "Upper Body Copy"), "Upper Body Copy")
        XCTAssertEqual(viewModel.preferredDuplicateName(for: "Upper Body Copy 2"), "Upper Body Copy")
    }
}
