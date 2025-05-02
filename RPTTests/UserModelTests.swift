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
}
