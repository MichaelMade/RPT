//
//  HomeViewModelTests.swift
//  RPTTests
//
//  Created by Michael Moore on 5/2/25.
//

import XCTest
import SwiftData
@testable import RPT

@MainActor
final class HomeViewModelTests: XCTestCase {
    private final class FailingDataManager: DataManaging {
        private let wrappedContext: ModelContext

        init(context: ModelContext) {
            self.wrappedContext = context
        }

        func getModelContext() -> ModelContext {
            wrappedContext
        }

        func saveChanges() throws {
            throw DataManager.DataError.saveFailed
        }
    }

    var viewModel: HomeViewModel!
    
    override func setUp() {
        super.setUp()
        WorkoutStateManager.shared.clearDiscardedState()
        viewModel = HomeViewModel()
    }
    
    override func tearDown() {
        WorkoutStateManager.shared.clearDiscardedState()
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

    func testLifetimeWorkMetric_prefersWeightedVolumeWhenAvailable() {
        let metric = viewModel.lifetimeWorkMetric(totalVolume: 1520, totalBodyweightReps: 200)

        XCTAssertEqual(metric.title, "Volume")
        XCTAssertEqual(metric.value, "1.5k")
        XCTAssertEqual(metric.subtitle, "lb lifted")
    }

    func testLifetimeWorkMetric_fallsBackToBodyweightRepsWhenNoWeightedVolumeExists() {
        let metric = viewModel.lifetimeWorkMetric(totalVolume: 0, totalBodyweightReps: 245)

        XCTAssertEqual(metric.title, "Reps")
        XCTAssertEqual(metric.value, "245")
        XCTAssertEqual(metric.subtitle, "bodyweight reps")
    }

    func testLifetimeWorkMetric_clampsCorruptedInputsSafely() {
        let metric = viewModel.lifetimeWorkMetric(totalVolume: -.infinity, totalBodyweightReps: -20)

        XCTAssertEqual(metric.title, "Volume")
        XCTAssertEqual(metric.value, "0")
        XCTAssertEqual(metric.subtitle, "lb lifted")
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

    func testWeeklyProgressSummary_usesStableCopy() {
        let summary = viewModel.weeklyProgressSummary(forWorkoutCount: 1)

        XCTAssertEqual(summary, "1 of 7 workouts", "Summary should stay readable at singular counts")
    }

    func testWeeklyProgressSummary_clampsNegativeCounts() {
        let summary = viewModel.weeklyProgressSummary(forWorkoutCount: -3)

        XCTAssertEqual(summary, "0 of 7 workouts", "Summary should clamp negative counts to zero")
    }

    func testWeeklyProgressSummary_capsVisibleCountAtWeeklyGoal() {
        let summary = viewModel.weeklyProgressSummary(forWorkoutCount: 10)

        XCTAssertEqual(summary, "7 of 7 workouts", "Summary should cap the visible count at the 7-workout goal to match the full progress state")
    }

    func testWeeklyProgressSubtitle_emptyWeekGuidance() {
        let subtitle = viewModel.weeklyProgressSubtitle(forWorkoutCount: 0)

        XCTAssertEqual(subtitle, "Log a workout to start your weekly streak.", "Subtitle should guide brand-new users when they have no recent workouts")
    }

    func testWeeklyProgressSubtitle_emptyWeekForReturningUserUsesRestartCopy() {
        let subtitle = viewModel.weeklyProgressSubtitle(forWorkoutCount: 0, hasLoggedWorkouts: true)

        XCTAssertEqual(subtitle, "Log a workout to restart your weekly streak.", "Subtitle should acknowledge returning users when the last 7 days are empty")
    }

    func testWeeklyProgressSubtitle_emptyWeekWithNamedDraftUsesDraftSpecificRestartCopy() {
        let draft = Workout(name: "Push Day", isCompleted: false)
        draft.sets = [ExerciseSet(weight: 135, reps: 8, isCompleted: true)]

        let subtitle = viewModel.weeklyProgressSubtitle(
            forWorkoutCount: 0,
            hasLoggedWorkouts: true,
            activeWorkout: draft
        )

        XCTAssertEqual(subtitle, "Finish “Push Day” to restart your weekly streak.")
    }

    func testWeeklyProgressSubtitle_emptyWeekWithNamedEmptyDraftPromptsForExercise() {
        let draft = Workout(name: "Push Day", isCompleted: false)

        let subtitle = viewModel.weeklyProgressSubtitle(
            forWorkoutCount: 0,
            hasLoggedWorkouts: true,
            activeWorkout: draft
        )

        XCTAssertEqual(subtitle, "Add an exercise to “Push Day” to restart your weekly streak.")
    }

    func testWeeklyProgressSubtitle_partialWeekCountsRemainingWorkouts() {
        let subtitle = viewModel.weeklyProgressSubtitle(forWorkoutCount: 5)

        XCTAssertEqual(subtitle, "2 more workouts to fill the last-7-days goal.", "Subtitle should explain how many workouts remain in the weekly goal")
    }

    func testWeeklyProgressSubtitle_goalMetUsesCompletionCopy() {
        let subtitle = viewModel.weeklyProgressSubtitle(forWorkoutCount: 7)

        XCTAssertEqual(subtitle, "You’ve hit your 7-workout pace for the last 7 days.", "Subtitle should celebrate when the weekly goal is met")
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

    func testRecentWorkoutsEmptyState_withoutDraftEncouragesFirstCompletion() {
        let emptyState = viewModel.recentWorkoutsEmptyState(activeWorkout: nil)

        XCTAssertEqual(emptyState.title, "No recent workouts yet")
        XCTAssertEqual(emptyState.subtitle, "Complete a workout and your latest sessions will show up here for quick review.")
    }

    func testProgressEmptyState_withoutDraftEncouragesFirstCompletion() {
        let emptyState = viewModel.progressEmptyState(activeWorkout: nil)

        XCTAssertEqual(emptyState.title, "No workouts logged yet")
        XCTAssertEqual(emptyState.subtitle, "Finish your first workout to start a streak and unlock lifetime progress on Home.")
    }

    func testProgressEmptyState_withNamedResumableDraftUsesWorkoutName() {
        let draft = Workout(name: "Push Day", isCompleted: false)
        draft.sets = [ExerciseSet(weight: 135, reps: 8, isCompleted: true)]

        let emptyState = viewModel.progressEmptyState(activeWorkout: draft)

        XCTAssertEqual(emptyState.title, "Workout in progress")
        XCTAssertEqual(emptyState.subtitle, "Finish “Push Day” to start a streak and unlock lifetime progress on Home.")
    }

    func testProgressEmptyState_withNamedEmptyDraftPointsToAddingExercisesOrSaving() {
        let draft = Workout(name: "Push Day", isCompleted: false)

        let emptyState = viewModel.progressEmptyState(activeWorkout: draft)

        XCTAssertEqual(emptyState.title, "Workout draft in progress")
        XCTAssertEqual(emptyState.subtitle, "Add an exercise to “Push Day” to start your streak, or save it for later until you are ready to train.")
    }

    func testProgressEmptyState_withPlaceholderDraftStaysGeneric() {
        let draft = Workout(name: "Current Workout", isCompleted: false)
        draft.sets = [ExerciseSet(weight: 135, reps: 8, isCompleted: true)]

        let emptyState = viewModel.progressEmptyState(activeWorkout: draft)

        XCTAssertEqual(emptyState.title, "Workout in progress")
        XCTAssertEqual(emptyState.subtitle, "Finish this workout to start a streak and unlock lifetime progress on Home.")
    }

    func testProgressEmptyState_withPlaceholderEmptyDraftStaysGeneric() {
        let draft = Workout(name: "Current Workout", isCompleted: false)

        let emptyState = viewModel.progressEmptyState(activeWorkout: draft)

        XCTAssertEqual(emptyState.title, "Workout draft in progress")
        XCTAssertEqual(emptyState.subtitle, "Add an exercise to start your streak, or save this workout for later until you are ready to train.")
    }

    func testRecentWorkoutsEmptyState_withNamedResumableDraftUsesWorkoutName() {
        let draft = Workout(name: "Push Day", isCompleted: false)
        draft.sets = [ExerciseSet(weight: 135, reps: 8, isCompleted: true)]

        let emptyState = viewModel.recentWorkoutsEmptyState(activeWorkout: draft)

        XCTAssertEqual(emptyState.title, "No completed workouts yet")
        XCTAssertEqual(emptyState.subtitle, "Finish “Push Day” to see it show up here with your latest stats.")
    }

    func testRecentWorkoutsEmptyState_withNamedEmptyDraftPointsToAddingExercisesOrSaving() {
        let draft = Workout(name: "Push Day", isCompleted: false)

        let emptyState = viewModel.recentWorkoutsEmptyState(activeWorkout: draft)

        XCTAssertEqual(emptyState.title, "No completed workouts yet")
        XCTAssertEqual(emptyState.subtitle, "Add an exercise to “Push Day” before finishing it, or save it for later to keep it as a draft.")
    }

    func testRecentWorkoutsEmptyState_withPlaceholderDraftStaysGeneric() {
        let draft = Workout(name: "Current Workout", isCompleted: false)
        draft.sets = [ExerciseSet(weight: 135, reps: 8, isCompleted: true)]

        let emptyState = viewModel.recentWorkoutsEmptyState(activeWorkout: draft)

        XCTAssertEqual(emptyState.title, "No completed workouts yet")
        XCTAssertEqual(emptyState.subtitle, "Finish this workout to see it show up here with your latest stats.")
    }

    func testRecentWorkoutsEmptyState_withPlaceholderEmptyDraftStaysGeneric() {
        let draft = Workout(name: "Current Workout", isCompleted: false)

        let emptyState = viewModel.recentWorkoutsEmptyState(activeWorkout: draft)

        XCTAssertEqual(emptyState.title, "No completed workouts yet")
        XCTAssertEqual(emptyState.subtitle, "Add an exercise before finishing this workout, or save it for later to keep it as a draft.")
    }

    func testShouldShowSingleRecentWorkoutQuickActions_onlyForSoloHistoryEntry() {
        XCTAssertTrue(
            viewModel.shouldShowSingleRecentWorkoutQuickActions(recentWorkoutCount: 1),
            "A single recent workout should surface visible quick actions so first-time history review does not depend on swipe discovery"
        )
        XCTAssertFalse(
            viewModel.shouldShowSingleRecentWorkoutQuickActions(recentWorkoutCount: 0),
            "No quick actions should appear when there is no recent workout to act on"
        )
        XCTAssertFalse(
            viewModel.shouldShowSingleRecentWorkoutQuickActions(recentWorkoutCount: 2),
            "Visible quick actions should stay reserved for the lone-history case to avoid cluttering longer lists"
        )
    }

    func testDeleteRecentWorkoutMessage_mentionsHistoryAndSavedCounts() {
        var calendar = Calendar(identifier: .gregorian)
        let locale = Locale(identifier: "en_US_POSIX")
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone

        let workoutDate = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 5,
            day: 13,
            hour: 6,
            minute: 45
        ).date!
        let now = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 5,
            day: 13,
            hour: 8,
            minute: 0
        ).date!

        let workout = Workout(date: workoutDate, name: "  Upper   A  ", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back])
        workout.addSet(exercise: bench, weight: 185, reps: 8)
        workout.addSet(exercise: row, weight: 135, reps: 10)

        let message = viewModel.deleteRecentWorkoutMessage(for: workout, now: now)

        XCTAssertEqual(
            message,
            "Delete Upper A from history? Today • 6:45 AM • 2 exercises • 2 working sets will be removed from your saved workout history.",
            "Delete confirmation should stay specific for working-only saved sessions instead of falling back to generic set wording"
        )
    }

    func testDeleteRecentWorkoutMessage_mentionsWorkingAndWarmupBreakdownWhenBothExist() {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone
        let workoutDate = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 5,
            day: 13,
            hour: 6,
            minute: 45
        ).date!
        let now = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 5,
            day: 13,
            hour: 8,
            minute: 0
        ).date!

        let workout = Workout(date: workoutDate, name: "Upper A", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        workout.addSet(exercise: bench, weight: 185, reps: 8)
        workout.addSet(exercise: bench, weight: 45, reps: 12, isWarmup: true)

        let message = viewModel.deleteRecentWorkoutMessage(for: workout, now: now)

        XCTAssertEqual(
            message,
            "Delete Upper A from history? Today • 6:45 AM • 1 exercise • 2 logged sets (1 working, 1 warm-up) will be removed from your saved workout history.",
            "Delete confirmation should call out both working and warm-up data when removing a mixed saved session from history"
        )
    }

    func testDeleteRecentWorkoutMessage_usesWarmupOnlyFallbackCopy() {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone
        let workoutDate = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 5,
            day: 13,
            hour: 6,
            minute: 45
        ).date!
        let now = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 5,
            day: 13,
            hour: 8,
            minute: 0
        ).date!

        let workout = Workout(date: workoutDate, name: "Warm-up Only", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = workout.addSet(exercise: bench, weight: 45, reps: 12, isWarmup: true)

        let message = viewModel.deleteRecentWorkoutMessage(for: workout, now: now)

        XCTAssertEqual(
            message,
            "Delete Warm-up Only from history? Today • 6:45 AM • Warm-up sets only will be removed from your saved workout history.",
            "Delete confirmation should reuse the warm-up-only fallback copy instead of implying that real working sets were logged"
        )
    }

    func testDeleteRecentWorkoutMessage_usesNoSetsLoggedFallbackCopy() {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone
        let workoutDate = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 5,
            day: 13,
            hour: 6,
            minute: 45
        ).date!
        let now = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 5,
            day: 13,
            hour: 8,
            minute: 0
        ).date!

        let workout = Workout(date: workoutDate, name: "Imported Session", isCompleted: true)

        let message = viewModel.deleteRecentWorkoutMessage(for: workout, now: now)

        XCTAssertEqual(
            message,
            "Delete Imported Session from history? Today • 6:45 AM • No sets logged will be removed from your saved workout history.",
            "Delete confirmation should stay honest for empty completed history entries instead of showing noisy zero-count metrics"
        )
    }

    func testDiscardCurrentWorkoutAndStartFollowUpAlertMessage_mentionsSourceSessionCounts() {
        let workout = Workout(name: "  Upper   A  ", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back])
        workout.addSet(exercise: bench, weight: 185, reps: 8)
        workout.addSet(exercise: row, weight: 135, reps: 10)

        XCTAssertEqual(
            viewModel.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: workout),
            "Your in-progress workout will be lost and RPT will immediately start a follow-up from “Upper A”. Source session: 2 exercises • 2 working sets. This action cannot be undone.",
            "Discard-and-start follow-up confirmations should stay specific for working-only source sessions too"
        )
    }

    func testDiscardCurrentWorkoutAndStartFollowUpAlertMessage_usesWarmupOnlyFallbackSourceSummary() {
        let workout = Workout(name: " \n ", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = workout.addSet(exercise: bench, weight: 45, reps: 12, isWarmup: true)

        XCTAssertEqual(
            viewModel.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: workout),
            "Your in-progress workout will be lost before RPT starts the selected follow-up. Source session: Warm-up sets only. This action cannot be undone.",
            "Blank legacy names should still keep the follow-up confirmation honest about the source session"
        )
    }

    func testDiscardCurrentWorkoutAndStartFollowUpAlertMessage_mentionsWorkingAndWarmupBreakdownWhenBothExist() {
        let workout = Workout(name: "Upper A", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        workout.addSet(exercise: bench, weight: 185, reps: 8)
        workout.addSet(exercise: bench, weight: 45, reps: 12, isWarmup: true)

        XCTAssertEqual(
            viewModel.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: workout),
            "Your in-progress workout will be lost and RPT will immediately start a follow-up from “Upper A”. Source session: 1 exercise • 2 logged sets (1 working, 1 warm-up). This action cannot be undone.",
            "Follow-up confirmations should keep the same working-vs-warm-up specificity as history delete confirmations"
        )
    }

    func testDeleteRecentWorkoutFailureMessage_usesGenericFallbackForBlankWorkoutName() {
        let workout = Workout(name: "   ", isCompleted: true)

        let message = viewModel.deleteRecentWorkoutFailureMessage(for: workout)

        XCTAssertEqual(
            message,
            "Couldn’t delete this workout from history. Keep it for now, then try again.",
            "Delete failures should stay generic when the saved workout name is blank or corrupted"
        )
    }

    func testDeleteRecentWorkoutFailureAlertTitle_usesExactWorkoutName() {
        let workout = Workout(name: "Upper A", isCompleted: true)

        XCTAssertEqual(
            viewModel.deleteRecentWorkoutFailureAlertTitle(for: workout),
            "Couldn’t Delete “Upper A”",
            "Delete failure alerts should keep naming the exact workout that stayed in history"
        )
    }

    func testDeleteRecentWorkoutFailureAlertTitle_usesFallbackWorkoutName() {
        let workout = Workout(name: "   ", isCompleted: true)

        XCTAssertEqual(
            viewModel.deleteRecentWorkoutFailureAlertTitle(for: workout),
            "Couldn’t Delete This Workout",
            "Delete failure alerts should stay generic when the saved workout name is blank or corrupted"
        )
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

    func testResumableWorkout_skipsDiscardedActiveBindingAndFallsBackToNewerStoredDraft() {
        let discardTime = Date()
        let discardedActiveWorkout = Workout(date: discardTime.addingTimeInterval(-120), name: "Discarded Active", isCompleted: false)
        let storedWorkout = Workout(date: discardTime.addingTimeInterval(120), name: "Stored Draft", isCompleted: false)
        viewModel.currentWorkout = storedWorkout

        let workoutStateManager = WorkoutStateManager.shared
        workoutStateManager.markWorkoutAsDiscarded(discardedActiveWorkout.id)
        workoutStateManager.discardTimestamp = discardTime

        let resumable = viewModel.resumableWorkout(activeWorkout: discardedActiveWorkout)

        XCTAssertTrue(resumable === storedWorkout, "Should ignore an incomplete binding that predates the discard timestamp and fall back to a newer eligible draft")
    }

    func testCanContinueWorkout_returnsFalseWhenOnlyDiscardedIncompleteWorkoutExists() {
        let discardTime = Date()
        let discardedStoredWorkout = Workout(date: discardTime.addingTimeInterval(-60), name: "Discarded Draft", isCompleted: false)
        viewModel.currentWorkout = discardedStoredWorkout

        let workoutStateManager = WorkoutStateManager.shared
        workoutStateManager.markWorkoutAsDiscarded(discardedStoredWorkout.id)
        workoutStateManager.discardTimestamp = discardTime

        let canContinue = viewModel.canContinueWorkout(activeWorkout: nil)

        XCTAssertFalse(canContinue, "Should not offer Continue Workout when the only incomplete draft was already discarded")
    }

    func testResolvedActiveWorkoutBinding_prefersExistingIncompleteBinding() {
        let activeWorkout = Workout(name: "Current Active")
        let storedWorkout = Workout(name: "Stored Draft")

        let resolved = viewModel.resolvedActiveWorkoutBinding(
            currentBinding: activeWorkout,
            storedWorkout: storedWorkout
        )

        XCTAssertTrue(resolved === activeWorkout, "Should preserve the current active binding instead of overwriting it with a stored fallback")
    }

    func testResolvedActiveWorkoutBinding_fallsBackToStoredIncompleteWorkout() {
        let storedWorkout = Workout(name: "Stored Draft")
        let completedBinding = Workout(name: "Completed Active", isCompleted: true)

        let resolved = viewModel.resolvedActiveWorkoutBinding(
            currentBinding: completedBinding,
            storedWorkout: storedWorkout
        )

        XCTAssertTrue(resolved === storedWorkout, "Should recover the stored incomplete workout when the current binding is missing or already completed")
    }

    func testResolvedActiveWorkoutBinding_returnsNilWhenNoIncompleteWorkoutExists() {
        let completedBinding = Workout(name: "Completed Active", isCompleted: true)
        let completedStoredWorkout = Workout(name: "Completed Stored", isCompleted: true)

        let resolved = viewModel.resolvedActiveWorkoutBinding(
            currentBinding: completedBinding,
            storedWorkout: completedStoredWorkout
        )

        XCTAssertNil(resolved, "Should clear the active binding when neither the current binding nor stored fallback is resumable")
    }

    func testResolvedActiveWorkoutBinding_skipsDiscardedBindingAndRecoversNewerStoredDraft() {
        let discardTime = Date()
        let discardedBinding = Workout(date: discardTime.addingTimeInterval(-120), name: "Discarded Binding", isCompleted: false)
        let storedWorkout = Workout(date: discardTime.addingTimeInterval(120), name: "Recovered Draft", isCompleted: false)

        let workoutStateManager = WorkoutStateManager.shared
        workoutStateManager.markWorkoutAsDiscarded(discardedBinding.id)
        workoutStateManager.discardTimestamp = discardTime

        let resolved = viewModel.resolvedActiveWorkoutBinding(
            currentBinding: discardedBinding,
            storedWorkout: storedWorkout
        )

        XCTAssertTrue(resolved === storedWorkout, "Should replace a discarded in-memory binding with a newer eligible stored draft")
    }

    func testShouldReloadAfterWorkoutSheetPresentationChange_onlyOnDismiss() {
        XCTAssertTrue(
            viewModel.shouldReloadAfterWorkoutSheetPresentationChange(from: true, to: false),
            "Closing the active workout sheet should trigger a Home refresh so recent workouts and stats stay current"
        )

        XCTAssertFalse(
            viewModel.shouldReloadAfterWorkoutSheetPresentationChange(from: false, to: true),
            "Opening the active workout sheet should not eagerly reload Home state"
        )

        XCTAssertFalse(
            viewModel.shouldReloadAfterWorkoutSheetPresentationChange(from: false, to: false),
            "No-op sheet state changes should not trigger a Home refresh"
        )
    }

    func testResumableWorkoutSummary_includesTemplateCountsAndStartedProgress() {
        let startDate = Date(timeIntervalSince1970: 0)
        let now = startDate.addingTimeInterval(2 * 3600)
        let workout = Workout(date: startDate, name: "Push Day", startedFromTemplate: "  Upper  A  ")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        workout.addSet(exercise: exercise, weight: 185, reps: 8)

        let summary = viewModel.resumableWorkoutSummary(for: workout, now: now)

        XCTAssertEqual(summary, "Started 2h ago • From Upper A • 1 exercise • 1 set • Exercise started", "Summary should show elapsed time, template origin, current draft counts, and whether logged work has started")
    }

    func testResumableWorkoutSummary_prefersResolvedTemplateNameWhenSourceTemplateWasRenamed() throws {
        let context = DataManager.shared.getModelContext()
        let template = WorkoutTemplate(name: "  Renamed   Upper A  ")
        context.insert(template)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(template)
            try? context.save()
        }

        let startDate = Date(timeIntervalSince1970: 0)
        let now = startDate.addingTimeInterval(20 * 60)
        let workout = Workout(
            date: startDate,
            name: "Push Day",
            startedFromTemplate: "Old Upper A",
            startedFromTemplateID: template.id
        )
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        workout.addSet(exercise: exercise, weight: 185, reps: 8)

        let summary = viewModel.resumableWorkoutSummary(for: workout, now: now)

        XCTAssertEqual(
            summary,
            "Started 20m ago • From Renamed Upper A • 1 exercise • 1 set • Exercise started",
            "Resumable workout summaries should prefer the current template name from stable-ID lookup so renamed plans do not show stale source-template labels during resume/discard decisions"
        )
    }

    func testResumableWorkoutSummary_emptyDraftExplainsNoExercisesYet() {
        let startDate = Date(timeIntervalSince1970: 0)
        let now = startDate.addingTimeInterval(30)
        let workout = Workout(date: startDate, name: "Draft Workout")

        let summary = viewModel.resumableWorkoutSummary(for: workout, now: now)

        XCTAssertEqual(summary, "Started just now • No exercises added yet", "Summary should explain empty drafts instead of showing zero-count noise")
    }

    func testContinueCurrentWorkoutButtonTitle_namesSpecificDraftWhenWorkoutHasLoggedOrPlannedWork() {
        let workout = Workout(name: "  Upper   A  ")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = workout.addSet(exercise: exercise, weight: 185, reps: 8)

        XCTAssertEqual(
            viewModel.continueCurrentWorkoutButtonTitle(for: workout),
            "Continue “Upper A”",
            "Continue CTAs should keep the in-progress wording once the draft already contains workout content"
        )
    }

    func testContinueCurrentWorkoutButtonTitle_usesOpenLanguageForEmptyNamedDraft() {
        let workout = Workout(name: "  Upper   A  ")

        XCTAssertEqual(
            viewModel.continueCurrentWorkoutButtonTitle(for: workout),
            "Open “Upper A”",
            "Zero-exercise draft recovery should say Open so blocked flows do not imply the draft is already far enough along to simply continue"
        )
    }

    func testContinueCurrentWorkoutButtonTitle_usesOpenLanguageForUntouchedPlannedDraft() {
        let workout = Workout(name: "  Upper   A  ")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let set = workout.addSet(exercise: exercise, weight: 185, reps: 8)
        set.completedAt = .distantPast

        XCTAssertEqual(
            viewModel.continueCurrentWorkoutButtonTitle(for: workout),
            "Open “Upper A”",
            "Template-seeded or manually planned drafts should still say Open until the user has actually logged work"
        )
    }

    func testContinueCurrentWorkoutButtonTitle_fallsBackForGenericDraftName() {
        let workout = Workout(name: "   ")

        XCTAssertEqual(
            viewModel.continueCurrentWorkoutButtonTitle(for: workout),
            "Open Workout",
            "Unnamed empty drafts should keep the clearer open-workout wording in blocked recovery flows"
        )
    }

    func testResumableWorkoutRecoveryInstruction_matchesEmptyDraftGuidance() {
        let workout = Workout(name: "Upper A")

        XCTAssertEqual(
            HomeViewModel.resumableWorkoutRecoveryInstruction(for: workout),
            "Add an exercise to keep going, save it for later, or discard it",
            "Shared recovery guidance should keep empty drafts on the add-an-exercise path"
        )
    }

    func testResumableWorkoutRecoveryInstruction_matchesUntouchedPlannedDraftGuidance() {
        let workout = Workout(name: "Upper A")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let set = workout.addSet(exercise: exercise, weight: 185, reps: 8)
        set.completedAt = .distantPast

        XCTAssertEqual(
            HomeViewModel.resumableWorkoutRecoveryInstruction(for: workout),
            "Open it, save it for later, or discard it",
            "Shared recovery guidance should keep untouched planned drafts on the reopen path"
        )
    }

    func testResumableWorkoutRecoveryInstruction_matchesLoggedWorkoutGuidanceWithTerminator() {
        let workout = Workout(name: "Upper A")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = workout.addSet(exercise: exercise, weight: 185, reps: 8)

        XCTAssertEqual(
            HomeViewModel.resumableWorkoutRecoveryInstruction(for: workout, terminator: "."),
            "Continue it, save it for later, or discard it.",
            "Shared recovery guidance should preserve the continue wording and punctuation for in-progress drafts with logged work"
        )
    }

    func testActiveWorkoutInProgressTitle_namesSpecificDraftWhenAvailable() {
        let workout = Workout(name: "  Upper   A  ")

        XCTAssertEqual(
            viewModel.activeWorkoutInProgressTitle(for: workout),
            "“Upper A” Draft In Progress",
            "Blocked-workout titles should name the exact draft and reflect that it has not started yet"
        )
    }

    func testActiveWorkoutInProgressTitle_fallsBackForBlankOrMissingDraftName() {
        let blankWorkout = Workout(name: "   ")
        let legacyPlaceholderWorkout = Workout(name: "Current Workout")

        XCTAssertEqual(
            viewModel.activeWorkoutInProgressTitle(for: blankWorkout),
            "Workout Draft In Progress",
            "Blocked-workout titles should stay generic when the draft name is blank or corrupted"
        )
        XCTAssertEqual(
            viewModel.activeWorkoutInProgressTitle(for: legacyPlaceholderWorkout),
            "Workout Draft In Progress",
            "Blocked-workout titles should stay generic when older placeholder draft names resurface"
        )
        XCTAssertEqual(
            viewModel.activeWorkoutInProgressTitle(for: nil),
            "Workout In Progress",
            "Blocked-workout titles should stay generic when no resumable workout is currently available"
        )
    }

    func testResumableWorkoutSummary_templateDraftWithoutLoggedSetsShowsNotStartedYet() {
        let startDate = Date(timeIntervalSince1970: 0)
        let now = startDate.addingTimeInterval(15 * 60)
        let workout = Workout(date: startDate, name: "Upper A")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back])
        _ = workout.addSet(exercise: bench, weight: 185, reps: 8)
        _ = workout.addSet(exercise: row, weight: 135, reps: 10)
        workout.sets.forEach { $0.completedAt = .distantPast }

        let summary = viewModel.resumableWorkoutSummary(for: workout, now: now)

        XCTAssertEqual(summary, "Started 15m ago • 2 exercises • 2 sets • No exercises started yet", "Summary should distinguish planned template drafts from workouts with logged work")
    }

    func testResumableWorkoutSummary_warmupOnlyDraftPrefersTouchedCountsOverUntouchedPlaceholders() {
        let startDate = Date(timeIntervalSince1970: 0)
        let now = startDate.addingTimeInterval(10 * 60)
        let workout = Workout(date: startDate, name: "Upper A", startedFromTemplate: "Push Day")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back])

        _ = workout.addSet(exercise: bench, weight: 45, reps: 10, isWarmup: true)
        let rowSet = workout.addSet(exercise: row, weight: 135, reps: 8)
        rowSet.completedAt = .distantPast

        let summary = viewModel.resumableWorkoutSummary(for: workout, now: now)

        XCTAssertEqual(summary, "Started 10m ago • From Push Day • 1 exercise • 1 set • Warm-up sets only so far", "Warm-up-only draft summaries should prefer actually touched warm-up context instead of inflating counts with untouched planned placeholder work")
    }

    func testReplaceCurrentWorkoutAlertTitle_namesSpecificDraftWhenAvailable() {
        let workout = Workout(name: "  Upper   A  ")

        XCTAssertEqual(
            viewModel.replaceCurrentWorkoutAlertTitle(for: workout),
            "Replace “Upper A”?",
            "Start-fresh confirmation titles should name the exact draft being replaced when a clean name exists"
        )
    }

    func testReplaceCurrentWorkoutAlertTitle_fallsBackForGenericDraftName() {
        let workout = Workout(name: "   ")

        XCTAssertEqual(
            viewModel.replaceCurrentWorkoutAlertTitle(for: workout),
            "Replace This Workout?",
            "Start-fresh confirmation titles should keep unnamed or legacy drafts on the newer display-safe generic wording"
        )
    }

    func testSaveAndStartFreshButtonTitle_namesSpecificDraftWhenAvailable() {
        let workout = Workout(name: "  Upper   A  ")

        XCTAssertEqual(
            viewModel.saveAndStartFreshButtonTitle(for: workout),
            "Save “Upper A” & Start New Workout",
            "Save-and-start CTAs should name the exact draft so users know what will be preserved before the new workout begins"
        )
    }

    func testSaveAndStartFreshButtonTitle_fallsBackForGenericDraftName() {
        let workout = Workout(name: "   ")

        XCTAssertEqual(
            viewModel.saveAndStartFreshButtonTitle(for: workout),
            "Save This Workout & Start New Workout",
            "Save-and-start CTAs should keep unnamed or legacy drafts on the newer display-safe generic wording"
        )
    }

    func testDiscardAndStartFreshButtonTitle_namesSpecificDraftWhenAvailable() {
        let workout = Workout(name: "  Upper   A  ")

        XCTAssertEqual(
            viewModel.discardAndStartFreshButtonTitle(for: workout),
            "Discard “Upper A” & Start New Workout",
            "Discard-and-start CTAs should name the exact draft so destructive replacement stays explicit"
        )
    }

    func testDiscardAndStartFreshButtonTitle_fallsBackForGenericDraftName() {
        let workout = Workout(name: "   ")

        XCTAssertEqual(
            viewModel.discardAndStartFreshButtonTitle(for: workout),
            "Discard This Workout & Start New Workout",
            "Discard-and-start CTAs should keep unnamed or legacy drafts on the newer display-safe generic wording"
        )
    }

    func testDiscardCurrentWorkoutAndStartFreshAlertCopy_namesSpecificDraftAndImpact() {
        let startDate = Date(timeIntervalSince1970: 0)
        let now = startDate.addingTimeInterval(30 * 60)
        let workout = Workout(date: startDate, name: "  Upper   A  ")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        workout.addSet(exercise: bench, weight: 185, reps: 8)

        XCTAssertEqual(
            viewModel.discardCurrentWorkoutAndStartFreshAlertTitle(for: workout),
            "Discard “Upper A” & Start New Workout?",
            "The second destructive start-fresh confirmation should name the exact draft being discarded"
        )
        XCTAssertEqual(
            viewModel.discardCurrentWorkoutAndStartFreshAlertMessage(for: workout, now: now),
            "This will discard “Upper A” (Started 30m ago • 1 exercise • 1 set • Exercise started) and immediately start a new workout. This action cannot be undone.",
            "The second destructive start-fresh confirmation should summarize the live draft impact before it is discarded"
        )
    }

    func testDiscardCurrentWorkoutAndStartFreshAlertCopy_fallsBackForGenericDraftName() {
        let startDate = Date(timeIntervalSince1970: 0)
        let now = startDate.addingTimeInterval(10 * 60)
        let workout = Workout(date: startDate, name: "   ")

        XCTAssertEqual(
            viewModel.discardCurrentWorkoutAndStartFreshAlertTitle(for: workout),
            "Discard This Workout & Start New Workout?",
            "Blank legacy workout names should keep the destructive start-fresh confirmation on the newer display-safe generic wording"
        )
        XCTAssertEqual(
            viewModel.discardCurrentWorkoutAndStartFreshAlertMessage(for: workout, now: now),
            "This will discard your in-progress workout (Started 10m ago • No exercises added yet) and immediately start a new workout. This action cannot be undone.",
            "Blank legacy workout names should still explain the discard impact before starting fresh"
        )
    }

    func testStartFreshWorkoutMessage_includesWorkoutNameAndCurrentDraftSummary() {
        let startDate = Date(timeIntervalSince1970: 0)
        let now = startDate.addingTimeInterval(30 * 60)
        let workout = Workout(date: startDate, name: "Upper A")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        workout.addSet(exercise: bench, weight: 185, reps: 8)

        let message = viewModel.startFreshWorkoutMessage(for: workout, now: now)

        XCTAssertEqual(
            message,
            "You already have “Upper A” in progress: Started 30m ago • 1 exercise • 1 set • Exercise started. Continue it, save it for later, or discard it.",
            "Start-fresh guidance should lead with the safest recovery path while still reusing the resumable-workout summary so users know exactly what they are about to replace"
        )
    }

    func testStartFreshWorkoutMessage_blankWorkoutNameFallsBackToGenericDraftLabel() {
        let workout = Workout(date: Date(timeIntervalSince1970: 0), name: "   ")

        let message = viewModel.startFreshWorkoutMessage(for: workout, now: Date(timeIntervalSince1970: 10))

        XCTAssertEqual(
            message,
            "You already have a workout draft in progress: Started just now • No exercises added yet. Add an exercise to keep going, save it for later, or discard it.",
            "Start-fresh guidance should tell users how to recover from an empty draft even when the name is blank or corrupted"
        )
    }

    func testStartFreshWorkoutMessage_guidesEmptyNamedDraftToAddExerciseBeforeReplacingIt() {
        let workout = Workout(date: Date(timeIntervalSince1970: 0), name: "  Upper   A  ")

        let message = viewModel.startFreshWorkoutMessage(for: workout, now: Date(timeIntervalSince1970: 10))

        XCTAssertEqual(
            message,
            "You already have “Upper A” draft in progress: Started just now • No exercises added yet. Add an exercise to keep going, save it for later, or discard it.",
            "Start-fresh guidance should stop vaguely saying to keep going when the in-progress draft is still empty"
        )
    }

    func testResumableWorkoutProgressText_partialWorkoutShowsStartedExerciseCount() {
        let workout = Workout(name: "Push Day")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back])

        _ = workout.addSet(exercise: bench, weight: 185, reps: 8)
        _ = workout.addSet(exercise: row, weight: 135, reps: 10)
        workout.sets[1].completedAt = .distantPast

        let progress = viewModel.resumableWorkoutProgressText(for: workout)

        XCTAssertEqual(progress, "1 of 2 exercises started", "Progress text should show how much of a multi-exercise draft already has logged work")
    }

    func testResumableWorkoutProgressText_warmupOnlyWorkoutShowsWarmupSpecificMessage() {
        let workout = Workout(name: "Push Day")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back])

        _ = workout.addSet(exercise: bench, weight: 45, reps: 10, isWarmup: true)
        let rowSet = workout.addSet(exercise: row, weight: 135, reps: 10)
        rowSet.completedAt = .distantPast

        let progress = viewModel.resumableWorkoutProgressText(for: workout)

        XCTAssertEqual(progress, "Warm-up sets only so far", "Progress text should call out warm-up-only draft work instead of making it sound like real work sets are underway")
    }

    func testWorkoutStartedSummary_usesReadableAbsoluteDateForFutureDrafts() {
        var calendar = Calendar(identifier: .gregorian)
        let locale = Locale(identifier: "en_US_POSIX")
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone

        let now = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 5,
            day: 1,
            hour: 21,
            minute: 20
        ).date!
        let futureStart = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 5,
            day: 1,
            hour: 23,
            minute: 0
        ).date!

        let summary = viewModel.workoutStartedSummary(
            for: futureStart,
            now: now,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )

        XCTAssertEqual(summary, "Started May 1 • 11:00 PM", "Future or clock-skewed draft dates should stay readable without pretending the workout just started")
    }

    func testWorkoutStartedSummary_usesRelativeYesterdayLabelAcrossCalendarDayBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        let locale = Locale(identifier: "en_US_POSIX")
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone

        let now = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 5,
            day: 1,
            hour: 6,
            minute: 0
        ).date!
        let startDate = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 4,
            day: 30,
            hour: 23,
            minute: 0
        ).date!

        let summary = viewModel.workoutStartedSummary(
            for: startDate,
            now: now,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )

        XCTAssertEqual(summary, "Started Yesterday • 11:00 PM", "Draft summaries should use calendar-aware relative labels once the workout crosses into a prior day")
    }

    func testWorkoutStartedSummary_usesReadableDateForOlderDrafts() {
        var calendar = Calendar(identifier: .gregorian)
        let locale = Locale(identifier: "en_US_POSIX")
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone

        let now = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 5,
            day: 1,
            hour: 6,
            minute: 0
        ).date!
        let startDate = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 4,
            day: 25,
            hour: 9,
            minute: 15
        ).date!

        let summary = viewModel.workoutStartedSummary(
            for: startDate,
            now: now,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )

        XCTAssertEqual(summary, "Started Friday • 9:15 AM", "Older resumable drafts should show a readable relative date instead of a vague day count")
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

    func testStartNewWorkout_failureLeavesCurrentWorkoutNilAndSetsRetryMessage() {
        let failingManager = WorkoutManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext())
        )
        let failingViewModel = HomeViewModel(workoutManager: failingManager)

        let didStart = failingViewModel.startNewWorkout()

        XCTAssertFalse(didStart, "Failed workout creation should keep Home on the current screen instead of opening an unsaved draft")
        XCTAssertNil(failingViewModel.currentWorkout, "Failed workout creation should not hand the UI an unsaved workout instance")
        XCTAssertEqual(
            failingViewModel.startWorkoutFailureAlertTitle,
            "Couldn’t Start New Workout",
            "Failed workout creation should name the exact blocked action so the main Home retry alert stays clearly anchored"
        )
        XCTAssertEqual(
            failingViewModel.startWorkoutFailureMessage,
            "Your workout could not be started right now. Please try again.",
            "Failed workout creation should surface a retryable alert message"
        )
    }

    func testStartNewWorkoutFailureAlertTitle_matchesPrimaryHomeAction() {
        XCTAssertEqual(
            viewModel.startNewWorkoutFailureAlertTitle(),
            "Couldn’t Start New Workout",
            "The main Home workout-launch failure title should name the blocked action instead of falling back to a generic alert"
        )
    }

    func testStartNewWorkout_successClearsPriorFailureAndSetsCurrentWorkout() {
        viewModel.presentStartWorkoutFailure("Old error", title: "Couldn’t Delete “Upper A”")

        let didStart = viewModel.startNewWorkout()

        XCTAssertTrue(didStart, "Starting a workout should succeed in the normal shared data context")
        XCTAssertNotNil(viewModel.currentWorkout, "Successful workout creation should expose the new draft")
        XCTAssertNil(viewModel.startWorkoutFailureMessage, "Successful workout creation should clear stale failure alerts")
        XCTAssertEqual(viewModel.startWorkoutFailureAlertTitle, "Workout Action Failed", "Successful workout creation should reset the shared failure alert title")
    }

    func testCanStartFollowUpWorkout_requiresNoResumableDraftAndCompletedWorkingSet() {
        let completedWorkout = Workout(name: "Upper A", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = completedWorkout.addSet(exercise: bench, weight: 185, reps: 8)

        XCTAssertTrue(
            viewModel.canStartFollowUpWorkout(from: completedWorkout, activeWorkout: nil),
            "Recent completed workouts with real logged work should offer a direct follow-up action when no draft is already in progress"
        )

        let activeWorkout = Workout(name: "Current Draft")
        XCTAssertFalse(
            viewModel.canStartFollowUpWorkout(from: completedWorkout, activeWorkout: activeWorkout),
            "Follow-up shortcuts should stay hidden while another workout is already resumable"
        )
    }

    func testCanStartFollowUpWorkout_allowsBodyweightHistoryButRejectsWarmupOnlyWorkouts() {
        let bodyweightWorkout = Workout(name: "Pull Day", isCompleted: true)
        let pullUp = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])
        _ = bodyweightWorkout.addSet(exercise: pullUp, weight: 0, reps: 8)

        XCTAssertTrue(
            viewModel.canStartFollowUpWorkout(from: bodyweightWorkout, activeWorkout: nil),
            "Bodyweight history should still be repeatable even though the logged load is zero"
        )

        let warmupOnlyWorkout = Workout(name: "Warm-up Only", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = warmupOnlyWorkout.addSet(exercise: bench, weight: 45, reps: 12, isWarmup: true)

        XCTAssertFalse(
            viewModel.canStartFollowUpWorkout(from: warmupOnlyWorkout, activeWorkout: nil),
            "Warm-up-only history should not offer a follow-up shortcut because there is no real working-set progression to carry forward"
        )
    }

    func testStartFollowUpWorkout_failureSurfacesRetryMessage() {
        let failingManager = WorkoutManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext())
        )
        let failingViewModel = HomeViewModel(workoutManager: failingManager)
        let completedWorkout = Workout(name: "Upper A", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = completedWorkout.addSet(exercise: bench, weight: 185, reps: 8)

        let didStart = failingViewModel.startFollowUpWorkout(from: completedWorkout)

        XCTAssertFalse(didStart, "Failed follow-up creation should keep Home on the current screen instead of opening an unsaved draft")
        XCTAssertEqual(
            failingViewModel.startWorkoutFailureAlertTitle,
            "Couldn’t Start Follow-Up from “Upper A”",
            "Follow-up creation failures should name the exact saved workout so retry alerts stay clearly anchored"
        )
        XCTAssertEqual(
            failingViewModel.startWorkoutFailureMessage,
            "Couldn’t start a follow-up from “Upper A”. Keep it in history, then try again.",
            "Follow-up creation failures should explain that the saved workout stayed in history and invite a retry"
        )
    }

    func testStartFollowUpFailureAlertTitle_usesGenericFallbackForBlankWorkoutName() {
        let blankWorkout = Workout(name: "   ", isCompleted: true)

        XCTAssertEqual(
            viewModel.startFollowUpFailureAlertTitle(for: blankWorkout),
            "Couldn’t Start This Follow-Up",
            "Blank legacy workout names should fall back to a generic follow-up failure title instead of quoting a placeholder name"
        )
    }

    func testStartFollowUpFailureAlertTitle_usesGenericFallbackForLegacyCurrentWorkoutPlaceholder() {
        let placeholderWorkout = Workout(name: "Current Workout", isCompleted: true)

        XCTAssertEqual(
            viewModel.startFollowUpFailureAlertTitle(for: placeholderWorkout),
            "Couldn’t Start This Follow-Up",
            "Legacy placeholder workout names should stay on the generic follow-up failure title instead of surfacing awkward quoted placeholder copy"
        )
    }

    func testFollowUpWorkoutButtonTitle_usesNormalizedWorkoutName() {
        let workout = Workout(name: "  Upper   A  ", isCompleted: true)

        XCTAssertEqual(
            viewModel.followUpWorkoutButtonTitle(for: workout),
            "Start Follow-Up from “Upper A”",
            "Follow-up CTA copy should use the normalized saved workout name so detail and history actions stay readable"
        )
    }

    func testFollowUpWorkoutButtonTitle_usesGenericFallbackForBlankWorkoutName() {
        let workout = Workout(name: "   ", isCompleted: true)

        XCTAssertEqual(
            viewModel.followUpWorkoutButtonTitle(for: workout),
            "Start This Follow-Up",
            "Blank legacy workout names should keep follow-up CTAs generic instead of quoting a placeholder workout name"
        )
    }

    func testReviewWorkoutButtonTitle_usesNormalizedWorkoutName() {
        let workout = Workout(name: "  Upper   A  ", isCompleted: true)

        XCTAssertEqual(
            viewModel.reviewWorkoutButtonTitle(for: workout),
            "Review “Upper A”",
            "Review CTA copy should use the normalized saved workout name so stacked history cards stay easy to scan"
        )
    }

    func testReviewWorkoutButtonTitle_usesGenericFallbackForBlankWorkoutName() {
        let workout = Workout(name: "   ", isCompleted: true)

        XCTAssertEqual(
            viewModel.reviewWorkoutButtonTitle(for: workout),
            "Review Workout",
            "Blank legacy workout names should keep review CTAs generic instead of quoting a placeholder workout name"
        )
    }

    func testSaveAndStartFollowUpButtonTitle_usesNormalizedWorkoutName() {
        let workout = Workout(name: "  Upper   A  ", isCompleted: true)
        let currentWorkout = Workout(name: "  Push   Day  ")

        XCTAssertEqual(
            viewModel.saveAndStartFollowUpButtonTitle(for: workout, currentWorkout: currentWorkout),
            "Save “Push Day” & Start Follow-Up from “Upper A”",
            "Follow-up recovery CTA copy should name both the in-progress draft and saved workout so blocked restart choices stay unmistakable"
        )
    }

    func testSaveAndStartFollowUpButtonTitle_usesGenericFallbackForBlankWorkoutName() {
        let workout = Workout(name: "   ", isCompleted: true)

        XCTAssertEqual(
            viewModel.saveAndStartFollowUpButtonTitle(for: workout),
            "Save This Workout & Start This Follow-Up",
            "Blank legacy workout names should keep save-and-start follow-up CTAs generic without dropping the draft-saving context"
        )
    }

    func testDiscardAndStartFollowUpButtonTitle_usesNormalizedWorkoutName() {
        let workout = Workout(name: "  Upper   A  ", isCompleted: true)
        let currentWorkout = Workout(name: "  Push   Day  ")

        XCTAssertEqual(
            viewModel.discardAndStartFollowUpButtonTitle(for: workout, currentWorkout: currentWorkout),
            "Discard “Push Day” & Start Follow-Up from “Upper A”",
            "Destructive follow-up recovery CTA copy should name both the in-progress draft and saved workout so conflict-resolution choices stay unmistakable"
        )
    }

    func testDiscardAndStartFollowUpButtonTitle_usesGenericFallbackForBlankWorkoutName() {
        let workout = Workout(name: "   ", isCompleted: true)

        XCTAssertEqual(
            viewModel.discardAndStartFollowUpButtonTitle(for: workout),
            "Discard This Workout & Start This Follow-Up",
            "Blank legacy workout names should keep destructive follow-up CTAs generic without dropping the draft-discard context"
        )
    }

    func testCopySummaryButtonTitle_usesNormalizedWorkoutName() {
        let workout = Workout(name: "  Upper   A  ", isCompleted: true)

        XCTAssertEqual(
            viewModel.copySummaryButtonTitle(for: workout),
            "Copy Summary for “Upper A”",
            "Copy-summary CTA copy should use the normalized saved workout name so users know exactly which recap they are about to export"
        )
    }

    func testCopySummaryButtonTitle_usesGenericFallbackForBlankWorkoutName() {
        let workout = Workout(name: "   ", isCompleted: true)

        XCTAssertEqual(
            viewModel.copySummaryButtonTitle(for: workout),
            "Copy Workout Summary",
            "Blank legacy workout names should keep copy-summary CTAs generic instead of quoting a placeholder workout name"
        )
    }

    func testDeleteRecentWorkoutButtonTitle_usesNormalizedWorkoutName() {
        let workout = Workout(name: "  Upper   A  ", isCompleted: true)

        XCTAssertEqual(
            viewModel.deleteRecentWorkoutButtonTitle(for: workout),
            "Delete “Upper A” from History",
            "Delete CTA copy should use the normalized saved workout name so destructive history cleanup stays unmistakable"
        )
    }

    func testDeleteRecentWorkoutButtonTitle_usesGenericFallbackForBlankWorkoutName() {
        let workout = Workout(name: "   ", isCompleted: true)

        XCTAssertEqual(
            viewModel.deleteRecentWorkoutButtonTitle(for: workout),
            "Delete Workout from History",
            "Blank legacy workout names should keep delete CTAs generic instead of quoting a placeholder workout name"
        )
    }

    func testDeleteRecentWorkoutConfirmationButtonTitle_usesNormalizedWorkoutName() {
        let workout = Workout(name: "  Upper   A  ", isCompleted: true)

        XCTAssertEqual(
            viewModel.deleteRecentWorkoutConfirmationButtonTitle(for: workout),
            "Delete “Upper A”",
            "Delete confirmation CTA copy should name the exact saved workout so final destructive choices stay unmistakable"
        )
    }

    func testDeleteRecentWorkoutConfirmationButtonTitle_usesGenericFallbackForBlankWorkoutName() {
        let workout = Workout(name: "   ", isCompleted: true)

        XCTAssertEqual(
            viewModel.deleteRecentWorkoutConfirmationButtonTitle(for: workout),
            "Delete This Workout",
            "Blank legacy workout names should keep destructive confirmation CTAs generic instead of quoting a placeholder workout name"
        )
    }

    func testDeleteRecentWorkoutAlertTitle_usesNormalizedWorkoutName() {
        let workout = Workout(name: "  Upper   A  ", isCompleted: true)

        XCTAssertEqual(
            viewModel.deleteRecentWorkoutAlertTitle(for: workout),
            "Delete “Upper A”?",
            "Delete alert titles should name the exact saved workout so Workout Details confirmations stay unmistakable"
        )
    }

    func testDeleteRecentWorkoutAlertTitle_usesGenericFallbackForBlankWorkoutName() {
        let workout = Workout(name: "   ", isCompleted: true)

        XCTAssertEqual(
            viewModel.deleteRecentWorkoutAlertTitle(for: workout),
            "Delete This Workout?",
            "Blank legacy workout names should keep destructive alert titles generic instead of quoting a placeholder workout name"
        )
    }

    func testDeleteRecentWorkoutMessage_usesGenericFallbackForBlankWorkoutName() {
        let workout = Workout(name: "   ", isCompleted: true)

        XCTAssertEqual(
            viewModel.deleteRecentWorkoutMessage(for: workout, now: workout.date),
            "Delete this workout from history? Today • No sets logged will be removed from your saved workout history.",
            "Blank legacy workout names should keep delete confirmation copy generic instead of pretending the placeholder workout name is meaningful"
        )
    }

    func testFollowUpWorkoutHelperText_describesPrefilledDraftBenefit() {
        let workout = Workout(name: "Push Day", isCompleted: true)

        XCTAssertEqual(
            viewModel.followUpWorkoutHelperText(for: workout),
            "Create a new draft with your last working-set weights prefilled so you can keep progressing without rebuilding the session.",
            "Follow-up helper copy should explain the progression benefit instead of exposing implementation details"
        )
    }

    func testShouldOfferFollowUpRecovery_matchesUnderlyingFollowUpContent() {
        let completedWorkout = Workout(name: "Upper A", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = completedWorkout.addSet(exercise: bench, weight: 185, reps: 8)

        XCTAssertTrue(
            viewModel.shouldOfferFollowUpRecovery(for: completedWorkout),
            "Completed workouts with real logged work should still advertise follow-up recovery actions even when another draft is already open"
        )

        let warmupOnlyWorkout = Workout(name: "Warm-up Only", isCompleted: true)
        _ = warmupOnlyWorkout.addSet(exercise: bench, weight: 45, reps: 12, isWarmup: true)

        XCTAssertFalse(
            viewModel.shouldOfferFollowUpRecovery(for: warmupOnlyWorkout),
            "Warm-up-only history should not show save/discard follow-up recovery actions because there is no progression to carry forward"
        )
    }

    func testActiveWorkoutBlocksFollowUpMessage_namesSavedWorkoutAndCurrentDraft() {
        let activeWorkout = Workout(name: "  Current   Draft  ")
        let completedWorkout = Workout(name: "  Upper   A  ", isCompleted: true)

        let message = viewModel.activeWorkoutBlocksFollowUpMessage(
            for: activeWorkout,
            startingFrom: completedWorkout,
            now: activeWorkout.date.addingTimeInterval(60)
        )

        XCTAssertEqual(
            message,
            "You already have a workout in progress: Started just now • Workout. Continue it, save it for later, or discard it before starting a follow-up from “Upper A”.",
            "Blocked follow-up copy should keep placeholder draft names generic while still explaining the exact saved workout the follow-up would come from"
        )
    }

    func testActiveWorkoutBlocksFollowUpMessage_usesGenericFallbackForLegacyCurrentWorkoutPlaceholder() {
        let activeWorkout = Workout(name: "  Current   Draft  ")
        let placeholderWorkout = Workout(name: "Current Workout", isCompleted: true)

        let message = viewModel.activeWorkoutBlocksFollowUpMessage(
            for: activeWorkout,
            startingFrom: placeholderWorkout,
            now: activeWorkout.date.addingTimeInterval(60)
        )

        XCTAssertEqual(
            message,
            "You already have a workout in progress: Started just now • Workout. Continue it, save it for later, or discard it before starting this follow-up.",
            "Legacy placeholder names on either the active draft or source workout should keep blocked follow-up guidance generic instead of surfacing placeholder copy as if it were user-chosen"
        )
    }

    func testActiveWorkoutBlocksFollowUpMessage_guidesEmptyDraftToAddExerciseBeforeStartingFollowUp() {
        let activeWorkout = Workout(name: "Push Day")
        let completedWorkout = Workout(name: "Upper A", isCompleted: true)

        let message = viewModel.activeWorkoutBlocksFollowUpMessage(
            for: activeWorkout,
            startingFrom: completedWorkout,
            now: activeWorkout.date.addingTimeInterval(60)
        )

        XCTAssertEqual(
            message,
            "You already have “Push Day” draft in progress: Started just now • No exercises added yet. Add an exercise to keep going, save it for later, or discard it before starting a follow-up from “Upper A”.",
            "Blocked follow-up guidance should name real active drafts so users can tell which workout would be interrupted before starting a follow-up"
        )
    }

    func testActiveWorkoutBlocksFollowUpMessage_namesSpecificActiveDraftWhenItExists() {
        let activeWorkout = Workout(name: "Push Day")
        let completedWorkout = Workout(name: "Upper A", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = activeWorkout.addSet(exercise: bench, weight: 185, reps: 8)

        let message = viewModel.activeWorkoutBlocksFollowUpMessage(
            for: activeWorkout,
            startingFrom: completedWorkout,
            now: activeWorkout.date.addingTimeInterval(60)
        )

        XCTAssertEqual(
            message,
            "You already have “Push Day” in progress: Started just now • 1 exercise • 1 set • Exercise started. Continue it, save it for later, or discard it before starting a follow-up from “Upper A”.",
            "Blocked follow-up guidance should name the active draft when it has a real title so users can recognize which session is in the way"
        )
    }

    func testActiveWorkoutBlocksFollowUpMessage_guidesUntouchedPlannedDraftToOpenBeforeStartingFollowUp() {
        let activeWorkout = Workout(name: "Push Day")
        let completedWorkout = Workout(name: "Upper A", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let set = activeWorkout.addSet(exercise: bench, weight: 185, reps: 8)
        set.completedAt = .distantPast

        let message = viewModel.activeWorkoutBlocksFollowUpMessage(
            for: activeWorkout,
            startingFrom: completedWorkout,
            now: activeWorkout.date.addingTimeInterval(60)
        )

        XCTAssertEqual(
            message,
            "You already have “Push Day” in progress: Started just now • 1 exercise • 1 set • Exercise not started yet. Open it, save it for later, or discard it before starting a follow-up from “Upper A”.",
            "Blocked follow-up guidance should treat untouched planned drafts as something to reopen, not continue, until the user has logged work"
        )
    }

    func testActiveWorkoutPersistenceFailureMessage_matchesActionAndWorkoutName() {
        let completedWorkout = Workout(name: "  Upper   A  ", isCompleted: true)
        let activeWorkout = Workout(name: "  Push   Day  ")

        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureMessage(
                for: .saveForLater,
                currentWorkout: activeWorkout,
                startingFollowUpFrom: completedWorkout
            ),
            "Couldn’t save “Push Day”. Keep it open, then try starting a follow-up from “Upper A” again.",
            "Save-for-later failures should keep the exact in-progress draft visible in retry guidance when follow-up start is blocked"
        )
        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureMessage(
                for: .discard,
                currentWorkout: activeWorkout,
                startingFollowUpFrom: completedWorkout
            ),
            "Couldn’t discard “Push Day”. Keep it open, then try starting a follow-up from “Upper A” again.",
            "Discard failures should keep the exact in-progress draft visible in retry guidance when follow-up start is blocked"
        )
        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureAlertTitle(for: .saveForLater, startingFollowUpFrom: completedWorkout),
            "Couldn’t Save & Start Follow-Up from “Upper A”",
            "Save-for-later follow-up failures should name the exact saved workout in the alert title so recovery stays clearly anchored"
        )
        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureAlertTitle(for: .discard, startingFollowUpFrom: completedWorkout),
            "Couldn’t Discard & Start Follow-Up from “Upper A”",
            "Discard follow-up failures should name the exact saved workout in the alert title so destructive recovery stays clearly anchored"
        )
    }

    func testActiveWorkoutPersistenceFailureMessages_useGenericFallbackForBlankWorkoutName() {
        let blankWorkout = Workout(name: "   ", isCompleted: true)

        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureMessage(for: .saveForLater, startingFollowUpFrom: blankWorkout),
            "Couldn’t save this workout. Keep it open, then try starting this follow-up again.",
            "Blank legacy workout names should keep save-for-later retry copy generic instead of leaking a placeholder workout name"
        )
        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureMessage(for: .discard, startingFollowUpFrom: blankWorkout),
            "Couldn’t discard this workout. Keep it open, then try starting this follow-up again.",
            "Blank legacy workout names should keep discard retry copy generic instead of leaking a placeholder workout name"
        )
    }

    func testActiveWorkoutPersistenceFailureAlertTitle_usesGenericFallbackForBlankWorkoutName() {
        let blankWorkout = Workout(name: "   ", isCompleted: true)

        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureAlertTitle(for: .saveForLater, startingFollowUpFrom: blankWorkout),
            "Couldn’t Save & Start This Follow-Up",
            "Blank legacy workout names should fall back to a generic save-and-start failure title instead of quoting a placeholder name"
        )
        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureAlertTitle(for: .discard, startingFollowUpFrom: blankWorkout),
            "Couldn’t Discard & Start This Follow-Up",
            "Blank legacy workout names should fall back to a generic discard-and-start failure title instead of quoting a placeholder name"
        )
    }

    func testActiveWorkoutPersistenceFailureAlertTitle_usesGenericFallbackForLegacyCurrentWorkoutPlaceholder() {
        let placeholderWorkout = Workout(name: "Current Workout", isCompleted: true)

        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureAlertTitle(for: .saveForLater, startingFollowUpFrom: placeholderWorkout),
            "Couldn’t Save & Start This Follow-Up",
            "Legacy placeholder workout names should keep save-and-start follow-up failures generic instead of surfacing quoted placeholder copy"
        )
        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureAlertTitle(for: .discard, startingFollowUpFrom: placeholderWorkout),
            "Couldn’t Discard & Start This Follow-Up",
            "Legacy placeholder workout names should keep discard-and-start follow-up failures generic instead of surfacing quoted placeholder copy"
        )
    }

    func testStartTemplateFailureAlertTitle_usesNormalizedTemplateName() {
        let template = WorkoutTemplate(name: "  Upper   A  ")

        XCTAssertEqual(
            viewModel.startTemplateFailureAlertTitle(for: template),
            "Couldn’t Start Template “Upper A”",
            "Template start failures launched from workout history should name the exact routine so retry alerts stay clearly anchored"
        )
    }

    func testStartTemplateFailureAlertTitle_usesGenericFallbackForBlankTemplateName() {
        let template = WorkoutTemplate(name: "   ")

        XCTAssertEqual(
            viewModel.startTemplateFailureAlertTitle(for: template),
            "Couldn’t Start This Template",
            "Blank legacy template names should fall back to a generic start-failure title instead of quoting a placeholder name"
        )
    }

    func testStartTemplateFailureAlertTitle_usesPartialTemplateCopyWhenTemplateNeedsIt() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = WorkoutTemplate(
            name: "  Upper   A  ",
            exercises: [
                TemplateExercise(exerciseName: "Bench Press", suggestedSets: 3, repRanges: []),
                TemplateExercise(exerciseName: "Incline Dumbbell Press", suggestedSets: 3, repRanges: [])
            ]
        )

        XCTAssertEqual(
            viewModel.startTemplateFailureAlertTitle(for: template),
            "Couldn’t Start Partial Template “Upper A”",
            "Home source-template start failures should stay aligned with partial-template CTAs when missing exercises mean only part of a saved plan can restart"
        )
    }

    func testSourceTemplateQuickActionTitle_usesNormalizedTemplateName() {
        let workout = Workout(name: "Push Day", isCompleted: true, startedFromTemplate: "  Upper   A  ")

        XCTAssertEqual(
            viewModel.sourceTemplateQuickActionTitle(for: workout),
            "Start Template “Upper A”",
            "Template quick action copy should normalize the remembered source template name so Home shortcuts stay readable"
        )
    }

    func testSourceTemplateQuickActionTitle_prefersResolvedTemplateNameWhenAvailable() {
        let workout = Workout(name: "Push Day", isCompleted: true, startedFromTemplate: "Old Upper A")

        XCTAssertEqual(
            viewModel.sourceTemplateQuickActionTitle(for: workout, resolvedTemplateName: "  Renamed   Upper A  "),
            "Start Template “Renamed Upper A”",
            "Home template shortcuts should use the current template name when a stable-ID lookup resolves a renamed source template"
        )
    }

    func testSourceTemplateQuickActionTitle_usesPartialTemplateCopyWhenResolvedTemplateNeedsIt() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let workout = Workout(name: "Push Day", isCompleted: true, startedFromTemplate: "Old Upper A")
        let resolvedTemplate = WorkoutTemplate(
            name: "  Renamed   Upper A  ",
            exercises: [
                TemplateExercise(exerciseName: "Bench Press", suggestedSets: 3, repRanges: []),
                TemplateExercise(exerciseName: "Incline Dumbbell Press", suggestedSets: 3, repRanges: [])
            ]
        )

        XCTAssertEqual(
            viewModel.sourceTemplateQuickActionTitle(
                for: workout,
                resolvedTemplateName: resolvedTemplate.name,
                resolvedTemplate: resolvedTemplate
            ),
            "Start Partial Template “Renamed Upper A”",
            "Home source-template shortcuts should reuse partial-template wording when the resolved plan will skip unavailable exercises"
        )
    }

    func testSourceTemplateQuickActionTitle_usesGenericFallbackForPlaceholderTemplateName() {
        let workout = Workout(name: "Push Day", isCompleted: true, startedFromTemplate: "Template")

        XCTAssertEqual(
            viewModel.sourceTemplateQuickActionTitle(for: workout),
            "Start This Template",
            "Placeholder legacy template names should fall back to the same generic start-template copy used elsewhere in the app"
        )
    }

    func testSourceTemplateQuickActionTitle_returnsNilWithoutUsableTemplateName() {
        let emptyTemplateWorkout = Workout(name: "Push Day", isCompleted: true, startedFromTemplate: "   ")
        let noTemplateWorkout = Workout(name: "Push Day", isCompleted: true)

        XCTAssertNil(
            viewModel.sourceTemplateQuickActionTitle(for: emptyTemplateWorkout),
            "Blank source-template names should not create a broken Home shortcut title"
        )
        XCTAssertNil(
            viewModel.sourceTemplateQuickActionTitle(for: noTemplateWorkout),
            "Missing source-template names should not create a Home shortcut title"
        )
    }

    func testStartFollowUpWorkout_successCreatesNewDraftAndClearsStaleFailure() {
        viewModel.presentStartWorkoutFailure("Old error", title: "Couldn’t Delete “Upper A”")
        let completedWorkout = Workout(name: "Upper A", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = completedWorkout.addSet(exercise: bench, weight: 185, reps: 8)

        let didStart = viewModel.startFollowUpWorkout(from: completedWorkout)

        XCTAssertTrue(didStart, "Starting a follow-up from recent history should succeed in the normal shared data context")
        XCTAssertEqual(viewModel.currentWorkout?.name, "Follow-up: Upper A")
        XCTAssertFalse(viewModel.currentWorkout?.isCompleted ?? true, "Follow-up drafts should open as incomplete workouts")
        XCTAssertEqual(viewModel.currentWorkout?.sets.first?.completedAt, .distantPast, "Follow-up sets should stay planned until the user actually logs them")
        XCTAssertNil(viewModel.startWorkoutFailureMessage, "Successful follow-up creation should clear stale failure alerts")
        XCTAssertEqual(viewModel.startWorkoutFailureAlertTitle, "Workout Action Failed", "Successful follow-up creation should reset the shared failure alert title")
    }

    func testStartFollowUpAfterPersistingActiveWorkout_saveForLaterFailureReturnsRetryMessage() {
        let activeWorkout = Workout(name: "Current Draft")
        let completedWorkout = Workout(name: "Upper A", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = completedWorkout.addSet(exercise: bench, weight: 185, reps: 8)

        let result = viewModel.startFollowUpAfterPersistingActiveWorkout(
            activeWorkout,
            action: .saveForLater,
            from: completedWorkout,
            persist: { _ in false }
        )

        switch result {
        case .success:
            XCTFail("Failed save-for-later should not start a follow-up workout")
        case .failure(let message):
            XCTAssertEqual(
                message,
                "Couldn’t save this workout. Keep it open, then try starting a follow-up from “Upper A” again.",
                "Blocked follow-up recovery should keep placeholder draft names generic when persistence fails before a follow-up starts"
            )
        }
    }

    func testStartFollowUpFailureMessage_namesExactSavedWorkout() {
        let workout = Workout(name: "  Upper   A  ", isCompleted: true)

        XCTAssertEqual(
            viewModel.startFollowUpFailureMessage(for: workout),
            "Couldn’t start a follow-up from “Upper A”. Keep it in history, then try again.",
            "Named follow-up start failures should keep the saved workout clearly quoted in retry copy"
        )
    }

    func testStartFollowUpFailureMessage_usesGenericFallbackForBlankWorkoutName() {
        let workout = Workout(name: "   ", isCompleted: true)

        XCTAssertEqual(
            viewModel.startFollowUpFailureMessage(for: workout),
            "Couldn’t start this follow-up. Keep this workout in history, then try again.",
            "Blank legacy workout names should keep follow-up start failures generic instead of leaking a placeholder source name"
        )
    }

    func testStartFollowUpFailureMessage_usesGenericFallbackForLegacyCurrentWorkoutPlaceholder() {
        let workout = Workout(name: "Current Workout", isCompleted: true)

        XCTAssertEqual(
            viewModel.startFollowUpFailureMessage(for: workout),
            "Couldn’t start this follow-up. Keep this workout in history, then try again.",
            "Legacy placeholder workout names should keep follow-up start failures generic instead of surfacing quoted placeholder source copy"
        )
    }

    func testStartFollowUpAfterPersistingActiveWorkout_successStartsNewDraft() {
        let activeWorkout = Workout(name: "Current Draft")
        let completedWorkout = Workout(name: "Upper A", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = completedWorkout.addSet(exercise: bench, weight: 185, reps: 8)

        let result = viewModel.startFollowUpAfterPersistingActiveWorkout(
            activeWorkout,
            action: .saveForLater,
            from: completedWorkout,
            persist: { _ in true }
        )

        switch result {
        case .success(let startedWorkout):
            XCTAssertEqual(startedWorkout.name, "Follow-up: Upper A")
            XCTAssertTrue(viewModel.currentWorkout === startedWorkout, "Successful follow-up recovery should update Home state to the new follow-up draft")
        case .failure(let message):
            XCTFail("Expected a follow-up workout after saving the current draft, got failure: \(message)")
        }
    }

    func testPersistWorkoutForFreshStart_saveForLaterFailureDoesNotClearDiscardState() {
        WorkoutStateManager.shared.markWorkoutAsDiscarded("older-draft")
        let workout = Workout(name: "Current Draft")

        let result = viewModel.persistWorkoutForFreshStart(
            workout,
            action: .saveForLater,
            persist: { _ in false }
        )

        XCTAssertFalse(result, "Failed save-for-later should keep the current workout in place")
        XCTAssertTrue(WorkoutStateManager.shared.wasAnyWorkoutDiscarded(), "Failed save-for-later should not clear discard state or pretend the workout was saved")
    }

    func testPersistWorkoutForFreshStart_discardFailureDoesNotMarkWorkoutDiscarded() {
        WorkoutStateManager.shared.clearDiscardedState()
        let workout = Workout(name: "Current Draft")

        let result = viewModel.persistWorkoutForFreshStart(
            workout,
            action: .discard,
            persist: { _ in false }
        )

        XCTAssertFalse(result, "Failed discard should keep the current workout in place")
        XCTAssertFalse(WorkoutStateManager.shared.wasAnyWorkoutDiscarded(), "Failed discard should not mark the workout as discarded")
    }

    func testPersistWorkoutForFreshStart_discardSuccessMarksWorkoutDiscarded() {
        WorkoutStateManager.shared.clearDiscardedState()
        let workout = Workout(name: "Current Draft")

        let result = viewModel.persistWorkoutForFreshStart(
            workout,
            action: .discard,
            persist: { _ in true }
        )

        XCTAssertTrue(result, "Successful discard should allow the fresh-start flow to continue")
        XCTAssertTrue(WorkoutStateManager.shared.wasAnyWorkoutDiscarded(), "Successful discard should mark discard state so the old workout does not immediately resurface")
    }

    func testStartFreshFailureAlertTitle_matchesAction() {
        XCTAssertEqual(
            viewModel.startFreshFailureAlertTitle(for: .saveForLater),
            "Couldn’t Save & Start New Workout",
            "Save-for-later failures should keep the replacement action explicit in the alert title"
        )
        XCTAssertEqual(
            viewModel.startFreshFailureAlertTitle(for: .discard),
            "Couldn’t Discard & Start New Workout",
            "Discard failures should keep the replacement action explicit in the alert title"
        )
    }

    func testStartFreshFailureAlertTitle_namesSpecificCurrentWorkout() {
        let workout = Workout(name: "Upper A")

        XCTAssertEqual(
            viewModel.startFreshFailureAlertTitle(for: .saveForLater, currentWorkout: workout),
            "Couldn’t Save & Start “Upper A”",
            "Save-for-later failures should name the exact in-progress workout when available"
        )
        XCTAssertEqual(
            viewModel.startFreshFailureAlertTitle(for: .discard, currentWorkout: workout),
            "Couldn’t Discard & Start “Upper A”",
            "Discard failures should name the exact in-progress workout when available"
        )
    }

    func testStartFreshFailureMessage_matchesAction() {
        XCTAssertEqual(
            viewModel.startFreshFailureMessage(for: .saveForLater),
            "Couldn’t save this workout. Keep this draft open, then try again.",
            "Save-for-later failures should explain that the current draft stayed open"
        )
        XCTAssertEqual(
            viewModel.startFreshFailureMessage(for: .discard),
            "Couldn’t discard this workout. Keep this draft open, then try again.",
            "Discard failures should explain that the current draft stayed open"
        )
    }

    func testStartFreshFailureMessage_namesSpecificCurrentWorkout() {
        let workout = Workout(name: "Upper A")

        XCTAssertEqual(
            viewModel.startFreshFailureMessage(for: .saveForLater, currentWorkout: workout),
            "Couldn’t save “Upper A”. Keep this draft open, then try again.",
            "Save-for-later failures should keep the named draft visible in the recovery message"
        )
        XCTAssertEqual(
            viewModel.startFreshFailureMessage(for: .discard, currentWorkout: workout),
            "Couldn’t discard “Upper A”. Keep this draft open, then try again.",
            "Discard failures should keep the named draft visible in the recovery message"
        )
    }
}
