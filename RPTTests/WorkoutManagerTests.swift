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

    func testCalculateRPTWeights_sanitizesInvalidInputs() {
        // Given
        let firstSetWeight: Double = -.infinity
        let drops: [Double] = [-0.1, .infinity, 0.25, 1.5]

        // When
        let weights = manager.calculateRPTWeights(
            firstSetWeight: firstSetWeight,
            percentageDrops: drops
        )

        // Then
        XCTAssertEqual(weights, [0, 0, 0, 0])
    }

    func testCalculateRPTWeights_clampsDropRangeBetweenZeroAndOne() {
        // Given
        let firstSetWeight: Double = 200
        let drops: [Double] = [-0.2, 0.1, 1.2]

        // When
        let weights = manager.calculateRPTWeights(
            firstSetWeight: firstSetWeight,
            percentageDrops: drops
        )

        // Then
        XCTAssertEqual(weights[0], 200, accuracy: 1e-6) // clamped to 0 drop
        XCTAssertEqual(weights[1], 180, accuracy: 1e-6)
        XCTAssertEqual(weights[2], 0, accuracy: 1e-6)   // clamped to 1 drop
    }

    func testCalculateRPTWeights_enforcesMonotonicBackoffWhenDropsAreOutOfOrder() {
        // Given
        let firstSetWeight: Double = 200
        let drops: [Double] = [0.25, 0.1, 0.05]

        // When
        let weights = manager.calculateRPTWeights(
            firstSetWeight: firstSetWeight,
            percentageDrops: drops
        )

        // Then
        XCTAssertEqual(weights[0], 150, accuracy: 1e-6)
        XCTAssertEqual(weights[1], 150, accuracy: 1e-6)
        XCTAssertEqual(weights[2], 150, accuracy: 1e-6)
    }

    func testCalculateRPTWeights_nonFiniteDropsInheritPreviousSafeBackoff() {
        // Given
        let firstSetWeight: Double = 200
        let drops: [Double] = [0.1, .infinity, 0.3]

        // When
        let weights = manager.calculateRPTWeights(
            firstSetWeight: firstSetWeight,
            percentageDrops: drops
        )

        // Then
        XCTAssertEqual(weights[0], 180, accuracy: 1e-6)
        XCTAssertEqual(weights[1], 180, accuracy: 1e-6)
        XCTAssertEqual(weights[2], 140, accuracy: 1e-6)
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

    func testFormatVolume_doesNotPromoteSubThousandNearThreshold() {
        // Given
        let volume: Double = 999.95

        // When
        let formatted = manager.formatVolume(volume)

        // Then
        XCTAssertEqual(formatted, "999.9 lb")
    }

    func testFormatVolume_truncatesSubThousandToSingleDecimal() {
        // Given
        let volume: Double = 999.94

        // When
        let formatted = manager.formatVolume(volume)

        // Then
        XCTAssertEqual(formatted, "999.9 lb")
    }

    func testFormatVolume_supportsMillionScaleAbbreviation() {
        // Given
        let exactMillion: Double = 1_000_000.0
        let nearTwoMillion: Double = 1_999_999.0

        // When
        let exactFormatted = manager.formatVolume(exactMillion)
        let nearFormatted = manager.formatVolume(nearTwoMillion)

        // Then
        XCTAssertEqual(exactFormatted, "1M lb")
        XCTAssertEqual(nearFormatted, "1.9M lb")
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

    // MARK: - Set Input Sanitization

    func testSanitizedSetInput_clampsNegativeValuesAndInvalidRPE() {
        // Given/When
        let sanitized = manager.sanitizedSetInput(weight: -135, reps: -8, rpe: 11)

        // Then
        XCTAssertEqual(sanitized.weight, 0)
        XCTAssertEqual(sanitized.reps, 0)
        XCTAssertNil(sanitized.rpe)
    }

    func testAddSet_sanitizesNegativeValuesBeforePersisting() {
        // Given
        let workout = Workout(name: "Test Workout")
        let exercise = Exercise(name: "Deadlift", category: .compound, primaryMuscleGroups: [.lowerBack])

        // When
        let createdSet = manager.addSet(to: workout, for: exercise, weight: -225, reps: -5, rpe: 0)

        // Then
        XCTAssertEqual(createdSet.weight, 0)
        XCTAssertEqual(createdSet.reps, 0)
        XCTAssertNil(createdSet.rpe)
    }

    func testAddExercise_createsIncompleteSetWithDistantPastCompletionDate() {
        // Given
        let workout = Workout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        // When
        let set = manager.addExercise(to: workout, exercise: exercise)

        // Then
        XCTAssertEqual(set.weight, 0)
        XCTAssertEqual(set.completedAt, .distantPast)
    }

    func testAddSet_withZeroRepsStartsIncomplete() {
        // Given
        let workout = Workout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        // When
        let set = manager.addSet(to: workout, for: exercise, weight: 185, reps: 0)

        // Then
        XCTAssertEqual(set.completedAt, .distantPast)
    }

    func testUpdateSet_clearingWeightResetsCompletionDate() {
        // Given
        let workout = Workout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let set = manager.addSet(to: workout, for: exercise, weight: 185, reps: 5)

        // When
        manager.updateSet(set, weight: 0, reps: 5, rpe: nil)

        // Then
        XCTAssertEqual(set.completedAt, .distantPast)
    }

    func testUpdateSet_clearingRepsResetsCompletionDate() {
        // Given
        let workout = Workout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let set = manager.addSet(to: workout, for: exercise, weight: 185, reps: 5)

        // When
        manager.updateSet(set, weight: 185, reps: 0, rpe: nil)

        // Then
        XCTAssertEqual(set.completedAt, .distantPast)
    }

    func testUpdateSet_marksNonZeroSetCompleteWhenTimestampWasIncomplete() {
        // Given
        let workout = Workout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let set = manager.addSet(to: workout, for: exercise, weight: 185, reps: 8)
        set.completedAt = .distantPast

        // When
        manager.updateSet(set, weight: 185, reps: 8, rpe: nil)

        // Then
        XCTAssertNotEqual(set.completedAt, .distantPast)
    }

    func testUpdateSet_bodyweightSetWithZeroWeightAndRepsMarksComplete() {
        // Given
        let workout = Workout(name: "Test Workout")
        let exercise = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])
        let set = manager.addSet(to: workout, for: exercise, weight: 0, reps: 0)

        // When
        manager.updateSet(set, weight: 0, reps: 8, rpe: nil)

        // Then
        XCTAssertNotEqual(set.completedAt, .distantPast)
        XCTAssertTrue(set.isCompletedWorkingSet)
    }

    func testWorkoutAddSet_withZeroRepsStartsIncomplete() {
        // Given
        let workout = Workout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        // When
        let set = workout.addSet(exercise: exercise, weight: 185, reps: 0)

        // Then
        XCTAssertEqual(set.completedAt, .distantPast)
    }

    func testWorkoutAddSet_withPositiveWeightAndRepsStartsComplete() {
        // Given
        let workout = Workout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        // When
        let set = workout.addSet(exercise: exercise, weight: 185, reps: 5)

        // Then
        XCTAssertNotEqual(set.completedAt, .distantPast)
    }

    // MARK: - Workout Name Sanitization

    func testSanitizedWorkoutName_trimsWhitespace() {
        // Given/When
        let sanitized = manager.sanitizedWorkoutName("  Push Day  ")

        // Then
        XCTAssertEqual(sanitized, "Push Day")
    }

    func testSanitizedWorkoutName_collapsesInternalWhitespaceRuns() {
        // Given/When
        let sanitized = manager.sanitizedWorkoutName("  Upper   Body\n\tSession  ")

        // Then
        XCTAssertEqual(sanitized, "Upper Body Session")
    }

    func testSanitizedWorkoutName_emptyAfterTrimFallsBackToDefault() {
        // Given/When
        let sanitized = manager.sanitizedWorkoutName("   \n\t  ")

        // Then
        XCTAssertEqual(sanitized, "Workout")
    }

    func testSanitizedWorkoutName_clampsLengthToEightyCharacters() {
        // Given
        let longName = String(repeating: "A", count: 120)

        // When
        let sanitized = manager.sanitizedWorkoutName(longName)

        // Then
        XCTAssertEqual(sanitized.count, 80)
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

    func testAggregateCompletedWorkoutStats_ignoresZeroAndCorruptedDurationsWhenAveraging() {
        // Given
        let validWorkout = Workout(date: Date(), name: "Valid", duration: 1800, isCompleted: true)
        let zeroDurationWorkout = Workout(date: Date(), name: "Zero", duration: 0, isCompleted: true)
        let corruptedWorkout = Workout(date: Date(), name: "Corrupted", duration: .infinity, isCompleted: true)

        // When
        let stats = manager.aggregateCompletedWorkoutStats(from: [validWorkout, zeroDurationWorkout, corruptedWorkout])

        // Then
        XCTAssertEqual(stats.count, 3)
        XCTAssertEqual(
            stats.averageDuration,
            1800,
            accuracy: 0.0001,
            "Missing/corrupted durations should not drag down average workout duration"
        )
    }

    func testSanitizedCompletedWorkoutDuration_requiresCompletedWorkoutAndPositiveFiniteDuration() {
        let completedWorkout = Workout(date: Date(), name: "Completed", duration: 125, isCompleted: true)
        let incompleteWorkout = Workout(date: Date(), name: "Incomplete", duration: 125, isCompleted: false)
        let zeroDurationWorkout = Workout(date: Date(), name: "Zero", duration: 0, isCompleted: true)
        let corruptedWorkout = Workout(date: Date(), name: "Corrupted", duration: -.infinity, isCompleted: true)

        XCTAssertEqual(manager.sanitizedCompletedWorkoutDuration(completedWorkout), 125, accuracy: 0.0001)
        XCTAssertNil(manager.sanitizedCompletedWorkoutDuration(incompleteWorkout))
        XCTAssertNil(manager.sanitizedCompletedWorkoutDuration(zeroDurationWorkout))
        XCTAssertNil(manager.sanitizedCompletedWorkoutDuration(corruptedWorkout))
    }

    func testFormatDuration_usesHumanReadableHourMinuteSecondOutput() {
        XCTAssertEqual(manager.formatDuration(3725), "1h 2m 5s")
        XCTAssertEqual(manager.formatDuration(3600), "1h 0m")
        XCTAssertEqual(manager.formatDuration(125), "2m 5s")
        XCTAssertEqual(manager.formatDuration(59.9), "59s")
        XCTAssertEqual(manager.formatDuration(.infinity), "0s")
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

    func testWorkoutFormattedTotalVolume_clampsNegativeSetData() {
        // Given
        let workout = Workout(name: "Corrupted Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        // When - corrupted persisted set data contains negative weight
        _ = workout.addSet(exercise: exercise, weight: -100, reps: 5)

        // Then - formatted volume should fail safe to zero
        XCTAssertEqual(workout.formattedTotalVolume(), "0 lb")
    }

    func testWorkoutComplete_clampsFutureStartDurationToZero() {
        // Given
        let futureDate = Date().addingTimeInterval(300)
        let workout = Workout(date: futureDate, name: "Future Workout", duration: 0, isCompleted: false)

        // When
        workout.complete()

        // Then
        XCTAssertTrue(workout.isCompleted)
        XCTAssertEqual(workout.duration, 0, accuracy: 0.0001)
    }

    func testWorkoutComplete_setsPositiveDurationForPastStart() {
        // Given
        let pastDate = Date().addingTimeInterval(-120)
        let workout = Workout(date: pastDate, name: "Past Workout", duration: 0, isCompleted: false)

        // When
        workout.complete()

        // Then
        XCTAssertTrue(workout.isCompleted)
        XCTAssertGreaterThan(workout.duration, 0)
    }

    func testWorkoutComplete_clampsCorruptedNegativePersistedDuration() {
        // Given
        let workout = Workout(name: "Corrupted Duration", duration: -45, isCompleted: false)

        // When
        workout.complete()

        // Then
        XCTAssertTrue(workout.isCompleted)
        XCTAssertEqual(workout.duration, 0, accuracy: 0.0001)
    }

    func testWorkoutComplete_clampsCorruptedNonFinitePersistedDuration() {
        // Given
        let workout = Workout(name: "Corrupted Duration", duration: .infinity, isCompleted: false)

        // When
        workout.complete()

        // Then
        XCTAssertTrue(workout.isCompleted)
        XCTAssertEqual(workout.duration, 0, accuracy: 0.0001)
    }

    func testGenerateFormattedSummary_preservesCompletedExerciseOrderAndFallsBackWhenEmpty() {
        // Given
        let workout = Workout(name: "Summary Workout")
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        // When empty
        let emptySummary = workout.generateFormattedSummary()

        // Then empty fallback
        XCTAssertTrue(emptySummary.contains("Exercises: None"))

        // When
        _ = workout.addSet(exercise: squat, weight: 225, reps: 5)
        _ = workout.addSet(exercise: bench, weight: 185, reps: 5)
        _ = workout.addSet(exercise: squat, weight: 205, reps: 3)
        let summary = workout.generateFormattedSummary()

        // Then preserves first-seen completed order while de-duplicating exercise names
        XCTAssertTrue(summary.contains("Exercises: Squat, Bench Press"))
    }

    func testGenerateFormattedSummary_includesHumanReadableDuration() {
        // Given
        let workout = Workout(name: "Duration Summary", duration: 125)

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        XCTAssertTrue(summary.contains("Duration: 2m 5s"))
    }

    func testGenerateFormattedSummary_durationDoesNotRoundUpNearMinuteBoundary() {
        // Given
        let workout = Workout(name: "Boundary Duration", duration: 59.9)

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        XCTAssertTrue(summary.contains("Duration: 59s"))
        XCTAssertFalse(summary.contains("Duration: 1m 0s"))
    }

    func testGenerateFormattedSummary_durationDoesNotRoundUpNearHourBoundary() {
        // Given
        let workout = Workout(name: "Hour Boundary Duration", duration: 3599.9)

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        XCTAssertTrue(summary.contains("Duration: 59m 59s"))
        XCTAssertFalse(summary.contains("Duration: 1h 0m"))
    }

    func testGenerateFormattedSummary_includesSecondsWhenDurationExceedsAnHour() {
        // Given
        let workout = Workout(name: "Long Duration", duration: 3661.9)

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        XCTAssertTrue(summary.contains("Duration: 1h 1m 1s"))
    }

    func testGenerateFormattedSummary_hidesZeroAndCorruptedDurations() {
        // Given
        let zeroDurationWorkout = Workout(name: "Zero Duration Summary", duration: 0)
        let corruptedDurationWorkout = Workout(name: "Corrupted Duration Summary", duration: -.infinity)

        // When
        let zeroSummary = zeroDurationWorkout.generateFormattedSummary()
        let corruptedSummary = corruptedDurationWorkout.generateFormattedSummary()

        // Then
        XCTAssertFalse(zeroSummary.contains("Duration:"))
        XCTAssertFalse(corruptedSummary.contains("Duration:"))
    }

    func testGenerateFormattedSummary_usesTotalRepsForBodyweightOnlyWorkout() {
        // Given
        let workout = Workout(name: "Bodyweight Summary")
        let pullUp = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])

        _ = workout.addSet(exercise: pullUp, weight: 0, reps: 10)
        _ = workout.addSet(exercise: pullUp, weight: 0, reps: 8)

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        XCTAssertTrue(summary.contains("Total Reps: 18 reps"))
        XCTAssertFalse(summary.contains("Total Volume: 0 lb"))
    }

    func testGenerateFormattedSummary_includesBodyweightRepsForMixedWorkout() {
        // Given
        let workout = Workout(name: "Mixed Summary")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let pullUp = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])

        _ = workout.addSet(exercise: bench, weight: 185, reps: 5)
        _ = workout.addSet(exercise: pullUp, weight: 0, reps: 10)

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        XCTAssertTrue(summary.contains("Total Volume: 925 lb"))
        XCTAssertTrue(summary.contains("Bodyweight Reps: 10 reps"))
    }

    func testGenerateFormattedSummary_exerciseListUsesCompletedWorkingSetsOnly() {
        // Given
        let workout = Workout(name: "Summary Completed Sets Only")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])
        let deadlift = Exercise(name: "Deadlift", category: .compound, primaryMuscleGroups: [.back])

        _ = workout.addSet(exercise: bench, weight: 185, reps: 5, isWarmup: false) // completed working set
        _ = workout.addSet(exercise: squat, weight: 225, reps: 0, isWarmup: false) // incomplete
        _ = workout.addSet(exercise: deadlift, weight: 135, reps: 5, isWarmup: true) // warmup

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        XCTAssertTrue(summary.contains("Exercises: Bench Press"))
        XCTAssertFalse(summary.contains("Squat"))
        XCTAssertFalse(summary.contains("Deadlift"))
    }

    func testGenerateFormattedSummary_normalizesExerciseNamesForDeduplication() {
        // Given
        let workout = Workout(name: "Summary Name Cleanup")
        let firstBench = Exercise(name: "  Bench   Press  ", category: .compound, primaryMuscleGroups: [.chest])
        let secondBench = Exercise(name: "bench press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: firstBench, weight: 185, reps: 5, isWarmup: false)
        _ = workout.addSet(exercise: secondBench, weight: 175, reps: 6, isWarmup: false)

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        XCTAssertTrue(summary.contains("Exercises: Bench Press"))
        XCTAssertFalse(summary.contains("Bench Press, bench press"))
    }

    func testGenerateFormattedSummary_ignoresBlankExerciseNames() {
        // Given
        let workout = Workout(name: "Summary Blank Name")
        let blankNameExercise = Exercise(name: "   \n\t  ", category: .compound, primaryMuscleGroups: [.back])

        _ = workout.addSet(exercise: blankNameExercise, weight: 225, reps: 5, isWarmup: false)

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        XCTAssertTrue(summary.contains("Exercises: None"))
    }

    func testGenerateFormattedSummary_completedWorkoutFallsBackToLoggedExerciseNamesWhenTimestampsAreMissing() {
        // Given
        let workout = Workout(name: "Legacy Completed", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])

        _ = workout.addSet(exercise: bench, weight: 185, reps: 0, isWarmup: false)
        _ = workout.addSet(exercise: squat, weight: 225, reps: 0, isWarmup: false)

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        XCTAssertTrue(summary.contains("Exercises: Bench Press, Squat"))
        XCTAssertTrue(summary.contains("Sets: 2"))
    }

    func testGenerateFormattedSummary_completedWarmupOnlyWorkoutKeepsWarmupContext() {
        // Given
        let workout = Workout(name: "Warm-up Only", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: bench, weight: 45, reps: 12, isWarmup: true)

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        XCTAssertTrue(summary.contains("Exercises: Bench Press"))
        XCTAssertTrue(summary.contains("Sets: 1"))
        XCTAssertTrue(summary.contains("Work: Warm-up sets only"))
        XCTAssertFalse(summary.contains("Total Volume: 0 lb"))
    }

    func testGenerateFormattedSummary_incompleteWorkoutDoesNotFallBackToPlannedExerciseNames() {
        // Given
        let workout = Workout(name: "Planned Workout", isCompleted: false)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: bench, weight: 185, reps: 0, isWarmup: false)

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        XCTAssertTrue(summary.contains("Exercises: None"))
        XCTAssertTrue(summary.contains("Sets: 0"))
        XCTAssertTrue(summary.contains("Work: Not logged yet"))
        XCTAssertFalse(summary.contains("Total Volume: 0 lb"))
    }

    func testGenerateFormattedSummary_emptyIncompleteWorkoutUsesNotStartedCopy() {
        // Given
        let workout = Workout(name: "Fresh Workout", isCompleted: false)

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        XCTAssertTrue(summary.contains("Exercises: None"))
        XCTAssertTrue(summary.contains("Sets: 0"))
        XCTAssertTrue(summary.contains("Work: Not started"))
        XCTAssertFalse(summary.contains("Total Volume: 0 lb"))
    }

    func testGenerateFormattedSummary_completedWorkoutWithoutLoggedSetsUsesNeutralWorkCopy() {
        // Given
        let workout = Workout(name: "Legacy Empty", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: bench, weight: 185, reps: 0, isWarmup: false)

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        XCTAssertTrue(summary.contains("Exercises: Bench Press"))
        XCTAssertTrue(summary.contains("Sets: 0"))
        XCTAssertTrue(summary.contains("Work: No sets logged"))
        XCTAssertFalse(summary.contains("Total Volume: 0 lb"))
    }

    func testGenerateFormattedSummary_completedPlaceholderSetsFallBackToLoggedWarmupsOnly() {
        // Given
        let workout = Workout(name: "Legacy Warmup", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: bench, weight: 45, reps: 12, isWarmup: true)
        _ = workout.addSet(exercise: bench, weight: 185, reps: 0, isWarmup: false)
        _ = workout.addSet(exercise: bench, weight: 165, reps: 0, isWarmup: false)

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        XCTAssertTrue(summary.contains("Exercises: Bench Press"))
        XCTAssertTrue(summary.contains("Sets: 1"))
        XCTAssertTrue(summary.contains("Work: Warm-up sets only"))
        XCTAssertFalse(summary.contains("Sets: 3"))
    }

    func testGenerateFormattedSummary_fallsBackToDefaultNameWhenNameIsWhitespaceOnly() {
        // Given
        let workout = Workout(name: "   \n\t  ")

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        XCTAssertTrue(summary.hasPrefix("Workout - "))
    }

    func testGenerateFormattedSummary_normalizesAndClampsWorkoutName() {
        // Given
        let longName = "  Upper   Body\nSession\t" + String(repeating: "A", count: 120)
        let workout = Workout(name: longName)

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        let firstLine = summary.components(separatedBy: "\n").first ?? ""
        let renderedName = String(firstLine.split(separator: "-").first?.trimmingCharacters(in: .whitespaces) ?? "")
        XCTAssertTrue(renderedName.hasPrefix("Upper Body Session"))
        XCTAssertLessThanOrEqual(renderedName.count, 80)
    }

    func testGenerateFormattedSummary_omitsNotesWhenTheyAreWhitespaceOnly() {
        // Given
        let workout = Workout(name: "Summary Notes", notes: "  \n\t   ")

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        XCTAssertFalse(summary.contains("Notes:"))
    }

    func testGenerateFormattedSummary_collapsesMultilineNotesToSingleLine() {
        // Given
        let workout = Workout(name: "Summary Notes", notes: "  Felt strong\n\nAdded back-off set\t ")

        // When
        let summary = workout.generateFormattedSummary()

        // Then
        XCTAssertTrue(summary.contains("Notes: Felt strong Added back-off set"))
    }

    func testWorkingSetsCount_excludesWarmupAndIncompleteSets() {
        // Given
        let workout = Workout(name: "Set Count Integrity")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: exercise, weight: 45, reps: 10, isWarmup: true)
        _ = workout.addSet(exercise: exercise, weight: 225, reps: 5, isWarmup: false)
        _ = workout.addSet(exercise: exercise, weight: 185, reps: 0, isWarmup: false)
        _ = workout.addSet(exercise: exercise, weight: 0, reps: 8, isWarmup: false)

        // Then
        XCTAssertEqual(workout.workingSetsCount, 1, "Only completed non-warmup sets should count as working sets")
    }

    func testWorkoutTotalVolume_usesOnlyCompletedWorkingSets() {
        // Given
        let workout = Workout(name: "Volume Integrity")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: exercise, weight: 45, reps: 10, isWarmup: true)   // warmup: excluded
        _ = workout.addSet(exercise: exercise, weight: 225, reps: 5, isWarmup: false)   // completed: included (1125)
        _ = workout.addSet(exercise: exercise, weight: 185, reps: 0, isWarmup: false)   // incomplete: excluded
        _ = workout.addSet(exercise: exercise, weight: 135, reps: 8, isWarmup: false)   // completed: included (1080)

        // Then
        XCTAssertEqual(workout.totalVolume, 2205, "Workout total volume should exclude warmups and incomplete sets")
    }

    func testExerciseSetIsCompletedWorkingSet_handlesBodyweightCompletionRules() {
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let bodyweightExercise = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])
        let workout = Workout(name: "Set Predicate")

        let completedWorkingSet = ExerciseSet(weight: 225, reps: 5, exercise: exercise, workout: workout, completedAt: Date(), isWarmup: false)
        XCTAssertTrue(completedWorkingSet.isCompletedWorkingSet)

        let warmupSet = ExerciseSet(weight: 135, reps: 8, exercise: exercise, workout: workout, completedAt: Date(), isWarmup: true)
        XCTAssertFalse(warmupSet.isCompletedWorkingSet)

        let zeroWeightSet = ExerciseSet(weight: 0, reps: 8, exercise: exercise, workout: workout, completedAt: Date(), isWarmup: false)
        XCTAssertFalse(zeroWeightSet.isCompletedWorkingSet)

        let bodyweightSet = ExerciseSet(weight: 0, reps: 8, exercise: bodyweightExercise, workout: workout, completedAt: Date(), isWarmup: false)
        XCTAssertTrue(bodyweightSet.isCompletedWorkingSet)

        let corruptedNegativeBodyweightSet = ExerciseSet(weight: -10, reps: 8, exercise: bodyweightExercise, workout: workout, completedAt: Date(), isWarmup: false)
        XCTAssertFalse(corruptedNegativeBodyweightSet.isCompletedWorkingSet)

        let zeroRepsSet = ExerciseSet(weight: 185, reps: 0, exercise: exercise, workout: workout, completedAt: Date(), isWarmup: false)
        XCTAssertFalse(zeroRepsSet.isCompletedWorkingSet)

        let incompleteTimestampSet = ExerciseSet(weight: 185, reps: 5, exercise: exercise, workout: workout, completedAt: .distantPast, isWarmup: false)
        XCTAssertFalse(incompleteTimestampSet.isCompletedWorkingSet)
    }

    func testWorkoutBestSets_usesOnlyCompletedWorkingSets() {
        // Given
        let workout = Workout(name: "Best Sets Integrity")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: bench, weight: 135, reps: 8, isWarmup: true)   // warmup: excluded
        _ = workout.addSet(exercise: bench, weight: 205, reps: 5, isWarmup: false)  // completed: included
        _ = workout.addSet(exercise: bench, weight: 225, reps: 0, isWarmup: false)  // incomplete: excluded

        // When
        let bestSetWeight = workout.bestSets[bench]?.weight

        // Then
        XCTAssertEqual(bestSetWeight, 205, "Best set should ignore warmup and incomplete sets")
    }

    func testWorkoutBestSets_prefersHigherRepsWhenWeightTies() {
        // Given
        let workout = Workout(name: "Best Sets Tie Break")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        let lowerRepSet = workout.addSet(exercise: bench, weight: 225, reps: 5, isWarmup: false)
        let higherRepSet = workout.addSet(exercise: bench, weight: 225, reps: 7, isWarmup: false)
        lowerRepSet.completedAt = Date(timeIntervalSinceReferenceDate: 200)
        higherRepSet.completedAt = Date(timeIntervalSinceReferenceDate: 100)

        // When
        let bestSet = workout.bestSets[bench]

        // Then
        XCTAssertEqual(bestSet?.weight, 225)
        XCTAssertEqual(bestSet?.reps, 7, "When top weight ties, best set should prefer the higher rep performance")
    }

    func testOrderedExerciseGroups_preservesLoggedExerciseAndSetOrderWhenTimestampsDrift() {
        // Given
        let workout = Workout(name: "Detail Ordering")
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        // Log squat first, then bench, then squat again to verify grouped ordering by first appearance.
        let squatSet1 = workout.addSet(exercise: squat, weight: 225, reps: 5)
        let benchSet1 = workout.addSet(exercise: bench, weight: 185, reps: 6)
        let squatSet2 = workout.addSet(exercise: squat, weight: 205, reps: 7)

        // Simulate edited timestamps that would incorrectly reorder if the UI sorted by completedAt.
        squatSet1.completedAt = Date(timeIntervalSinceReferenceDate: 300)
        benchSet1.completedAt = Date(timeIntervalSinceReferenceDate: 100)
        squatSet2.completedAt = Date(timeIntervalSinceReferenceDate: 200)

        // When
        let orderedGroups = workout.orderedExerciseGroups

        // Then
        XCTAssertEqual(
            orderedGroups.map(\.exercise.name),
            ["Squat", "Bench Press"],
            "Exercise sections should follow logged workout order, not alphabetical/completion-time ordering"
        )
        XCTAssertEqual(
            orderedGroups.first?.sets.map(\.weight),
            [225, 205],
            "Sets inside each section should stay in canonical logged order"
        )
    }

    func testOrderedSetsForExercise_preservesLoggedOrderWhenInterleavedTimestampsDrift() {
        // Given
        let workout = Workout(name: "Exercise History Ordering")
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        let squatSet1 = workout.addSet(exercise: squat, weight: 225, reps: 5)
        let benchSet = workout.addSet(exercise: bench, weight: 185, reps: 6)
        let squatSet2 = workout.addSet(exercise: squat, weight: 205, reps: 7)

        // Simulate timestamp edits/corruption that would misorder exercise history if sorted by completion date.
        squatSet1.completedAt = Date(timeIntervalSinceReferenceDate: 300)
        benchSet.completedAt = Date(timeIntervalSinceReferenceDate: 100)
        squatSet2.completedAt = Date(timeIntervalSinceReferenceDate: 200)

        // When
        let orderedSets = workout.orderedSets(for: squat)

        // Then
        XCTAssertEqual(
            orderedSets.map(\.weight),
            [225, 205],
            "Exercise-specific history should preserve canonical logged order even when completion timestamps drift"
        )
    }

    func testCreateFollowUpWorkout_preservesLoggedSetOrderWhenCompletionTimestampsDrift() {
        // Given
        let workout = Workout(name: "Order Integrity")
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])

        let first = workout.addSet(exercise: squat, weight: 200, reps: 5)
        let second = workout.addSet(exercise: squat, weight: 180, reps: 6)
        let third = workout.addSet(exercise: squat, weight: 160, reps: 8)

        // Simulate edited/corrupted completion timestamps that no longer reflect true set sequence.
        first.completedAt = Date(timeIntervalSinceReferenceDate: 300)
        second.completedAt = Date(timeIntervalSinceReferenceDate: 100)
        third.completedAt = Date(timeIntervalSinceReferenceDate: 200)

        // When
        let followUp = workout.createFollowUpWorkout(percentageIncrease: 0.10)
        let followUpWeights = followUp
            .exerciseGroups[squat]?
            .map(\.weight)

        // Then
        XCTAssertEqual(
            followUpWeights,
            [220, 198, 176],
            "Follow-up progression should use canonical logged set order, not completion timestamp sorting"
        )
    }

    func testCreateFollowUpWorkout_preservesExerciseInsertionOrderAcrossMultipleExercises() {
        // Given
        let workout = Workout(name: "Exercise Order Integrity")
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        // Logged order: squat first, then bench.
        _ = workout.addSet(exercise: squat, weight: 200, reps: 5)
        _ = workout.addSet(exercise: bench, weight: 150, reps: 8)

        // When
        let followUp = workout.createFollowUpWorkout(percentageIncrease: 0.10)

        // Then
        XCTAssertEqual(
            followUp.orderedExerciseGroups.map(\.exercise.name),
            ["Squat", "Bench Press"],
            "Follow-up workout should preserve original exercise sequence for stable UI/logging order"
        )
    }

    func testExerciseSetHasCompletedValues_allowsZeroWeightForBodyweightExercises() {
        XCTAssertTrue(ExerciseSet.hasCompletedValues(weight: 185, reps: 5))
        XCTAssertFalse(ExerciseSet.hasCompletedValues(weight: 185, reps: 0))
        XCTAssertFalse(ExerciseSet.hasCompletedValues(weight: 0, reps: 5))
        XCTAssertTrue(ExerciseSet.hasCompletedValues(weight: 0, reps: 5, exerciseCategory: .bodyweight))
    }

    func testExerciseSetFormattedWeightReps_usesIntegerWeightAndRepCount() {
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let workout = Workout(name: "Formatting")
        let set = ExerciseSet(weight: 185, reps: 8, exercise: exercise, workout: workout)

        XCTAssertEqual(set.formattedWeightReps, "185 lb × 8 reps")
    }

    func testExerciseSetFormattedWeightReps_usesBodyweightLabelForZeroWeightBodyweightSets() {
        let bodyweightExercise = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])
        let weightedExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let workout = Workout(name: "Formatting")

        let bodyweightSet = ExerciseSet(weight: 0, reps: 10, exercise: bodyweightExercise, workout: workout)
        let weightedSet = ExerciseSet(weight: 0, reps: 10, exercise: weightedExercise, workout: workout)

        XCTAssertEqual(bodyweightSet.formattedWeightReps, "BW × 10 reps")
        XCTAssertEqual(weightedSet.formattedWeightReps, "0 lb × 10 reps")
    }

    func testExerciseSetFormattedWeightReps_usesSingularRepGrammar() {
        let bodyweightExercise = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])
        let weightedExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        XCTAssertEqual(
            ExerciseSet.formattedWeightReps(weight: 0, reps: 1, exerciseCategory: bodyweightExercise.category),
            "BW × 1 rep"
        )
        XCTAssertEqual(
            ExerciseSet.formattedWeightReps(weight: 185, reps: 1, exerciseCategory: weightedExercise.category),
            "185 lb × 1 rep"
        )
    }

    func testExerciseSetFormattedWeightReps_clampsNegativeValuesToSafeDisplay() {
        XCTAssertEqual(
            ExerciseSet.formattedWeightReps(weight: -45, reps: -3, exerciseCategory: .compound),
            "0 lb × 0 reps"
        )
        XCTAssertEqual(
            ExerciseSet.formattedWeightReps(weight: -10, reps: -1, exerciseCategory: .bodyweight),
            "BW × 0 reps"
        )
    }
}
