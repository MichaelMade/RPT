//
//  KilogramTrainingTests.swift
//  RPTTests
//
//  The training math for a lifter who works in kilograms: estimates,
//  warm-up ramps, progression targets, follow-up workouts, volume and
//  export. Pound behaviour is covered by the suites that predate units.
//

import XCTest
@testable import RPT

final class KilogramTrainingMathTests: XCTestCase {
    private func makeExercise(category: ExerciseCategory = .compound) -> Exercise {
        Exercise(name: "Squat", category: category, primaryMuscleGroups: [.quadriceps])
    }

    /// A completed workout whose working sets were logged in kilograms.
    private func makeKilogramWorkout(_ sets: [(load: Double, reps: Int)], exercise: Exercise? = nil) -> Workout {
        let exercise = exercise ?? makeExercise()
        let workout = Workout(name: "Leg Day", isCompleted: true)

        for plan in sets {
            let set = workout.addSet(exercise: exercise, weight: 0, reps: plan.reps)
            set.setLoad(plan.load, in: .kilograms)
            set.completedAt = Date()
        }

        return workout
    }

    // MARK: - Estimated 1RM

    func testEstimateUsesTheExactLoadNotTheRoundedPound() {
        let exercise = makeExercise()
        let set = ExerciseSet(weight: 0, reps: 5, exercise: exercise)
        set.setLoad(100, in: .kilograms)

        // Epley on 100 kg x 5 is 116.67 kg.
        let estimate = OneRepMax.bestEstimate(in: [set])

        XCTAssertEqual(WeightUnit.kilograms.converting(estimate, from: .pounds), 116.667, accuracy: 0.001)
        XCTAssertEqual(OneRepMax.formatted(estimate, unit: .kilograms), "116.7 kg")
        XCTAssertEqual(OneRepMax.formatted(estimate, unit: .pounds), "257 lb")
    }

    func testEstimateOfNothingIsADash() {
        XCTAssertEqual(OneRepMax.formatted(0, unit: .kilograms), "—")
        XCTAssertEqual(OneRepMax.estimate(pounds: .nan, reps: 5), 0)
    }

    // MARK: - Warm-up ramp

    func testWarmupRampUsesATwentyKilogramBarAndLoadableSteps() {
        let plan = WarmupPlanner.plan(topSetLoad: 100, unit: .kilograms)

        XCTAssertEqual(plan.map(\.load), [20, 40, 60, 80])
        XCTAssertEqual(plan.map(\.reps), [10, 5, 3, 1])
    }

    func testWarmupRampRoundsToTwoAndAHalfKilograms() {
        let plan = WarmupPlanner.plan(topSetLoad: 142.5, unit: .kilograms)

        // 57, 85.5 and 114 round to the nearest 2.5 kg.
        XCTAssertEqual(plan.map(\.load), [20, 57.5, 85, 115])
    }

    func testWarmupRampForALightKilogramTopSet() {
        XCTAssertEqual(WarmupPlanner.plan(topSetLoad: 20, unit: .kilograms), [WarmupLoadStep(load: 0, reps: 10)])
        XCTAssertTrue(WarmupPlanner.plan(topSetLoad: 0, unit: .kilograms).isEmpty)
        // 30 kg: 40% and 60% are below the bar and collapse into it; 80%
        // (24) loads as 25.
        XCTAssertEqual(WarmupPlanner.plan(topSetLoad: 30, unit: .kilograms).map(\.load), [20, 25])
        // 22.5 kg: nothing fits between the bar and the top set.
        XCTAssertEqual(WarmupPlanner.plan(topSetLoad: 22.5, unit: .kilograms).map(\.load), [20])
    }

    func testPoundRampIsUnchanged() {
        XCTAssertEqual(WarmupPlanner.plan(topSetWeight: 225).map(\.weight), [45, 90, 135, 180])
        XCTAssertEqual(
            WarmupPlanner.plan(topSetLoad: 225, unit: .pounds).map(\.load),
            [45, 90, 135, 180]
        )
    }

    // MARK: - Progression

    func testProgressionAddsTwoAndAHalfKilograms() {
        let suggestion = ProgressionAdvisor.suggestion(lastLoad: 100, unit: .kilograms, lastReps: 6)

        XCTAssertEqual(suggestion.direction, .increaseWeight)
        XCTAssertEqual(suggestion.suggestedLoad, 102.5)
        XCTAssertEqual(suggestion.formattedLoad, "102.5 kg")
        XCTAssertEqual(suggestion.note, "You hit 6 reps — load 102.5 kg and aim for 4+ reps.")
        XCTAssertTrue(suggestion.note.contains(suggestion.formattedLoad), "The view highlights the target inside the note")
    }

    func testProgressionBacksOffTwoAndAHalfKilograms() {
        let suggestion = ProgressionAdvisor.suggestion(lastLoad: 100, unit: .kilograms, lastReps: 3)

        XCTAssertEqual(suggestion.direction, .reduceWeight)
        XCTAssertEqual(suggestion.suggestedLoad, 97.5)
        XCTAssertEqual(suggestion.note, "Below the rep range — drop to 97.5 kg and rebuild to 6 reps.")
    }

    func testProgressionHoldsAMicroplateLoadExactly() {
        let suggestion = ProgressionAdvisor.suggestion(lastLoad: 61.25, unit: .kilograms, lastReps: 5)

        XCTAssertEqual(suggestion.direction, .addReps)
        XCTAssertEqual(suggestion.note, "Stay at 61.25 kg and push for 6 reps.")
    }

    func testPoundProgressionIsUnchanged() {
        let suggestion = ProgressionAdvisor.suggestion(lastWeight: 225, lastReps: 6)

        XCTAssertEqual(suggestion.suggestedWeight, 230)
        XCTAssertEqual(suggestion.unit, .pounds)
        XCTAssertEqual(suggestion.note, "You hit 6 reps — load 230 lb and aim for 4+ reps.")
        XCTAssertEqual(suggestion.formattedLoad, "230 lb")
    }

    // MARK: - Volume

    func testVolumeOfKilogramSetsIsExact() {
        let workout = makeKilogramWorkout([(100, 5), (90, 6), (85, 8)])

        // 500 + 540 + 680
        XCTAssertEqual(workout.formattedTotalVolume(in: .kilograms), "1720 kg")
        XCTAssertEqual(
            WeightUnit.kilograms.converting(workout.totalVolume, from: .pounds),
            1_720,
            accuracy: 0.000_001
        )
    }

    func testFractionalKilogramVolumeIsWrittenToTheTenth() {
        let workout = makeKilogramWorkout([(61.25, 5)])

        XCTAssertEqual(workout.formattedTotalVolume(in: .kilograms), "306.3 kg")
    }

    func testPoundHistoryReadsInKilogramsAfterSwitching() {
        let exercise = makeExercise()
        let workout = Workout(name: "Old Session", isCompleted: true)
        _ = workout.addSet(exercise: exercise, weight: 225, reps: 5)

        XCTAssertEqual(workout.formattedTotalVolume(in: .pounds), "1125 lb")
        XCTAssertEqual(workout.formattedTotalVolume(in: .kilograms), "510.3 kg")
    }

    // MARK: - Follow-up workout

    func testFollowUpTargetsAreRoundedInKilograms() {
        let workout = makeKilogramWorkout([(100, 5), (90, 6), (85, 8)])

        let followUp = workout.createFollowUpWorkout(unit: .kilograms)
        let loads = followUp.setsInLoggedOrder.map { $0.load(in: .kilograms) }

        // Top set +2.5% is 102.5; the back-offs keep their 10% and 15%
        // drops (92.25 and 87.125) rounded to 2.5 kg.
        XCTAssertEqual(loads, [102.5, 92.5, 87.5])
        XCTAssertTrue(followUp.sets.allSatisfy { $0.loadUnit == .kilograms })
        XCTAssertTrue(followUp.sets.allSatisfy { !$0.isCompletedLoggedSet }, "Targets are planned, never logged")
    }

    func testFollowUpOfFiftyKilogramsGoesUp() {
        // 50 x 1.025 is exactly halfway between 50 and 52.5.
        let workout = makeKilogramWorkout([(50, 5), (45, 6)])

        let followUp = workout.createFollowUpWorkout(unit: .kilograms)

        XCTAssertEqual(followUp.setsInLoggedOrder.map { $0.load(in: .kilograms) }, [52.5, 47.5])
    }

    func testFollowUpOfAHundredPoundsGoesUp() {
        // The same halfway case in pounds. It used to stay at 100.
        let exercise = makeExercise()
        let workout = Workout(name: "Session", isCompleted: true)
        _ = workout.addSet(exercise: exercise, weight: 100, reps: 5)

        let followUp = workout.createFollowUpWorkout(unit: .pounds)

        XCTAssertEqual(followUp.sets.map(\.weight), [105])
    }

    func testFollowUpOfPoundHistoryForAKilogramLifterIsLoadable() {
        let exercise = makeExercise()
        let workout = Workout(name: "Old Session", isCompleted: true)
        _ = workout.addSet(exercise: exercise, weight: 225, reps: 5)
        _ = workout.addSet(exercise: exercise, weight: 205, reps: 6)

        let followUp = workout.createFollowUpWorkout(unit: .kilograms)
        let loads = followUp.setsInLoggedOrder.map { $0.load(in: .kilograms) }

        // 225 lb is 102.06 kg; +2.5% is 104.6, which loads as 105.
        XCTAssertEqual(loads.first, 105)
        XCTAssertTrue(loads.allSatisfy { $0.truncatingRemainder(dividingBy: 2.5) == 0 })
    }

    func testPoundFollowUpIsUnchanged() {
        let exercise = makeExercise()
        let workout = Workout(name: "Session", isCompleted: true)
        _ = workout.addSet(exercise: exercise, weight: 200, reps: 5)
        _ = workout.addSet(exercise: exercise, weight: 180, reps: 6)

        let followUp = workout.createFollowUpWorkout(unit: .pounds)

        XCTAssertEqual(followUp.setsInLoggedOrder.map(\.weight), [205, 185])
        XCTAssertTrue(followUp.sets.allSatisfy { $0.loadValue == nil }, "Pound workouts keep the stored shape they always had")
    }

    func testBodyweightFollowUpStaysBodyweight() {
        let pullUp = makeExercise(category: .bodyweight)
        let workout = Workout(name: "Session", isCompleted: true)
        _ = workout.addSet(exercise: pullUp, weight: 0, reps: 10)

        let followUp = workout.createFollowUpWorkout(unit: .kilograms)

        XCTAssertEqual(followUp.sets.map(\.weight), [0])
        XCTAssertNil(followUp.sets.first?.loadValue)
    }

    // MARK: - Saving a workout as a template

    func testSavedTemplateKeepsTheKilogramDropPercentage() {
        let cases: [(top: Double, backoff: Double, percent: Int)] = [
            (40, 36, 90), (62.5, 50, 80), (125, 112.5, 90), (150, 127.5, 85), (100, 100, 100)
        ]

        for plan in cases {
            let workout = makeKilogramWorkout([(plan.top, 5), (plan.backoff, 7)])
            let ranges = WorkoutTemplateBuilder.templateExercises(from: workout).first?.repRanges ?? []
            let stored = ranges.last?.percentageOfFirstSet ?? 0

            XCTAssertEqual(stored, Double(plan.percent) / 100, accuracy: 0.000_1, "\(plan.top) -> \(plan.backoff) kg")
            XCTAssertEqual(Int((stored * 100).rounded()), plan.percent, "What the template screen shows")
        }
    }

    func testSavedTemplatePercentageForPoundsIsUnchanged() {
        let exercise = makeExercise()
        let workout = Workout(name: "Session", isCompleted: true)
        _ = workout.addSet(exercise: exercise, weight: 200, reps: 5)
        _ = workout.addSet(exercise: exercise, weight: 180, reps: 7)

        let ranges = WorkoutTemplateBuilder.templateExercises(from: workout).first?.repRanges ?? []

        XCTAssertEqual(ranges.last?.percentageOfFirstSet, 0.9)
    }

    // MARK: - CSV

    func testExportIsInTheLiftersUnitAndSaysSo() {
        let workout = makeKilogramWorkout([(102.5, 5), (61.25, 8)])

        let lines = WorkoutCSVExporter.csv(for: [workout], unit: .kilograms).components(separatedBy: "\n")

        XCTAssertEqual(lines.first, "date,workout,exercise,set_type,weight_kg,reps,rpe,volume_kg")
        XCTAssertTrue(lines[1].hasSuffix(",working,102.5,5,,512.5"), lines[1])
        XCTAssertTrue(lines[2].hasSuffix(",working,61.25,8,,490"), lines[2])
    }

    func testOddKilogramLoadIsExportedAsTyped() {
        let workout = makeKilogramWorkout([(7.26, 10), (61.35, 5)])

        let lines = WorkoutCSVExporter.csv(for: [workout], unit: .kilograms).components(separatedBy: "\n")

        XCTAssertTrue(lines[1].hasSuffix(",working,7.26,10,,72.6"), lines[1])
        XCTAssertTrue(lines[2].hasSuffix(",working,61.35,5,,306.75"), lines[2])
    }

    func testPoundExportIsUnchanged() {
        let exercise = makeExercise()
        let workout = Workout(name: "Session", isCompleted: true)
        _ = workout.addSet(exercise: exercise, weight: 225, reps: 5)

        let lines = WorkoutCSVExporter.csv(for: [workout], unit: .pounds).components(separatedBy: "\n")

        XCTAssertEqual(lines.first, WorkoutCSVExporter.header)
        XCTAssertEqual(WorkoutCSVExporter.header, "date,workout,exercise,set_type,weight_lb,reps,rpe,volume_lb")
        XCTAssertTrue(lines[1].hasSuffix(",working,225,5,,1125"), lines[1])
    }

    func testEachExportedRowAddsUpWhenTheUnitWasSwitched() {
        let workout = makeKilogramWorkout([(100, 5)])

        let lines = WorkoutCSVExporter.csv(for: [workout], unit: .pounds).components(separatedBy: "\n")

        // 100 kg is written as 220 lb, and the volume is 220 x 5.
        XCTAssertTrue(lines[1].hasSuffix(",working,220,5,,1100"), lines[1])
    }
}
