//
//  HomeViewModelTests.swift
//  RPTTests
//
//  Created by Michael Moore on 5/2/25.
//

import XCTest
@testable import RPT

@MainActor
final class HomeViewModelTests: XCTestCase {
    var viewModel: HomeViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = HomeViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Format Total Volume Tests
    
    func testFormatTotalVolume_nil() {
        // Given - no user stats
        viewModel.userStats = nil
        
        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()
        
        // Then - should return "0"
        XCTAssertEqual(formattedVolume, "0", "Format should return '0' when userStats is nil")
    }
    
    func testFormatTotalVolume_zero() {
        // Given - user stats with zero volume
        viewModel.userStats = (totalWorkouts: 0, totalVolume: 0.0, workoutStreak: 0)
        
        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()
        
        // Then - should return "0"
        XCTAssertEqual(formattedVolume, "0", "Format should return '0' for zero volume")
    }
    
    func testFormatTotalVolume_wholeNumber() {
        // Given - user stats with whole number volume
        viewModel.userStats = (totalWorkouts: 10, totalVolume: 5000.0, workoutStreak: 5)
        
        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()
        
        // Then - should return "5k" (no decimal)
        XCTAssertEqual(formattedVolume, "5k", "Format should return whole number for round thousands")
    }

    func testFormatTotalVolume_fractionalThousands() {
        // Given - user stats with non-round thousands
        viewModel.userStats = (totalWorkouts: 3, totalVolume: 1500.0, workoutStreak: 2)

        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()

        // Then - should keep one decimal place
        XCTAssertEqual(formattedVolume, "1.5k", "Format should preserve fractional thousands")
    }

    func testFormatTotalVolume_roundedFractionWithoutTrailingDecimal() {
        // Given - user stats that round to a whole thousand at one decimal precision
        viewModel.userStats = (totalWorkouts: 8, totalVolume: 1999.0, workoutStreak: 4)

        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()

        // Then - should avoid showing trailing .0
        XCTAssertEqual(formattedVolume, "2k", "Format should not show trailing .0k after rounding")
    }
    
    func testFormatTotalVolume_exactlyThreshold() {
        // Given - user stats with volume exactly at 1000
        viewModel.userStats = (totalWorkouts: 5, totalVolume: 1000.0, workoutStreak: 3)

        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()

        // Then - should return "1k"
        XCTAssertEqual(formattedVolume, "1k", "Format should abbreviate exact 1000 volume")
    }

    func testFormatTotalVolume_roundsNearThresholdIntoThousandsFormat() {
        // Given - user stats just below threshold that round to 1000.0
        viewModel.userStats = (totalWorkouts: 5, totalVolume: 999.95, workoutStreak: 3)

        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()

        // Then - should use thousands format after rounding
        XCTAssertEqual(formattedVolume, "1k", "Format should round near-threshold totals into thousands format")
    }

    func testFormatTotalVolume_belowThreshold() {
        // Given - user stats with volume below 1000
        viewModel.userStats = (totalWorkouts: 5, totalVolume: 950.0, workoutStreak: 3)
        
        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()
        
        // Then - should return "950" (no decimal, no 'k')
        XCTAssertEqual(formattedVolume, "950", "Format should return integer without decimal for volume below 1000")
    }

    func testFormatTotalVolume_roundsSubThousandInsteadOfTruncating() {
        // Given - user stats with a fractional value below 1000
        viewModel.userStats = (totalWorkouts: 5, totalVolume: 123.6, workoutStreak: 3)

        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()

        // Then - should round to nearest whole number, not floor
        XCTAssertEqual(formattedVolume, "124", "Format should round sub-thousand totals to nearest integer")
    }

    func testFormatTotalVolume_subThousandRoundedWholeBoundaryPromotesToThousands() {
        // Given - user stats below 1000 that round to 1000
        viewModel.userStats = (totalWorkouts: 5, totalVolume: 999.6, workoutStreak: 3)

        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()

        // Then - should stay consistent with thousands abbreviation
        XCTAssertEqual(formattedVolume, "1k", "Format should promote rounded 1000 values to thousands format")
    }

    func testFormatTotalVolume_negativeValue() {
        // Given - corrupted negative persisted volume
        viewModel.userStats = (totalWorkouts: 5, totalVolume: -250.0, workoutStreak: 3)

        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()

        // Then - should clamp to zero
        XCTAssertEqual(formattedVolume, "0", "Format should clamp negative volume to zero")
    }

    func testFormatTotalVolume_nonFiniteValue() {
        // Given - corrupted non-finite persisted volume
        viewModel.userStats = (totalWorkouts: 5, totalVolume: .infinity, workoutStreak: 3)

        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()

        // Then - should fail safe to zero
        XCTAssertEqual(formattedVolume, "0", "Format should fail safe for non-finite volume")
    }
    
    // MARK: - Weekly Progress Tests
    
    func testCalculateWeeklyProgress_noWorkouts() {
        let progress = viewModel.weeklyProgress(forWorkoutCount: 0)

        XCTAssertEqual(progress, 0.0, "Progress should be zero when there are no workouts")
    }

    func testCalculateWeeklyProgress_capsAtOne() {
        let progress = viewModel.weeklyProgress(forWorkoutCount: 10)

        XCTAssertEqual(progress, 1.0, "Progress should cap at 1.0 when workouts exceed weekly target")
    }

    func testCalculateWeeklyProgress_partialWeek() {
        let progress = viewModel.weeklyProgress(forWorkoutCount: 3)

        XCTAssertEqual(progress, 3.0 / 7.0, accuracy: 0.0001, "Progress should scale linearly within the weekly target")
    }

    // MARK: - Continue Workout Resolution

    func testCanContinueWorkout_withCurrentWorkoutAndNoActiveBinding() {
        let storedWorkout = Workout(name: "Stored Incomplete")
        viewModel.currentWorkout = storedWorkout

        let canContinue = viewModel.canContinueWorkout(activeWorkout: nil)
        let resumable = viewModel.resumableWorkout(activeWorkout: nil)

        XCTAssertTrue(canContinue, "Should continue when a resumable workout exists in Home state")
        XCTAssertTrue(resumable === storedWorkout, "Should prefer currentWorkout when active binding is nil")
    }

    func testCanContinueWorkout_prefersActiveBindingWhenPresent() {
        let storedWorkout = Workout(name: "Stored Incomplete")
        let activeWorkout = Workout(name: "Active Binding")
        viewModel.currentWorkout = storedWorkout

        let resumable = viewModel.resumableWorkout(activeWorkout: activeWorkout)

        XCTAssertTrue(resumable === activeWorkout, "Should prefer active binding workout when both are available")
    }

    func testCanContinueWorkout_withoutAnyWorkout() {
        viewModel.currentWorkout = nil

        let canContinue = viewModel.canContinueWorkout(activeWorkout: nil)

        XCTAssertFalse(canContinue, "Should not continue when no active or stored incomplete workout exists")
    }

    // MARK: - Incomplete Workout Resume Logic

    func testShouldResumeIncompleteWorkout_withoutDiscardState() {
        let workoutDate = Date()

        let shouldResume = viewModel.shouldResumeIncompleteWorkout(
            workoutDate: workoutDate,
            discardTimestamp: nil,
            wasAnyWorkoutDiscarded: false
        )

        XCTAssertTrue(shouldResume, "Should resume incomplete workout when no discard state exists")
    }

    func testShouldResumeIncompleteWorkout_withDiscardedOlderWorkout() {
        let discardTime = Date()
        let workoutDate = discardTime.addingTimeInterval(-60)

        let shouldResume = viewModel.shouldResumeIncompleteWorkout(
            workoutDate: workoutDate,
            discardTimestamp: discardTime,
            wasAnyWorkoutDiscarded: true
        )

        XCTAssertFalse(shouldResume, "Should not resume an incomplete workout that predates discard time")
    }

    func testShouldResumeIncompleteWorkout_withDiscardedNewerWorkout() {
        let discardTime = Date()
        let workoutDate = discardTime.addingTimeInterval(60)

        let shouldResume = viewModel.shouldResumeIncompleteWorkout(
            workoutDate: workoutDate,
            discardTimestamp: discardTime,
            wasAnyWorkoutDiscarded: true
        )

        XCTAssertTrue(shouldResume, "Should resume incomplete workouts created after a discard event")
    }

    func testShouldResumeIncompleteWorkout_withWorkoutAtDiscardTimestamp() {
        let discardTime = Date()
        let workoutDate = discardTime

        let shouldResume = viewModel.shouldResumeIncompleteWorkout(
            workoutDate: workoutDate,
            discardTimestamp: discardTime,
            wasAnyWorkoutDiscarded: true
        )

        XCTAssertTrue(shouldResume, "Should resume incomplete workout when timestamps are equal to avoid false negatives from coarse timestamp precision")
    }

    func testShouldResumeIncompleteWorkout_withDiscardFlagButNoTimestamp() {
        let workoutDate = Date()

        let shouldResume = viewModel.shouldResumeIncompleteWorkout(
            workoutDate: workoutDate,
            discardTimestamp: nil,
            wasAnyWorkoutDiscarded: true
        )

        XCTAssertFalse(shouldResume, "Should fail safe when discard flag exists without timestamp")
    }

    func testShouldResumeIncompleteWorkout_withoutWorkout() {
        let shouldResume = viewModel.shouldResumeIncompleteWorkout(
            workoutDate: nil,
            discardTimestamp: Date(),
            wasAnyWorkoutDiscarded: false
        )

        XCTAssertFalse(shouldResume, "Should not resume when there is no incomplete workout")
    }
}
