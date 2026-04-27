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

    func testFormatTotalVolume_thousandsFormattingTruncatesWithoutOverstating() {
        // Given - user stats near the next thousand boundary
        viewModel.userStats = (totalWorkouts: 8, totalVolume: 1999.0, workoutStreak: 4)

        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()

        // Then - should not round up to an inflated thousand value
        XCTAssertEqual(formattedVolume, "1.9k", "Format should truncate thousands to avoid overstating progress")
    }

    func testFormatTotalVolume_millionsFormattingUsesSuffix() {
        // Given - user stats with a whole-number million value
        viewModel.userStats = (totalWorkouts: 12, totalVolume: 1_000_000.0, workoutStreak: 6)

        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()

        // Then - should abbreviate to millions
        XCTAssertEqual(formattedVolume, "1M", "Format should abbreviate million-scale totals with an M suffix")
    }

    func testFormatTotalVolume_millionsFormattingTruncatesWithoutOverstating() {
        // Given - user stats near the next million boundary
        viewModel.userStats = (totalWorkouts: 12, totalVolume: 1_999_999.0, workoutStreak: 6)

        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()

        // Then - should truncate instead of rounding up to 2M
        XCTAssertEqual(formattedVolume, "1.9M", "Format should truncate million-scale totals to avoid overstating progress")
    }
    
    func testFormatTotalVolume_exactlyThreshold() {
        // Given - user stats with volume exactly at 1000
        viewModel.userStats = (totalWorkouts: 5, totalVolume: 1000.0, workoutStreak: 3)

        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()

        // Then - should return "1k"
        XCTAssertEqual(formattedVolume, "1k", "Format should abbreviate exact 1000 volume")
    }

    func testFormatTotalVolume_doesNotPromoteSubThousandValuesIntoThousandsFormat() {
        // Given - user stats just below threshold
        viewModel.userStats = (totalWorkouts: 5, totalVolume: 999.95, workoutStreak: 3)

        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()

        // Then - should avoid inflating into thousands format
        XCTAssertEqual(formattedVolume, "999", "Format should keep sub-thousand totals below 1k")
    }

    func testFormatTotalVolume_belowThreshold() {
        // Given - user stats with volume below 1000
        viewModel.userStats = (totalWorkouts: 5, totalVolume: 950.0, workoutStreak: 3)
        
        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()
        
        // Then - should return "950" (no decimal, no 'k')
        XCTAssertEqual(formattedVolume, "950", "Format should return integer without decimal for volume below 1000")
    }

    func testFormatTotalVolume_truncatesSubThousandFractionsToAvoidOverstatement() {
        // Given - user stats with a fractional value below 1000
        viewModel.userStats = (totalWorkouts: 5, totalVolume: 123.6, workoutStreak: 3)

        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()

        // Then - should truncate instead of rounding up
        XCTAssertEqual(formattedVolume, "123", "Format should truncate sub-thousand totals")
    }

    func testFormatTotalVolume_subThousandBoundaryDoesNotPromoteToThousands() {
        // Given - user stats below 1000 near the boundary
        viewModel.userStats = (totalWorkouts: 5, totalVolume: 999.6, workoutStreak: 3)

        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()

        // Then - should remain sub-thousand
        XCTAssertEqual(formattedVolume, "999", "Format should not promote sub-thousand totals to 1k")
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

    // MARK: - Recent Workout Filtering

    func testCompletedRecentWorkouts_excludesIncompleteAndRespectsLimit() {
        let now = Date()

        let newestIncomplete = Workout(date: now, name: "In Progress", isCompleted: false)
        let newestCompleted = Workout(date: now.addingTimeInterval(-60), name: "Completed 1", isCompleted: true)
        let olderCompleted = Workout(date: now.addingTimeInterval(-120), name: "Completed 2", isCompleted: true)
        let oldestCompleted = Workout(date: now.addingTimeInterval(-180), name: "Completed 3", isCompleted: true)

        let recent = viewModel.completedRecentWorkouts(
            from: [olderCompleted, newestIncomplete, oldestCompleted, newestCompleted],
            limit: 2
        )

        XCTAssertEqual(recent.count, 2, "Should cap to requested recent workout limit")
        XCTAssertTrue(recent.allSatisfy(\.isCompleted), "Should exclude in-progress workouts from Recent Workouts list")
        XCTAssertTrue(recent[0] === newestCompleted, "Should keep most-recent completed workout first")
        XCTAssertTrue(recent[1] === olderCompleted, "Should include the next most-recent completed workout")
    }

    func testCompletedRecentWorkouts_withNonPositiveLimitReturnsEmpty() {
        let workout = Workout(date: Date(), name: "Completed", isCompleted: true)

        XCTAssertTrue(
            viewModel.completedRecentWorkouts(from: [workout], limit: 0).isEmpty,
            "Should return no workouts when limit is zero"
        )
    }

    func testResolvedRecentCompletedWorkouts_usesRecentSliceWhenItAlreadySatisfiesLimit() {
        let now = Date()
        let recentCompletedA = Workout(date: now, name: "Recent A", isCompleted: true)
        let recentCompletedB = Workout(date: now.addingTimeInterval(-60), name: "Recent B", isCompleted: true)
        let fallbackCompleted = Workout(date: now.addingTimeInterval(120), name: "Fallback", isCompleted: true)

        let resolved = viewModel.resolvedRecentCompletedWorkouts(
            from: [recentCompletedB, recentCompletedA],
            fallbackAllWorkouts: [fallbackCompleted],
            limit: 2
        )

        XCTAssertEqual(resolved.count, 2, "Should return requested limit when recent slice already has enough completed workouts")
        XCTAssertTrue(resolved[0] === recentCompletedA, "Should keep recent-slice ordering by newest completed date")
        XCTAssertTrue(resolved[1] === recentCompletedB, "Should keep second-most-recent completed workout from recent slice")
    }

    func testResolvedRecentCompletedWorkouts_fallsBackToFullHistoryWhenRecentSliceIsSparse() {
        let now = Date()
        let recentIncomplete = Workout(date: now, name: "Draft", isCompleted: false)
        let recentCompleted = Workout(date: now.addingTimeInterval(-60), name: "Recent Completed", isCompleted: true)

        let historyNewest = Workout(date: now.addingTimeInterval(120), name: "History Newest", isCompleted: true)
        let historySecond = Workout(date: now.addingTimeInterval(30), name: "History Second", isCompleted: true)
        let historyOlder = Workout(date: now.addingTimeInterval(-300), name: "History Older", isCompleted: true)

        let resolved = viewModel.resolvedRecentCompletedWorkouts(
            from: [recentIncomplete, recentCompleted],
            fallbackAllWorkouts: [historyOlder, historySecond, historyNewest],
            limit: 2
        )

        XCTAssertEqual(resolved.count, 2, "Should use fallback history to fill requested limit when recent slice is sparse")
        XCTAssertTrue(resolved[0] === historyNewest, "Should return most-recent completed workout from full history fallback")
        XCTAssertTrue(resolved[1] === historySecond, "Should include next most-recent completed workout from full history fallback")
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

    func testResumableWorkout_skipsCompletedActiveBindingAndFallsBackToCurrentIncomplete() {
        let completedActiveWorkout = Workout(name: "Completed Active", isCompleted: true)
        let storedIncompleteWorkout = Workout(name: "Stored Incomplete", isCompleted: false)
        viewModel.currentWorkout = storedIncompleteWorkout

        let resumable = viewModel.resumableWorkout(activeWorkout: completedActiveWorkout)

        XCTAssertTrue(resumable === storedIncompleteWorkout, "Should ignore completed active binding and resume the stored incomplete workout")
    }

    func testCanContinueWorkout_returnsFalseWhenOnlyCompletedWorkoutsExist() {
        let completedActiveWorkout = Workout(name: "Completed Active", isCompleted: true)
        let completedStoredWorkout = Workout(name: "Completed Stored", isCompleted: true)
        viewModel.currentWorkout = completedStoredWorkout

        let canContinue = viewModel.canContinueWorkout(activeWorkout: completedActiveWorkout)

        XCTAssertFalse(canContinue, "Should not continue when both active and stored workouts are already completed")
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

        XCTAssertTrue(shouldResume, "Should still resume when discard flag exists without timestamp to avoid hiding valid incomplete workouts")
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
