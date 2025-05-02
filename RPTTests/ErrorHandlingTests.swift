//
//  ErrorHandlingTests.swift
//  RPTTests
//
//  Created by Michael Moore on 5/2/25.
//

import XCTest
@testable import RPT

@MainActor
final class ErrorHandlingTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - DataManager Tests
    
    func testDataManagerErrorHandling() throws {
        // Test that the error handling in DataManager works correctly
        
        // Test the saveChangesSafely method
        let dataManager = DataManager.shared
        
        // This should return true (successful operation)
        let saveResult = dataManager.saveChangesSafely()
        XCTAssertTrue(saveResult, "saveChangesSafely should return true on successful save")
        
        // Test fetching with safe method
        let workouts = dataManager.fetchRecentWorkoutsSafely(limit: 5)
        // We're just testing that it doesn't throw, not the actual results
        XCTAssertNotNil(workouts, "fetchRecentWorkoutsSafely should not return nil")
        
        // Test throwing methods with try/catch
        do {
            let _ = try dataManager.fetchRecentWorkouts(limit: 5)
            // If we got here, no error was thrown
            XCTAssertTrue(true, "fetchRecentWorkouts didn't throw an error")
        } catch {
            XCTFail("fetchRecentWorkouts threw an unexpected error: \(error)")
        }
    }
    
    // MARK: - SettingsManager Tests
    
    func testSettingsManagerErrorHandling() throws {
        // Test that the error handling in SettingsManager works correctly
        let settingsManager = SettingsManager.shared
        
        // Test successful operations
        let updateResult = settingsManager.updateSettingsSafely()
        XCTAssertTrue(updateResult, "updateSettingsSafely should return true on successful update")
        
        // Test validation
        let validDrops = settingsManager.updateRPTPercentageDropsSafely(drops: [0.0, 0.1, 0.2])
        XCTAssertTrue(validDrops, "Valid percentage drops should be accepted")
        
        let invalidDrops = settingsManager.updateRPTPercentageDropsSafely(drops: [0.1, 0.2]) // First element not 0.0
        XCTAssertFalse(invalidDrops, "Invalid percentage drops should be rejected")
        
        // Test reset to defaults
        let resetResult = settingsManager.resetToDefaultsSafely()
        XCTAssertTrue(resetResult, "resetToDefaultsSafely should return true on successful reset")
    }
    
    // MARK: - ActiveWorkoutViewModel Tests
    
    func testActiveWorkoutViewModelErrorHandling() throws {
        // Create a workout for testing
        let workout = Workout(name: "Test Workout")
        let viewModel = ActiveWorkoutViewModel(workout: workout)
        
        // Test validation
        let exercise = Exercise(name: "Test Exercise", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [], instructions: "Test", isCustom: true)
        
        let addResult = viewModel.addExerciseToWorkoutSafely(exercise)
        XCTAssertTrue(addResult, "Adding a valid exercise should succeed")
        
        // Test saving
        let saveResult = viewModel.saveWorkoutSafely()
        XCTAssertTrue(saveResult, "Saving a valid workout should succeed")
        
        // Test error message
        XCTAssertNil(viewModel.errorMessage, "There should be no error message after successful operations")
        
        // Test error message setting
        viewModel.errorMessage = "Test error"
        XCTAssertEqual(viewModel.errorMessage, "Test error", "Error message should be set correctly")
        
        viewModel.clearError()
        XCTAssertNil(viewModel.errorMessage, "Error message should be cleared")
    }
    
    // MARK: - Error Types Tests
    
    func testErrorDescriptions() {
        // Test DataManager error descriptions
        let dataError1 = DataManager.DataError.saveFailed
        XCTAssertEqual(dataError1.description, "Failed to save changes to database")
        
        let dataError2 = DataManager.DataError.fetchFailed
        XCTAssertEqual(dataError2.description, "Failed to fetch data")
        
        // Test SettingsManager error descriptions
        let settingsError1 = SettingsManager.SettingsError.saveFailed
        XCTAssertEqual(settingsError1.description, "Failed to save settings")
        
        let settingsError2 = SettingsManager.SettingsError.invalidValue
        XCTAssertEqual(settingsError2.description, "Invalid setting value")
        
        // Test ActiveWorkoutViewModel error descriptions
        let workoutError1 = ActiveWorkoutViewModel.WorkoutError.saveFailure
        XCTAssertEqual(workoutError1.description, "Failed to save workout")
        
        let workoutError2 = ActiveWorkoutViewModel.WorkoutError.invalidSetData
        XCTAssertEqual(workoutError2.description, "Invalid set data")
    }
}
