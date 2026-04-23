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

    func testUserSettingsDefaultRPTDrops_fallsBackWhenPersistedStringIsInvalid() {
        let settings = UserSettings()
        settings.defaultRPTPercentageDropsString = "not-a-number, , ,"

        XCTAssertEqual(
            settings.defaultRPTPercentageDrops,
            [0.0, 0.10, 0.15],
            "Invalid persisted RPT drops should fail safe to app defaults"
        )
    }

    func testUserSettingsDefaultRPTDrops_prependsTopSetWhenMissing() {
        let settings = UserSettings()
        settings.defaultRPTPercentageDropsString = "0.10,0.15"

        XCTAssertEqual(
            settings.defaultRPTPercentageDrops,
            [0.0, 0.10, 0.15],
            "Persisted RPT drops missing top set should be normalized to include 0.0 first"
        )
    }

    func testUserSettingsDefaultRPTDrops_normalizesOutOfOrderAndDuplicateDrops() {
        let settings = UserSettings()
        settings.defaultRPTPercentageDropsString = "0.20,0.10,0.10,0.00,0.30"

        XCTAssertEqual(
            settings.defaultRPTPercentageDrops,
            [0.0, 0.10, 0.20, 0.30],
            "Persisted RPT drops should be normalized to deterministic ascending unique values"
        )
    }

    func testSettingsManagerUpdateRPTPercentageDrops_rejectsNonMonotonicDrops() {
        let settingsManager = SettingsManager.shared

        let didAcceptInvalid = settingsManager.updateRPTPercentageDropsSafely(drops: [0.0, 0.20, 0.10])

        XCTAssertFalse(
            didAcceptInvalid,
            "RPT percentage drops should reject non-monotonic backoff values that would increase later set weights"
        )
    }

    func testUserSettingsRestTimerDuration_normalizesInvalidValues() {
        let belowRange = UserSettings(restTimerDuration: -45)
        XCTAssertEqual(
            belowRange.restTimerDuration,
            1,
            "Rest timer duration should clamp invalid low values to the minimum safe bound"
        )

        let aboveRange = UserSettings(restTimerDuration: 5000)
        XCTAssertEqual(
            aboveRange.restTimerDuration,
            3600,
            "Rest timer duration should clamp invalid high values to the maximum supported bound"
        )
    }

    func testExerciseManagerSanitizeExerciseName_normalizesWhitespaceAndLength() {
        let raw = "   Bulgarian   Split   Squat\n\n"

        XCTAssertEqual(
            ExerciseManager.sanitizeExerciseName(raw),
            "Bulgarian Split Squat",
            "Exercise names should trim and normalize repeated whitespace"
        )

        let longName = String(repeating: "A", count: 200)
        XCTAssertEqual(
            ExerciseManager.sanitizeExerciseName(longName).count,
            80,
            "Exercise names should cap length to the app-safe limit"
        )

        XCTAssertEqual(
            ExerciseManager.sanitizeExerciseName(" \n\t "),
            "Exercise",
            "Blank exercise names should fail safe to a sensible default"
        )
    }

    func testExerciseManagerNormalizedNameLookupKey_isCaseAndDiacriticInsensitive() {
        let a = ExerciseManager.normalizedNameLookupKey("  Café Row ")
        let b = ExerciseManager.normalizedNameLookupKey("cafe row")

        XCTAssertEqual(
            a,
            b,
            "Exercise lookup keys should ignore case and diacritics"
        )
    }

    func testExerciseManagerNamesCollide_detectsWhitespaceCaseAndDiacriticVariants() {
        XCTAssertTrue(
            ExerciseManager.namesCollide("  Café   Row  ", "cafe row"),
            "Exercise duplicate checks should treat whitespace/case/diacritic variants as the same name"
        )

        XCTAssertFalse(
            ExerciseManager.namesCollide("Barbell Row", "Dumbbell Row"),
            "Exercise duplicate checks should still allow distinct exercise names"
        )
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
