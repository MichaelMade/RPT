//
//  WorkoutTemplateBuilderTests.swift
//  RPTTests
//
//  Save-as-template building, template name availability, the free-tier
//  template gate, and draft-safe workout durations.
//

import XCTest
@testable import RPT

@MainActor
final class WorkoutTemplateBuilderTests: XCTestCase {
    private func makeLoggedWorkout() -> (workout: Workout, bench: Exercise) {
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let workout = Workout(name: "Push Day")

        _ = workout.addSet(exercise: bench, weight: 45, reps: 10, isWarmup: true)
        _ = workout.addSet(exercise: bench, weight: 200, reps: 5)
        _ = workout.addSet(exercise: bench, weight: 180, reps: 7)
        _ = workout.addSet(exercise: bench, weight: 170, reps: 9)

        return (workout, bench)
    }

    func testBuildsRepRangesFromLoggedSets() {
        let (workout, _) = makeLoggedWorkout()

        let exercises = WorkoutTemplateBuilder.templateExercises(from: workout)

        XCTAssertEqual(exercises.count, 1)
        let exercise = exercises[0]
        XCTAssertEqual(exercise.exerciseName, "Bench Press")
        XCTAssertEqual(exercise.suggestedSets, 3, "Warm-up sets are excluded")

        let ranges = exercise.repRanges.sorted { $0.setNumber < $1.setNumber }
        XCTAssertEqual(ranges.map(\.minReps), [5, 7, 9])
        XCTAssertEqual(ranges.map(\.maxReps), [7, 9, 11])

        // Back-off percentages derived from the actual weight drops.
        XCTAssertEqual(ranges[0].percentageOfFirstSet ?? 0, 1.0, accuracy: 0.001)
        XCTAssertEqual(ranges[1].percentageOfFirstSet ?? 0, 0.9, accuracy: 0.001)
        XCTAssertEqual(ranges[2].percentageOfFirstSet ?? 0, 0.85, accuracy: 0.001)
    }

    func testSkipsExercisesWithoutUsableSets() {
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let workout = Workout(name: "Warm-ups Only")
        _ = workout.addSet(exercise: bench, weight: 45, reps: 10, isWarmup: true)

        XCTAssertTrue(WorkoutTemplateBuilder.templateExercises(from: workout).isEmpty)
    }

    func testEmptyWorkoutProducesNoExercises() {
        XCTAssertTrue(WorkoutTemplateBuilder.templateExercises(from: Workout(name: "Empty")).isEmpty)
    }
}

@MainActor
final class TemplateNameAvailabilityTests: XCTestCase {
    private var createdTemplateNames: [String] = []

    override func tearDown() {
        for name in createdTemplateNames {
            if let template = TemplateManager.shared.fetchTemplateByName(name) {
                _ = TemplateManager.shared.deleteTemplate(template)
            }
        }
        createdTemplateNames = []
        super.tearDown()
    }

    func testAvailableNameReturnsBaseWhenFree() {
        let unique = "Fresh Plan \(UUID().uuidString.prefix(8))"
        XCTAssertEqual(TemplateManager.shared.availableTemplateName(basedOn: unique), unique)
    }

    func testAvailableNameSuffixesWhenTaken() {
        let base = "Taken Plan \(UUID().uuidString.prefix(8))"
        createdTemplateNames.append(base)

        let exercises = [
            TemplateExercise(
                exerciseName: "Barbell Bench Press",
                suggestedSets: 1,
                repRanges: [TemplateRepRange(setNumber: 1, minReps: 5, maxReps: 5, percentageOfFirstSet: 1.0)]
            )
        ]
        XCTAssertEqual(TemplateManager.shared.createTemplate(name: base, exercises: exercises), .success)

        XCTAssertEqual(TemplateManager.shared.availableTemplateName(basedOn: base), "\(base) 2")
        XCTAssertEqual(
            TemplateManager.shared.availableTemplateName(basedOn: base.lowercased()),
            "\(TemplateManager.sanitizeTemplateName(base.lowercased())) 2",
            "Name collision checks are case-insensitive"
        )
    }
}

final class TemplateGateTests: XCTestCase {
    func testFreeTierAllowsUpToLimit() {
        XCTAssertTrue(MonetizationPlan.canCreateTemplate(existingCount: 0, isUnlocked: false))
        XCTAssertTrue(MonetizationPlan.canCreateTemplate(existingCount: MonetizationPlan.freeTemplateLimit - 1, isUnlocked: false))
        XCTAssertFalse(MonetizationPlan.canCreateTemplate(existingCount: MonetizationPlan.freeTemplateLimit, isUnlocked: false))
    }

    func testProIsUnlimited() {
        XCTAssertTrue(MonetizationPlan.canCreateTemplate(existingCount: 500, isUnlocked: true))
    }
}

@MainActor
final class WorkoutDurationTests: XCTestCase {
    func testNormalSessionUsesElapsedTime() {
        let start = Date(timeIntervalSinceNow: -45 * 60)
        let workout = Workout(date: start, name: "Same Day")

        workout.complete(now: Date())

        XCTAssertEqual(workout.duration, 45 * 60, accuracy: 5)
    }

    func testStaleDraftUsesLoggedSetSpanInsteadOfWallClock() {
        let threeDaysAgo = Date(timeIntervalSinceNow: -3 * 24 * 60 * 60)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let workout = Workout(date: threeDaysAgo, name: "Stale Draft")

        let firstSet = workout.addSet(exercise: bench, weight: 200, reps: 5)
        firstSet.completedAt = threeDaysAgo.addingTimeInterval(5 * 60)
        let lastSet = workout.addSet(exercise: bench, weight: 180, reps: 7)
        lastSet.completedAt = threeDaysAgo.addingTimeInterval(45 * 60)

        workout.complete(now: Date())

        XCTAssertEqual(workout.duration, 40 * 60, accuracy: 5, "Duration should span logged sets, not idle days")
    }

    func testStaleDraftWithoutLoggedSetsKeepsPositiveDuration() {
        let twoDaysAgo = Date(timeIntervalSinceNow: -2 * 24 * 60 * 60)
        let workout = Workout(date: twoDaysAgo, name: "Empty Stale Draft")

        workout.complete(now: Date())

        XCTAssertGreaterThan(workout.duration, 0)
    }
}
