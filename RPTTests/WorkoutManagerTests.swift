//
//  WorkoutManagerTests.swift
//  RPTTests
//
//  Created by Michael Moore on 4/30/25.
//

import XCTest
@testable import RPT

@MainActor
final class WorkoutManagerLogicTests: XCTestCase {
    var manager: WorkoutManager!

    override func setUp() {
        super.setUp()
        // Use the shared singleton for logic tests
        manager = WorkoutManager.shared
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - RPT Weight Calculation

    func testCalculateRPTWeights_withMultipleDrops() {
        // Given
        let firstSetWeight: Double = 250.0
        let drops: [Double] = [0.05, 0.15, 0.25]
        // When
        let weights = manager.calculateRPTWeights(
            firstSetWeight: firstSetWeight,
            percentageDrops: drops
        )
        // Then
        XCTAssertEqual(weights.count, drops.count)
        XCTAssertEqual(weights[0], 250 * 0.95, accuracy: 1e-6)
        XCTAssertEqual(weights[1], 250 * 0.85, accuracy: 1e-6)
        XCTAssertEqual(weights[2], 250 * 0.75, accuracy: 1e-6)
    }

    func testCalculateRPTWeights_withEmptyDrops() {
        // Given
        let firstSetWeight: Double = 180.0
        let drops: [Double] = []
        // When
        let weights = manager.calculateRPTWeights(
            firstSetWeight: firstSetWeight,
            percentageDrops: drops
        )
        // Then
        XCTAssertTrue(weights.isEmpty)
    }

    // MARK: - Weight & Volume Formatting

    func testFormatWeight_displaysOneDecimal() {
        // Given
        let weight: Double = 200.456
        // When
        let formatted = manager.formatWeight(weight)
        // Then
        XCTAssertEqual(formatted, "200.5 lb")
    }

    func testFormatWeight_nonFiniteAndNegativeFallbackToZero() {
        // Given/When
        let nonFinite = manager.formatWeight(.infinity)
        let negative = manager.formatWeight(-45.0)

        // Then
        XCTAssertEqual(nonFinite, "0.0 lb")
        XCTAssertEqual(negative, "0.0 lb")
    }

    func testFormatVolume_belowThreshold_wholeNumber() {
        // Given
        let volume: Double = 750.0
        // When
        let formatted = manager.formatVolume(volume)
        // Then
        XCTAssertEqual(formatted, "750 lb")
    }
    
    func testFormatVolume_belowThreshold_decimalNumber() {
        // Given
        let volume: Double = 750.5
        // When
        let formatted = manager.formatVolume(volume)
        // Then
        XCTAssertEqual(formatted, "750.5 lb")
    }

    func testFormatVolume_aboveThreshold_wholeNumber() {
        // Given
        let volume: Double = 2000.0
        // When
        let formatted = manager.formatVolume(volume)
        // Then
        XCTAssertEqual(formatted, "2k lb")
    }

    func testFormatVolume_aboveThreshold_fractionalThousands() {
        // Given
        let volume: Double = 1500.0
        // When
        let formatted = manager.formatVolume(volume)
        // Then
        XCTAssertEqual(formatted, "1.5k lb")
    }

    func testFormatVolume_exactlyThreshold() {
        // Given
        let volume: Double = 1000.0
        // When
        let formatted = manager.formatVolume(volume)
        // Then
        XCTAssertEqual(formatted, "1k lb")
    }

    func testFormatVolume_nonFiniteAndNegativeFallbackToZero() {
        // Given/When
        let nonFinite = manager.formatVolume(.infinity)
        let negative = manager.formatVolume(-250.0)

        // Then
        XCTAssertEqual(nonFinite, "0 lb")
        XCTAssertEqual(negative, "0 lb")
    }

    func testRoundToNearest5_nonFiniteAndNegativeFallbackToZero() {
        // Given/When
        let nonFinite = manager.roundToNearest5(.infinity)
        let negative = manager.roundToNearest5(-2.0)

        // Then
        XCTAssertEqual(nonFinite, 0)
        XCTAssertEqual(negative, 0)
    }

    func testRoundToNearest5_roundsValidInput() {
        // Given/When
        let roundedDown = manager.roundToNearest5(182.0)
        let roundedUp = manager.roundToNearest5(183.0)

        // Then
        XCTAssertEqual(roundedDown, 180)
        XCTAssertEqual(roundedUp, 185)
    }

    // MARK: - Duration Sanitization

    func testSanitizedDurationSinceWorkoutStart_clampsFutureStartDateToZero() {
        // Given
        let now = Date()
        let futureStartDate = now.addingTimeInterval(300)

        // When
        let duration = manager.sanitizedDurationSinceWorkoutStart(futureStartDate, now: now)

        // Then
        XCTAssertEqual(duration, 0, accuracy: 0.0001)
    }

    func testSanitizedDurationSinceWorkoutStart_returnsElapsedTimeForPastStartDate() {
        // Given
        let now = Date()
        let pastStartDate = now.addingTimeInterval(-125)

        // When
        let duration = manager.sanitizedDurationSinceWorkoutStart(pastStartDate, now: now)

        // Then
        XCTAssertEqual(duration, 125, accuracy: 0.0001)
    }

    // MARK: - Workout Stats Aggregation

    func testAggregateCompletedWorkoutStats_excludesIncompleteWorkouts() {
        // Given
        let completedWorkout = Workout(
            date: Date(),
            name: "Completed",
            duration: 1800,
            isCompleted: true
        )
        let inProgressWorkout = Workout(
            date: Date(),
            name: "In Progress",
            duration: 1200,
            isCompleted: false
        )
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = completedWorkout.addSet(exercise: exercise, weight: 100, reps: 5) // 500
        _ = inProgressWorkout.addSet(exercise: exercise, weight: 200, reps: 5) // 1000 (should be ignored)

        // When
        let stats = manager.aggregateCompletedWorkoutStats(from: [completedWorkout, inProgressWorkout])

        // Then
        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats.totalVolume, 500, accuracy: 0.0001)
        XCTAssertEqual(stats.averageDuration, 1800, accuracy: 0.0001)
    }

    func testAggregateCompletedWorkoutStats_emptyWhenOnlyIncompleteWorkouts() {
        // Given
        let inProgressWorkout = Workout(
            date: Date(),
            name: "In Progress",
            duration: 1200,
            isCompleted: false
        )

        // When
        let stats = manager.aggregateCompletedWorkoutStats(from: [inProgressWorkout])

        // Then
        XCTAssertEqual(stats.count, 0)
        XCTAssertEqual(stats.totalVolume, 0, accuracy: 0.0001)
        XCTAssertEqual(stats.averageDuration, 0, accuracy: 0.0001)
    }

    func testAggregateCompletedWorkoutStats_clampsCorruptedNegativeValues() {
        // Given
        let corruptedWorkout = Workout(
            date: Date(),
            name: "Corrupted",
            duration: -300,
            isCompleted: true
        )
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = corruptedWorkout.addSet(exercise: exercise, weight: -100, reps: 5) // -500 (should clamp)

        // When
        let stats = manager.aggregateCompletedWorkoutStats(from: [corruptedWorkout])

        // Then
        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats.totalVolume, 0, accuracy: 0.0001)
        XCTAssertEqual(stats.averageDuration, 0, accuracy: 0.0001)
    }
    
    // MARK: - Workout Model Tests
    
    func testWorkoutTotalVolumeCalculation() {
        // Given
        let workout = Workout(name: "Test Workout")
        let exercise = Exercise(name: "Test Exercise", category: .compound, primaryMuscleGroups: [.abs])
        
        // When - empty workout
        // Then
        XCTAssertEqual(workout.totalVolume, 0.0)
        
        // When - add one set
        _ = workout.addSet(exercise: exercise, weight: 100, reps: 10)
        // Then
        XCTAssertEqual(workout.totalVolume, 1000.0)
        
        // When - add another set
        _ = workout.addSet(exercise: exercise, weight: 90, reps: 12)
        // Then
        XCTAssertEqual(workout.totalVolume, 1000.0 + 1080.0)
    }
    
    func testWorkoutFormattedTotalVolume() {
        // Given
        let workout = Workout(name: "Test Workout")
        let exercise = Exercise(name: "Test Exercise", category: .compound, primaryMuscleGroups: [.abs])
        
        // When - whole number volume
        _ = workout.addSet(exercise: exercise, weight: 100, reps: 10) // 1000 volume
        // Then
        XCTAssertEqual(workout.formattedTotalVolume(), "1000 lb")
        
        // When - decimal volume
        workout.sets.removeAll() // Clear sets
        _ = workout.addSet(exercise: exercise, weight: 100, reps: 5) // 500 volume
        _ = workout.addSet(exercise: exercise, weight: 90, reps: 5) // 450 volume
        // Then - total should be 950
        XCTAssertEqual(workout.formattedTotalVolume(), "950 lb")
        
        // When - add fraction
        _ = workout.addSet(exercise: exercise, weight: 45, reps: 1) // 45 volume
        // Then - total should be 995
        XCTAssertEqual(workout.formattedTotalVolume(), "995 lb")
    }
}
