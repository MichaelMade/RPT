//
//  FormattingTests.swift
//  RPTTests
//
//  Created by Michael Moore on 5/2/25.
//

import XCTest
@testable import RPT

@MainActor
final class FormattingTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Weight Formatting Tests
    
    func testWeightFormatting_integerAndDouble() {
        let settingsManager = SettingsManager.shared
        
        // Test integer weight formatting
        XCTAssertEqual(settingsManager.formatWeight(225), "225 lb", "Integer weight should format correctly")
        XCTAssertEqual(settingsManager.formatWeight(0), "0 lb", "Zero weight should format correctly")
        XCTAssertEqual(settingsManager.formatWeight(-45), "0 lb", "Negative integer weight should clamp to zero")
        XCTAssertEqual(settingsManager.formatWeight(225, useUnit: false), "225", "Integer weight without unit should format correctly")
        
        // Test double weight formatting
        XCTAssertEqual(settingsManager.formatWeight(135.0), "135.0 lb", "Double weight should format correctly")
        XCTAssertEqual(settingsManager.formatWeight(135.5), "135.5 lb", "Double weight with decimal should format correctly")
        XCTAssertEqual(settingsManager.formatWeight(-2.5), "0.0 lb", "Negative double weight should clamp to zero")
        XCTAssertEqual(settingsManager.formatWeight(.infinity), "0.0 lb", "Non-finite double weight should fail safe to zero")
        XCTAssertEqual(settingsManager.formatWeight(135.5, useUnit: false), "135.5", "Double weight without unit should format correctly")
    }
    
    // MARK: - RPT Calculation Tests
    
    func testRPTCalculationExample() {
        let settingsManager = SettingsManager.shared

        // Save current settings to restore later
        let originalDrops = settingsManager.settings.defaultRPTPercentageDrops

        // Set test values
        _ = settingsManager.updateRPTPercentageDropsSafely(drops: [0.0, 0.1, 0.2])

        // Test calculation with 200 lb
        let example = settingsManager.calculateRPTExample(firstSetWeight: 200)
        XCTAssertEqual(example, "180 → 160 lb", "RPT calculation example should format correctly")

        // Test calculation with 225 lb
        let example2 = settingsManager.calculateRPTExample(firstSetWeight: 225)
        XCTAssertEqual(example2, "205 → 180 lb", "RPT calculation example should format correctly for 225 lb")

        // Restore original settings
        _ = settingsManager.updateRPTPercentageDropsSafely(drops: originalDrops)
    }

    func testRPTCalculationExample_topSetOnlyFallback() {
        let settingsManager = SettingsManager.shared

        // Save current settings to restore later
        let originalDrops = settingsManager.settings.defaultRPTPercentageDrops

        // No back-off sets configured
        _ = settingsManager.updateRPTPercentageDropsSafely(drops: [0.0])

        let example = settingsManager.calculateRPTExample(firstSetWeight: 200)
        XCTAssertEqual(example, "Top set only", "RPT calculation example should provide a helpful fallback when no back-off sets are configured")

        // Restore original settings
        _ = settingsManager.updateRPTPercentageDropsSafely(drops: originalDrops)
    }
    
    // MARK: - Summary Generation Tests
    
    func testWorkoutSummaryGeneration() {
        // Create a test workout
        let workout = Workout(name: "Test Workout")
        let exercise = Exercise(name: "Test Exercise", category: .compound, primaryMuscleGroups: [.abs])
        
        // Add some sets
        _ = workout.addSet(exercise: exercise, weight: 225, reps: 5)
        _ = workout.addSet(exercise: exercise, weight: 205, reps: 6)
        
        // Generate summary
        let summary = workout.generateSummary()
        
        // Verify the summary contains the correct weight unit (lb)
        XCTAssertTrue(summary.contains("lb"), "Summary should contain 'lb' as the weight unit")
        XCTAssertFalse(summary.contains("kg"), "Summary should not contain 'kg' as the weight unit")
        
        // Formatted summary should also use lb
        let formattedSummary = workout.generateFormattedSummary()
        XCTAssertTrue(formattedSummary.contains("lb"), "Formatted summary should contain 'lb' as the weight unit")
        XCTAssertFalse(formattedSummary.contains("kg"), "Formatted summary should not contain 'kg' as the weight unit")
    }
    
    // MARK: - Units Consistency Tests

    func testWorkoutDetailSetDisplayText_usesBodyweightAwareFormatting() {
        let bodyweightExercise = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])
        let weightedExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        let bodyweightSet = ExerciseSet(weight: 0, reps: 12, exercise: bodyweightExercise)
        let weightedSet = ExerciseSet(weight: 185, reps: 8, exercise: weightedExercise)

        XCTAssertEqual(ExerciseSection.setDisplayText(for: bodyweightSet), "BW × 12 reps")
        XCTAssertEqual(ExerciseSection.setDisplayText(for: weightedSet), "185 lb × 8 reps")
    }

    func testExerciseSetRowDisplayWeightText_usesBodyweightLabelForZeroWeightBodyweightSets() {
        XCTAssertEqual(
            ExerciseSetRowView.displayWeightText(weight: 0, exerciseCategory: .bodyweight),
            "BW"
        )
        XCTAssertEqual(
            ExerciseSetRowView.displayWeightText(weight: 45, exerciseCategory: .bodyweight),
            "45 lb"
        )
        XCTAssertEqual(
            ExerciseSetRowView.displayWeightText(weight: 0, exerciseCategory: .compound),
            "0 lb"
        )
    }

    func testExerciseSetRowDisplayRepsText_handlesSingularAndPlural() {
        XCTAssertEqual(ExerciseSetRowView.displayRepsText(1), "1 rep")
        XCTAssertEqual(ExerciseSetRowView.displayRepsText(8), "8 reps")
    }

    func testWorkoutRowSetCountText_prefersCompletedWorkingSetsAndUsesSingularPluralGrammar() {
        let workout = Workout(name: "Workout Row Set Count")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: exercise, weight: 45, reps: 10, isWarmup: true)
        _ = workout.addSet(exercise: exercise, weight: 225, reps: 5)
        _ = workout.addSet(exercise: exercise, weight: 185, reps: 0)

        XCTAssertEqual(WorkoutRow.setCountText(for: workout), "1 set")

        _ = workout.addSet(exercise: exercise, weight: 205, reps: 6)

        XCTAssertEqual(WorkoutRow.setCountText(for: workout), "2 sets")
    }

    func testWorkoutRowExerciseCountText_prefersCompletedWorkingSetExercisesWithFallback() {
        let workout = Workout(name: "Workout Row Exercise Count")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])

        _ = workout.addSet(exercise: bench, weight: 225, reps: 5)
        _ = workout.addSet(exercise: squat, weight: 95, reps: 8, isWarmup: true)

        XCTAssertEqual(WorkoutRow.exerciseCountText(for: workout), "1 exercise")

        _ = workout.addSet(exercise: squat, weight: 185, reps: 5)

        XCTAssertEqual(WorkoutRow.exerciseCountText(for: workout), "2 exercises")

        let fallbackWorkout = Workout(name: "Workout Row Fallback")
        _ = fallbackWorkout.addSet(exercise: bench, weight: 135, reps: 0)
        _ = fallbackWorkout.addSet(exercise: squat, weight: 185, reps: 0)

        XCTAssertEqual(WorkoutRow.exerciseCountText(for: fallbackWorkout), "2 exercises")
    }

    func testWorkoutRowSecondaryMetric_prefersBodyweightRepsWhenVolumeIsZero() {
        let workout = Workout(name: "Bodyweight Workout")
        let pullUp = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])

        _ = workout.addSet(exercise: pullUp, weight: 0, reps: 8)
        _ = workout.addSet(exercise: pullUp, weight: 0, reps: 6)

        let metric = WorkoutRow.secondaryMetric(for: workout)

        XCTAssertEqual(metric?.label, "Total Reps")
        XCTAssertEqual(metric?.value, "14 reps")
    }

    func testWorkoutRowSecondaryMetric_prefersVolumeWhenWeightedWorkExists() {
        let workout = Workout(name: "Mixed Workout")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let pullUp = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])

        _ = workout.addSet(exercise: bench, weight: 185, reps: 5)
        _ = workout.addSet(exercise: pullUp, weight: 0, reps: 10)

        let metric = WorkoutRow.secondaryMetric(for: workout)

        XCTAssertEqual(metric?.label, "Total Volume")
        XCTAssertEqual(metric?.value, "925 lb")
    }
    
    func testWeightUnitsConsistency() {
        let workoutManager = WorkoutManager.shared
        let settingsManager = SettingsManager.shared
        
        // Both weight formatting methods should use 'lb'
        XCTAssertTrue(workoutManager.formatWeight(135.0).contains("lb"), "WorkoutManager should format weight with 'lb'")
        XCTAssertTrue(settingsManager.formatWeight(135).contains("lb"), "SettingsManager should format weight with 'lb'")
        
        // Volume formatting should use 'lb'
        XCTAssertTrue(workoutManager.formatVolume(2000.0).contains("lb"), "Volume formatting should use 'lb'")
        
        // Create a workout and test its formatted volume
        let workout = Workout(name: "Test")
        XCTAssertTrue(workout.formattedTotalVolume().contains("lb"), "Workout volume formatting should use 'lb'")
    }
}
