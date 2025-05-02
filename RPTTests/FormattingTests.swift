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
        XCTAssertEqual(settingsManager.formatWeight(225, useUnit: false), "225", "Integer weight without unit should format correctly")
        
        // Test double weight formatting
        XCTAssertEqual(settingsManager.formatWeight(135.0), "135.0 lb", "Double weight should format correctly")
        XCTAssertEqual(settingsManager.formatWeight(135.5), "135.5 lb", "Double weight with decimal should format correctly")
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
