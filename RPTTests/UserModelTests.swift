//
//  UserModelTests.swift
//  RPTTests
//
//  Created by Michael Moore on 5/2/25.
//

import XCTest
@testable import RPT

@MainActor
final class UserModelTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - User Height and Weight
    
    func testUserHeightAndWeightUnits() {
        // Given - create a user with height in inches and weight in pounds
        let user = User(
            username: "TestUser",
            email: "test@example.com",
            height: 72.0, // 6 feet in inches
            weight: 180.0 // 180 pounds
        )
        
        // Then - verify height and weight
        XCTAssertEqual(user.height, 72.0, "Height should be stored in inches")
        XCTAssertEqual(user.weight, 180.0, "Weight should be stored in pounds")
    }
    
    func testBMICalculation() {
        // Given - create users with different heights and weights
        let user1 = User(
            username: "User1",
            email: "user1@example.com",
            height: 70.0, // 5'10" in inches
            weight: 154.0 // 154 pounds
        )
        
        let user2 = User(
            username: "User2",
            email: "user2@example.com",
            height: 65.0, // 5'5" in inches
            weight: 150.0 // 150 pounds
        )
        
        let userWithoutHeight = User(
            username: "UserWithoutHeight",
            email: "noheight@example.com",
            weight: 180.0
        )
        
        let userWithoutWeight = User(
            username: "UserWithoutWeight",
            email: "noweight@example.com",
            height: 72.0
        )
        
        // Then - verify BMI calculations using the imperial formula: 703 * weight(lb) / height(in)²
        // BMI for user1 = 703 * 154 / (70*70) = 703 * 154 / 4900 = 22.1
        let expectedBMI1 = 703 * 154.0 / (70.0 * 70.0)
        XCTAssertEqual(user1.bmi!, expectedBMI1, accuracy: 0.1, "BMI should be calculated correctly with imperial formula")
        
        // BMI for user2 = 703 * 150 / (65*65) = 703 * 150 / 4225 = 25.0
        let expectedBMI2 = 703 * 150.0 / (65.0 * 65.0)
        XCTAssertEqual(user2.bmi!, expectedBMI2, accuracy: 0.1, "BMI should be calculated correctly with imperial formula")
        
        // Users with missing data should return nil for BMI
        XCTAssertNil(userWithoutHeight.bmi, "BMI should be nil when height is missing")
        XCTAssertNil(userWithoutWeight.bmi, "BMI should be nil when weight is missing")
    }
    
    // MARK: - User Statistics
    
    func testUserStatsTotalVolume() {
        // Given - create a user and a workout
        let user = User(
            username: "TestUser",
            email: "test@example.com"
        )
        let workout = Workout(name: "Test Workout")
        let exercise = Exercise(name: "Test Exercise", category: .compound, primaryMuscleGroups: [.abs])
        
        // Add some sets to the workout
        _ = workout.addSet(exercise: exercise, weight: 225, reps: 5) // 1125 volume
        _ = workout.addSet(exercise: exercise, weight: 205, reps: 6) // 1230 volume
        _ = workout.addSet(exercise: exercise, weight: 185, reps: 8) // 1480 volume
        // Total volume: 3835
        
        // Initial total volume should be 0
        XCTAssertEqual(user.totalVolume, 0.0, "Initial total volume should be 0")
        
        // When - update stats with the workout
        user.updateStats(with: workout)
        
        // Then - verify total volume is updated correctly
        XCTAssertEqual(user.totalVolume, 3835.0, "Total volume should be updated with workout volume")
        
        // When - add another workout
        let workout2 = Workout(name: "Test Workout 2")
        _ = workout2.addSet(exercise: exercise, weight: 135, reps: 10) // 1350 volume
        
        user.updateStats(with: workout2)
        
        // Then - verify total volume is cumulative
        XCTAssertEqual(user.totalVolume, 3835.0 + 1350.0, "Total volume should be cumulative")
    }

    func testUpdateStats_clampsCorruptedNegativeWorkoutVolume() {
        // Given
        let user = User(username: "TestUser", email: "test@example.com")
        let workout = Workout(name: "Corrupted Workout")
        let exercise = Exercise(name: "Deadlift", category: .compound, primaryMuscleGroups: [.lowerBack])

        _ = workout.addSet(exercise: exercise, weight: -200, reps: 5) // -1000 corrupted volume

        // When
        user.updateStats(with: workout)

        // Then
        XCTAssertEqual(user.totalVolume, 0, "Corrupted negative workout volume should not reduce lifetime total volume")
        XCTAssertEqual(user.totalWorkouts, 1, "Workout count should still increment")
    }

    func testUpdateStats_usesOnlyCompletedWorkingSetsForVolumeAndPersonalBests() {
        // Given
        let user = User(username: "TestUser", email: "test@example.com")
        let workout = Workout(name: "Mixed Workout")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: bench, weight: 135, reps: 8, isWarmup: true)  // warmup: excluded
        _ = workout.addSet(exercise: bench, weight: 225, reps: 0, isWarmup: false) // incomplete: excluded
        _ = workout.addSet(exercise: bench, weight: 205, reps: 5, isWarmup: false) // completed: included

        // When
        user.updateStats(with: workout)

        // Then
        XCTAssertEqual(user.totalVolume, 1025, "Only completed working sets should contribute to lifetime volume")
        XCTAssertEqual(user.personalBests["Bench Press"], 205, "Personal best should ignore warmup and incomplete sets")
    }

    func testRegisterCompletedWorkoutIfNeeded_requiresCompletedWorkout() {
        // Given
        let user = User(username: "TestUser", email: "test@example.com")
        let workout = Workout(name: "Incomplete Workout")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: bench, weight: 205, reps: 5)
        XCTAssertFalse(workout.isCompleted, "Sanity check: fresh workout should start incomplete")

        // When
        let registrationAttempt = user.registerCompletedWorkoutIfNeeded(workout)

        // Then
        XCTAssertFalse(registrationAttempt, "Incomplete workouts should not be counted in lifetime stats")
        XCTAssertEqual(user.workouts.count, 0, "Incomplete workouts should not be linked as completed history")
        XCTAssertEqual(user.totalWorkouts, 0, "Incomplete workouts should not increment total workouts")
        XCTAssertEqual(user.totalVolume, 0, "Incomplete workouts should not change total volume")
    }

    func testRegisterCompletedWorkoutIfNeeded_isIdempotentForSameWorkout() {
        // Given
        let user = User(username: "TestUser", email: "test@example.com")
        let workout = Workout(name: "Idempotent Completion")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: bench, weight: 205, reps: 5)
        workout.complete()

        // When
        let firstRegistration = user.registerCompletedWorkoutIfNeeded(workout)
        let secondRegistration = user.registerCompletedWorkoutIfNeeded(workout)

        // Then
        XCTAssertTrue(firstRegistration, "First registration should be counted")
        XCTAssertFalse(secondRegistration, "Second registration of the same workout should be ignored")
        XCTAssertEqual(user.workouts.count, 1, "Workout should only be linked once")
        XCTAssertEqual(user.totalWorkouts, 1, "Total workouts should not double-count retriggered completion")
        XCTAssertEqual(user.totalVolume, 1025, "Total volume should not double-count retriggered completion")
    }

    func testRegisterCompletedWorkoutIfNeeded_usesWorkoutDateForBackfilledStreaks() {
        // Given
        let user = User(username: "TestUser", email: "test@example.com")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let calendar = Calendar.current
        let now = Date()
        let priorWorkoutDate = calendar.date(byAdding: .day, value: -2, to: now)!
        let backfilledWorkoutDate = calendar.date(byAdding: .day, value: -1, to: now)!

        let priorWorkout = Workout(date: priorWorkoutDate, name: "Prior Workout")
        _ = priorWorkout.addSet(exercise: bench, weight: 185, reps: 5)
        priorWorkout.complete()

        let backfilledWorkout = Workout(date: backfilledWorkoutDate, name: "Backfilled Workout")
        _ = backfilledWorkout.addSet(exercise: bench, weight: 190, reps: 5)
        backfilledWorkout.complete()

        XCTAssertTrue(user.registerCompletedWorkoutIfNeeded(priorWorkout), "Sanity check: first completed workout should register")
        XCTAssertEqual(user.workoutStreak, 1, "First completed workout should start the streak")

        // When
        let secondRegistration = user.registerCompletedWorkoutIfNeeded(backfilledWorkout)

        // Then
        XCTAssertTrue(secondRegistration, "Second completed workout should register")
        XCTAssertEqual(user.workoutStreak, 2, "A workout logged for the next calendar day should extend the streak even when completed later")
    }

    func testCreateFollowUpWorkout_usesOnlyCompletedWorkingSets() {
        let workout = Workout(name: "Corrupted Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: exercise, weight: 45, reps: 10, isWarmup: true, rpe: 6)   // warmup: excluded
        _ = workout.addSet(exercise: exercise, weight: -50, reps: -3, isWarmup: false, rpe: 11) // incomplete: excluded
        _ = workout.addSet(exercise: exercise, weight: 200, reps: 6, isWarmup: false, rpe: 8)   // completed: included

        let followUp = workout.createFollowUpWorkout(percentageIncrease: 0.025)
        let followUpSets = followUp.sets.filter { $0.exercise?.id == exercise.id }

        XCTAssertEqual(followUpSets.count, 1, "Follow-up should only include completed working sets")
        XCTAssertEqual(followUpSets.first?.weight, 205, "Top set should progress from the latest completed working set")
        XCTAssertEqual(followUpSets.first?.reps, 6, "Reps should be copied from completed working sets")
        XCTAssertEqual(followUpSets.first?.rpe, 8, "Valid RPE should be preserved")
    }

    func testCreateFollowUpWorkout_nonFinitePercentageIncreaseDefaultsSafely() {
        let workout = Workout(name: "Base Workout")
        let exercise = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quads])

        _ = workout.addSet(exercise: exercise, weight: 200, reps: 5)

        let followUp = workout.createFollowUpWorkout(percentageIncrease: .infinity)
        let followUpSet = followUp.sets.first

        XCTAssertEqual(followUpSet?.weight, 200, "Non-finite percentage increase should fall back safely")
    }

    func testCreateFollowUpWorkout_includesBodyweightWorkingSets() {
        let workout = Workout(name: "Bodyweight Workout")
        let pullUps = Exercise(name: "Pull-Ups", category: .bodyweight, primaryMuscleGroups: [.back])

        _ = workout.addSet(exercise: pullUps, weight: 0, reps: 8)
        _ = workout.addSet(exercise: pullUps, weight: 0, reps: 6)

        let followUp = workout.createFollowUpWorkout(percentageIncrease: 0.025)
        let followUpSets = followUp.sets.filter { $0.exercise?.id == pullUps.id }

        XCTAssertEqual(followUpSets.count, 2, "Bodyweight completed working sets should carry into follow-up workouts")
        XCTAssertEqual(followUpSets.map(\.weight), [0, 0], "Bodyweight follow-up sets should preserve zero external load")
        XCTAssertEqual(followUpSets.map(\.reps), [8, 6], "Bodyweight follow-up reps should be preserved")
    }

    func testCreateFollowUpWorkout_setsStartIncompleteForLogging() {
        let workout = Workout(name: "Base Workout")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: bench, weight: 200, reps: 5)
        _ = workout.addSet(exercise: bench, weight: 180, reps: 8)

        let followUp = workout.createFollowUpWorkout(percentageIncrease: 0.025)

        XCTAssertFalse(followUp.isCompleted, "Follow-up workout should start incomplete")
        XCTAssertTrue(followUp.sets.allSatisfy { $0.completedAt == .distantPast }, "Follow-up sets should remain planned until the user logs completion")
        XCTAssertEqual(followUp.workingSetsCount, 0, "Planned follow-up sets should not be counted as completed working sets")
    }
}
