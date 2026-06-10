//
//  TrainingMathTests.swift
//  RPTTests
//
//  Pure-logic coverage for the training-science utilities: e1RM math,
//  warm-up ramps, progression suggestions, plate math, CSV export, and
//  workout name normalization.
//

import XCTest
@testable import RPT

final class OneRepMaxTests: XCTestCase {
    func testSingleRepReturnsWeight() {
        XCTAssertEqual(OneRepMax.epley(weight: 225, reps: 1), 225)
        XCTAssertEqual(OneRepMax.brzycki(weight: 225, reps: 1), 225)
        XCTAssertEqual(OneRepMax.estimate(weight: 225, reps: 1), 225)
    }

    func testEpleyKnownValue() {
        // 200 x 5 → 200 * (1 + 5/30) = 233.33
        XCTAssertEqual(OneRepMax.epley(weight: 200, reps: 5), 233.333, accuracy: 0.01)
    }

    func testBrzyckiKnownValue() {
        // 200 x 5 → 200 * 36 / 32 = 225
        XCTAssertEqual(OneRepMax.brzycki(weight: 200, reps: 5), 225, accuracy: 0.01)
    }

    func testEstimateClampsHighReps() {
        // Reps above 12 should not inflate the estimate further.
        XCTAssertEqual(
            OneRepMax.estimate(weight: 100, reps: 20),
            OneRepMax.estimate(weight: 100, reps: 12)
        )
    }

    func testInvalidInputsReturnZero() {
        XCTAssertEqual(OneRepMax.estimate(weight: 0, reps: 5), 0)
        XCTAssertEqual(OneRepMax.estimate(weight: 100, reps: 0), 0)
        XCTAssertEqual(OneRepMax.epley(weight: -10, reps: 5), 0)
    }

    func testFormatted() {
        XCTAssertEqual(OneRepMax.formatted(233.4), "233 lb")
        XCTAssertEqual(OneRepMax.formatted(0), "—")
    }
}

final class WarmupPlannerTests: XCTestCase {
    func testHeavyTopSetProducesFullRamp() {
        let plan = WarmupPlanner.plan(topSetWeight: 225)

        XCTAssertEqual(plan.first?.weight, WarmupPlanner.barWeight)
        XCTAssertEqual(plan.first?.reps, 10)

        // 40% of 225 = 90, 60% = 135, 80% = 180
        XCTAssertEqual(plan.map(\.weight), [45, 90, 135, 180])

        // Reps taper down as weight rises.
        XCTAssertEqual(plan.map(\.reps), [10, 5, 3, 1])
    }

    func testStepsAreStrictlyIncreasingAndBelowTopSet() {
        for topSet in stride(from: 50, through: 600, by: 5) {
            let plan = WarmupPlanner.plan(topSetWeight: topSet)
            let weights = plan.map(\.weight)

            XCTAssertEqual(weights, weights.sorted(), "Ramp should ascend for top set \(topSet)")
            XCTAssertEqual(Set(weights).count, weights.count, "No duplicate steps for top set \(topSet)")
            XCTAssertTrue(weights.allSatisfy { $0 < topSet }, "All steps below top set for \(topSet)")
        }
    }

    func testLightTopSetGetsBodyweightWarmup() {
        let plan = WarmupPlanner.plan(topSetWeight: 40)
        XCTAssertEqual(plan, [WarmupStep(weight: 0, reps: 10)])
    }

    func testZeroTopSetProducesNoPlan() {
        XCTAssertTrue(WarmupPlanner.plan(topSetWeight: 0).isEmpty)
    }
}

final class ProgressionAdvisorTests: XCTestCase {
    func testHittingTopOfRangeSuggestsMoreWeight() {
        let suggestion = ProgressionAdvisor.suggestion(lastWeight: 225, lastReps: 6, repRange: 4...6)
        XCTAssertEqual(suggestion.direction, .increaseWeight)
        XCTAssertEqual(suggestion.suggestedWeight, 230)
    }

    func testInsideRangeSuggestsMoreReps() {
        let suggestion = ProgressionAdvisor.suggestion(lastWeight: 225, lastReps: 5, repRange: 4...6)
        XCTAssertEqual(suggestion.direction, .addReps)
        XCTAssertEqual(suggestion.suggestedWeight, 225)
    }

    func testBelowRangeSuggestsLessWeight() {
        let suggestion = ProgressionAdvisor.suggestion(lastWeight: 225, lastReps: 3, repRange: 4...6)
        XCTAssertEqual(suggestion.direction, .reduceWeight)
        XCTAssertEqual(suggestion.suggestedWeight, 220)
    }

    func testNoHistoryHoldsSteady() {
        let suggestion = ProgressionAdvisor.suggestion(lastWeight: 0, lastReps: 0)
        XCTAssertEqual(suggestion.direction, .holdSteady)
    }

    func testCustomIncrement() {
        let suggestion = ProgressionAdvisor.suggestion(lastWeight: 315, lastReps: 6, repRange: 4...6, increment: 10)
        XCTAssertEqual(suggestion.suggestedWeight, 325)
    }
}

final class PlateCalculatorLogicTests: XCTestCase {
    func testExactLoad() {
        // 225 lb on an Olympic bar = 45 bar + 2x90 = one 45 + one 25 + one 10 + one 5 + one 2.5? No:
        // (225 - 45) / 2 = 90 per side → 45 + 35 + 10 = 90.
        let result = PlateCalculator.calculate(
            targetWeight: 225,
            barbell: .olympic,
            unit: .pounds,
            availablePlates: PlateCalculator.defaultLbPlates
        )

        XCTAssertTrue(result.isExact)
        XCTAssertEqual(result.achievedWeight, 225, accuracy: 0.001)

        let perSideTotal = result.platesPerSide.reduce(0.0) { $0 + $1.weight * Double($1.count) }
        XCTAssertEqual(perSideTotal, 90, accuracy: 0.001)
    }

    func testTargetBelowBarLoadsNothing() {
        let result = PlateCalculator.calculate(
            targetWeight: 30,
            barbell: .olympic,
            unit: .pounds,
            availablePlates: PlateCalculator.defaultLbPlates
        )

        XCTAssertTrue(result.platesPerSide.isEmpty)
        XCTAssertEqual(result.achievedWeight, 45, accuracy: 0.001)
    }

    func testInexactTargetReportsLeftover() {
        let result = PlateCalculator.calculate(
            targetWeight: 47,
            barbell: .olympic,
            unit: .pounds,
            availablePlates: PlateCalculator.defaultLbPlates
        )

        XCTAssertFalse(result.isExact)
        XCTAssertEqual(result.achievedWeight, 45, accuracy: 0.001)
        XCTAssertEqual(result.leftover, 2, accuracy: 0.001)
    }
}

final class WorkoutNameFormatterTests: XCTestCase {
    func testCollapsesWhitespace() {
        XCTAssertEqual(WorkoutNameFormatter.displayName(for: "  Push   Day  "), "Push Day")
    }

    func testLegacyPlaceholdersBecomeGeneric() {
        XCTAssertEqual(WorkoutNameFormatter.displayName(for: "Current Workout"), "Workout")
        XCTAssertEqual(WorkoutNameFormatter.displayName(for: "current draft"), "Workout")
        XCTAssertEqual(WorkoutNameFormatter.displayName(for: ""), "Workout")
        XCTAssertEqual(WorkoutNameFormatter.displayName(for: "   "), "Workout")
    }

    func testSpecificNameIsNilForPlaceholders() {
        XCTAssertNil(WorkoutNameFormatter.specificName(for: "Current Workout"))
        XCTAssertNil(WorkoutNameFormatter.specificName(for: ""))
        XCTAssertEqual(WorkoutNameFormatter.specificName(for: "Push Day"), "Push Day")
    }

    func testClampsVeryLongNames() {
        let longName = String(repeating: "a", count: 200)
        XCTAssertEqual(WorkoutNameFormatter.displayName(for: longName).count, 80)
    }
}

final class WorkoutCSVExporterTests: XCTestCase {
    func testEscaping() {
        XCTAssertEqual(WorkoutCSVExporter.escape("plain"), "plain")
        XCTAssertEqual(WorkoutCSVExporter.escape("with,comma"), "\"with,comma\"")
        XCTAssertEqual(WorkoutCSVExporter.escape("say \"hi\""), "\"say \"\"hi\"\"\"")
    }

    @MainActor
    func testCSVIncludesOnlyCompletedWorkouts() {
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        let completed = Workout(name: "Push Day")
        completed.isCompleted = true
        _ = completed.addSet(exercise: exercise, weight: 225, reps: 5)

        let draft = Workout(name: "Unfinished")
        _ = draft.addSet(exercise: exercise, weight: 135, reps: 8)

        let csv = WorkoutCSVExporter.csv(for: [completed, draft])
        let lines = csv.components(separatedBy: "\n")

        XCTAssertEqual(lines.first, WorkoutCSVExporter.header)
        XCTAssertEqual(lines.count, 2, "Header plus exactly one logged set from the completed workout")
        XCTAssertTrue(lines[1].contains("Push Day"))
        XCTAssertTrue(lines[1].contains("225"))
        XCTAssertFalse(csv.contains("Unfinished"))
    }

    @MainActor
    func testWarmupSetsMarkedAndZeroVolume() {
        let exercise = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])

        let workout = Workout(name: "Leg Day")
        workout.isCompleted = true
        _ = workout.addSet(exercise: exercise, weight: 135, reps: 5, isWarmup: true)

        let csv = WorkoutCSVExporter.csv(for: [workout])
        let lines = csv.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[1].contains("warmup"))
        XCTAssertTrue(lines[1].hasSuffix(",0"), "Warm-up sets contribute zero working volume")
    }
}
