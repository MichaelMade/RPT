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
        XCTAssertEqual(settingsManager.formatWeight(-45), "0 lb", "Negative integer weight should clamp to zero")
        XCTAssertEqual(settingsManager.formatWeight(225, useUnit: false), "225", "Integer weight without unit should format correctly")
        
        // Test double weight formatting
        XCTAssertEqual(settingsManager.formatWeight(135.0), "135.0 lb", "Double weight should format correctly")
        XCTAssertEqual(settingsManager.formatWeight(135.5), "135.5 lb", "Double weight with decimal should format correctly")
        XCTAssertEqual(settingsManager.formatWeight(-2.5), "0.0 lb", "Negative double weight should clamp to zero")
        XCTAssertEqual(settingsManager.formatWeight(.infinity), "0.0 lb", "Non-finite double weight should fail safe to zero")
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

    func testRPTCalculationExample_topSetOnlyFallback() {
        let settingsManager = SettingsManager.shared

        // Save current settings to restore later
        let originalDrops = settingsManager.settings.defaultRPTPercentageDrops

        // No back-off sets configured
        _ = settingsManager.updateRPTPercentageDropsSafely(drops: [0.0])

        let example = settingsManager.calculateRPTExample(firstSetWeight: 200)
        XCTAssertEqual(example, "Top set only", "RPT calculation example should provide a helpful fallback when no back-off sets are configured")

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

    func testWorkoutDetailSetDisplayText_usesBodyweightAwareFormatting() {
        let bodyweightExercise = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])
        let weightedExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let workout = Workout(name: "Test")

        let loggedBodyweightSet = ExerciseSet(
            weight: 0,
            reps: 12,
            exercise: bodyweightExercise,
            workout: workout,
            completedAt: Date()
        )
        let loggedWeightedSet = ExerciseSet(
            weight: 185,
            reps: 8,
            exercise: weightedExercise,
            workout: workout,
            completedAt: Date()
        )
        let plannedWeightedSet = ExerciseSet(
            weight: 185,
            reps: 8,
            exercise: weightedExercise,
            workout: workout,
            completedAt: .distantPast
        )
        let unloggedWarmupSet = ExerciseSet(
            weight: 95,
            reps: 5,
            exercise: weightedExercise,
            workout: workout,
            completedAt: .distantPast,
            isWarmup: true
        )
        let blankPlaceholderSet = ExerciseSet(
            weight: 0,
            reps: 0,
            exercise: weightedExercise,
            workout: workout,
            completedAt: .distantPast
        )

        XCTAssertEqual(ExerciseSection.setDisplayText(for: loggedBodyweightSet), "BW × 12 reps")
        XCTAssertEqual(ExerciseSection.setDisplayText(for: loggedWeightedSet), "185 lb × 8 reps")
        XCTAssertEqual(ExerciseSection.setDisplayText(for: plannedWeightedSet), "Planned • 185 lb × 8 reps")
        XCTAssertEqual(ExerciseSection.setDisplayText(for: unloggedWarmupSet), "Warm-up • 95 lb × 5 reps")
        XCTAssertEqual(ExerciseSection.setDisplayText(for: blankPlaceholderSet), "Not logged")
    }

    func testExerciseSetRowDisplayWeightText_usesBodyweightLabelForZeroWeightBodyweightSets() {
        XCTAssertEqual(
            ExerciseSetRowView.displayWeightText(weight: 0, exerciseCategory: .bodyweight),
            "BW"
        )
        XCTAssertEqual(
            ExerciseSetRowView.displayWeightText(weight: 45, exerciseCategory: .bodyweight),
            "45 lb"
        )
        XCTAssertEqual(
            ExerciseSetRowView.displayWeightText(weight: 0, exerciseCategory: .compound),
            "0 lb"
        )
    }

    func testExerciseSetRowDisplayRepsText_handlesSingularAndPlural() {
        XCTAssertEqual(ExerciseSetRowView.displayRepsText(1), "1 rep")
        XCTAssertEqual(ExerciseSetRowView.displayRepsText(8), "8 reps")
    }

    func testExerciseSetDisplayRPE_hidesInvalidLegacyValues() {
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let workout = Workout(name: "Push")

        let validSet = ExerciseSet(weight: 185, reps: 8, exercise: exercise, workout: workout, rpe: 8)
        let zeroRPE = ExerciseSet(weight: 185, reps: 8, exercise: exercise, workout: workout, rpe: 0)
        let oversizedRPE = ExerciseSet(weight: 185, reps: 8, exercise: exercise, workout: workout, rpe: 12)

        XCTAssertEqual(validSet.displayRPE, 8)
        XCTAssertNil(zeroRPE.displayRPE)
        XCTAssertNil(oversizedRPE.displayRPE)
    }

    func testWorkoutRowDisplayName_fallsBackForBlankAndNormalizesWhitespace() {
        let blankNameWorkout = Workout(name: "   \n   ")
        XCTAssertEqual(WorkoutRow.displayName(for: blankNameWorkout), "Workout")

        let spacedNameWorkout = Workout(name: "  Upper   Body\nSession  ")
        XCTAssertEqual(WorkoutRow.displayName(for: spacedNameWorkout), "Upper Body Session")
    }

    func testWorkoutRowDisplayName_clampsVeryLongNames() {
        let longName = String(repeating: "A", count: 120)
        let workout = Workout(name: longName)

        XCTAssertEqual(WorkoutRow.displayName(for: workout).count, 80)
    }

    func testWorkoutRowTemplateOriginText_normalizesWhitespaceAndHidesBlankValues() {
        let templatedWorkout = Workout(name: "Push", startedFromTemplate: "  Upper  Body\nA  ")
        XCTAssertEqual(WorkoutRow.templateOriginText(for: templatedWorkout), "Template • Upper Body A")

        let blankTemplateWorkout = Workout(name: "Push", startedFromTemplate: "   \n  ")
        XCTAssertNil(WorkoutRow.templateOriginText(for: blankTemplateWorkout))
    }

    func testWorkoutRowRelativeDateText_formatsTodayWithTime() {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone
        let locale = Locale(identifier: "en_US_POSIX")
        let now = Date(timeIntervalSince1970: 1_714_392_000) // Apr 29, 2024 12:00 UTC
        let date = Date(timeIntervalSince1970: 1_714_383_900) // Apr 29, 2024 09:45 UTC

        XCTAssertEqual(
            WorkoutRow.relativeDateText(for: date, now: now, calendar: calendar, locale: locale, timeZone: timeZone),
            "Today • 9:45 AM"
        )
    }

    func testWorkoutRowRelativeDateText_formatsYesterdayWithTime() {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone
        let locale = Locale(identifier: "en_US_POSIX")
        let now = Date(timeIntervalSince1970: 1_714_392_000) // Apr 29, 2024 12:00 UTC
        let date = Date(timeIntervalSince1970: 1_714_294_800) // Apr 28, 2024 08:00 UTC

        XCTAssertEqual(
            WorkoutRow.relativeDateText(for: date, now: now, calendar: calendar, locale: locale, timeZone: timeZone),
            "Yesterday • 8:00 AM"
        )
    }

    func testWorkoutRowRelativeDateText_usesInjectedNowInsteadOfSystemTodayForRelativeLabels() {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone
        let locale = Locale(identifier: "en_US_POSIX")
        let now = Date(timeIntervalSince1970: 1_714_392_000) // Apr 29, 2024 12:00 UTC
        let date = Date(timeIntervalSince1970: 1_714_124_500) // Apr 26, 2024 05:15 AM UTC

        XCTAssertEqual(
            WorkoutRow.relativeDateText(for: date, now: now, calendar: calendar, locale: locale, timeZone: timeZone),
            "Friday • 5:15 AM",
            "Relative labels should be derived from the supplied reference date, not the device's current day"
        )
    }

    func testWorkoutRowRelativeDateText_doesNotMarkFutureDatesAsToday() {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone
        let locale = Locale(identifier: "en_US_POSIX")
        let now = Date(timeIntervalSince1970: 1_714_392_000) // Apr 29, 2024 12:00 UTC
        let sameDayFutureDate = Date(timeIntervalSince1970: 1_714_431_600) // Apr 29, 2024 11:00 PM UTC
        let nextDayFutureDate = Date(timeIntervalSince1970: 1_714_474_800) // Apr 30, 2024 11:00 AM UTC

        XCTAssertEqual(
            WorkoutRow.relativeDateText(for: sameDayFutureDate, now: now, calendar: calendar, locale: locale, timeZone: timeZone),
            "Apr 29 • 11:00 PM",
            "Future timestamps later the same day should use absolute calendar formatting instead of relative Today labels"
        )
        XCTAssertEqual(
            WorkoutRow.relativeDateText(for: nextDayFutureDate, now: now, calendar: calendar, locale: locale, timeZone: timeZone),
            "Apr 30 • 11:00 AM",
            "Future dates should fall back to absolute calendar formatting instead of using Today/Yesterday labels"
        )
    }

    func testWorkoutRowRelativeDateText_formatsRecentWeekdayWithTime() {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone
        let locale = Locale(identifier: "en_US_POSIX")
        let now = Date(timeIntervalSince1970: 1_714_392_000) // Apr 29, 2024 12:00 UTC
        let date = Date(timeIntervalSince1970: 1_714_118_200) // Apr 26, 2024 03:50 UTC

        XCTAssertEqual(
            WorkoutRow.relativeDateText(for: date, now: now, calendar: calendar, locale: locale, timeZone: timeZone),
            "Friday • 3:50 AM"
        )
    }

    func testWorkoutRowRelativeDateText_formatsOlderDatesWithMonthDayAndYearFallback() {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone
        let locale = Locale(identifier: "en_US_POSIX")
        let now = Date(timeIntervalSince1970: 1_714_392_000) // Apr 29, 2024 12:00 UTC
        let sameYearDate = Date(timeIntervalSince1970: 1_709_651_400) // Mar 5, 2024 03:30 UTC
        let priorYearDate = Date(timeIntervalSince1970: 1_672_491_900) // Dec 31, 2022 11:45 PM UTC

        XCTAssertEqual(
            WorkoutRow.relativeDateText(for: sameYearDate, now: now, calendar: calendar, locale: locale, timeZone: timeZone),
            "Mar 5 • 3:30 AM"
        )
        XCTAssertEqual(
            WorkoutRow.relativeDateText(for: priorYearDate, now: now, calendar: calendar, locale: locale, timeZone: timeZone),
            "Dec 31, 2022 • 11:45 PM"
        )
    }

    func testWorkoutRowSetCountText_prefersCompletedWorkingSetsAndUsesSingularPluralGrammar() {
        let workout = Workout(name: "Workout Row Set Count")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: exercise, weight: 45, reps: 10, isWarmup: true)
        _ = workout.addSet(exercise: exercise, weight: 225, reps: 5)
        _ = workout.addSet(exercise: exercise, weight: 185, reps: 0)

        XCTAssertEqual(WorkoutRow.setCountText(for: workout), "1 set")

        _ = workout.addSet(exercise: exercise, weight: 205, reps: 6)

        XCTAssertEqual(WorkoutRow.setCountText(for: workout), "2 sets")
    }

    func testWorkoutRowCountsFallbackText_explainsWhenNoSetsWereLogged() {
        let emptyWorkout = Workout(name: "Imported Workout", isCompleted: true)
        XCTAssertEqual(WorkoutRow.countsFallbackText(for: emptyWorkout), "No sets logged")

        let placeholderWorkout = Workout(name: "Legacy Placeholder Workout", isCompleted: true)
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = placeholderWorkout.addSet(exercise: exercise, weight: 225, reps: 0)
        _ = placeholderWorkout.addSet(exercise: exercise, weight: 185, reps: 0)

        XCTAssertEqual(
            WorkoutRow.countsFallbackText(for: placeholderWorkout),
            "No sets logged",
            "Completed workouts with only placeholder/unstarted sets should not look like real logged work"
        )

        let warmupOnlyWorkout = Workout(name: "Warm-up Only Workout", isCompleted: true)
        _ = warmupOnlyWorkout.addSet(exercise: exercise, weight: 45, reps: 10, isWarmup: true)

        XCTAssertEqual(
            WorkoutRow.countsFallbackText(for: warmupOnlyWorkout),
            "Warm-up sets only",
            "Completed workouts with only logged warm-ups should acknowledge that some work was recorded"
        )

        let draftWorkout = Workout(name: "Draft Workout", isCompleted: false)
        _ = draftWorkout.addSet(exercise: exercise, weight: 225, reps: 0)
        XCTAssertNil(
            WorkoutRow.countsFallbackText(for: draftWorkout),
            "Incomplete drafts should keep their planned set counts instead of being flattened into a completed-history empty state"
        )

        let warmupOnlyDraft = Workout(name: "Warm-up Draft", isCompleted: false)
        _ = warmupOnlyDraft.addSet(exercise: exercise, weight: 45, reps: 10, isWarmup: true)
        XCTAssertEqual(
            WorkoutRow.countsFallbackText(for: warmupOnlyDraft),
            "Warm-up sets only",
            "Incomplete drafts with logged warm-ups should acknowledge that progress was recorded"
        )

        let loggedWorkout = Workout(name: "Logged Workout", isCompleted: true)
        _ = loggedWorkout.addSet(exercise: exercise, weight: 225, reps: 5)

        XCTAssertNil(WorkoutRow.countsFallbackText(for: loggedWorkout))
    }

    func testWorkoutRowDisplaySetCount_fallsBackToNonWarmupSetsBeforeCountingWarmups() {
        let workout = Workout(name: "Workout Row Fallback Set Count")
        let exercise = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])

        _ = workout.addSet(exercise: exercise, weight: 45, reps: 8, isWarmup: true)
        _ = workout.addSet(exercise: exercise, weight: 95, reps: 5, isWarmup: true)
        _ = workout.addSet(exercise: exercise, weight: 225, reps: 0)
        _ = workout.addSet(exercise: exercise, weight: 205, reps: 0)

        XCTAssertEqual(WorkoutRow.displaySetCount(for: workout), 2)
        XCTAssertEqual(WorkoutRow.setCountText(for: workout), "2 sets")
    }

    func testWorkoutRowExerciseCountText_prefersCompletedWorkingSetExercisesWithFallback() {
        let workout = Workout(name: "Workout Row Exercise Count")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])

        _ = workout.addSet(exercise: bench, weight: 225, reps: 5)
        _ = workout.addSet(exercise: squat, weight: 95, reps: 8, isWarmup: true)

        XCTAssertEqual(WorkoutRow.exerciseCountText(for: workout), "1 exercise")

        _ = workout.addSet(exercise: squat, weight: 185, reps: 5)

        XCTAssertEqual(WorkoutRow.exerciseCountText(for: workout), "2 exercises")

        let fallbackWorkout = Workout(name: "Workout Row Fallback")
        _ = fallbackWorkout.addSet(exercise: bench, weight: 135, reps: 0)
        _ = fallbackWorkout.addSet(exercise: squat, weight: 185, reps: 0)

        XCTAssertEqual(WorkoutRow.exerciseCountText(for: fallbackWorkout), "2 exercises")

        let completedPlaceholderWorkout = Workout(name: "Completed Placeholder Exercise Count", isCompleted: true)
        _ = completedPlaceholderWorkout.addSet(exercise: bench, weight: 135, reps: 0)
        _ = completedPlaceholderWorkout.addSet(exercise: squat, weight: 185, reps: 0)

        XCTAssertEqual(
            WorkoutRow.exerciseCountText(for: completedPlaceholderWorkout),
            "0 exercises",
            "Completed placeholder-only workouts should not count unlogged planned exercises as completed history"
        )

        let warmupOnlyWorkout = Workout(name: "Warm-up Exercise Count", isCompleted: true)
        _ = warmupOnlyWorkout.addSet(exercise: bench, weight: 45, reps: 10, isWarmup: true)

        XCTAssertEqual(
            WorkoutRow.exerciseCountText(for: warmupOnlyWorkout),
            "1 exercise",
            "Completed warm-up-only workouts should still acknowledge the logged exercise context"
        )
    }

    func testWorkoutRowDurationMetric_showsFormattedCompletedDuration() {
        let workout = Workout(name: "Long Workout", duration: 3725, isCompleted: true)

        let metric = WorkoutRow.durationMetric(for: workout)

        XCTAssertEqual(metric?.label, "Duration")
        XCTAssertEqual(metric?.value, "1h 2m 5s")
    }

    func testWorkoutRowDurationMetric_hidesIncompleteZeroAndCorruptedDurations() {
        let incompleteWorkout = Workout(name: "In Progress", duration: 3725, isCompleted: false)
        let zeroDurationWorkout = Workout(name: "Zero Duration", duration: 0, isCompleted: true)
        let corruptedDurationWorkout = Workout(name: "Corrupted Duration", duration: -.infinity, isCompleted: true)

        XCTAssertNil(WorkoutRow.durationMetric(for: incompleteWorkout))
        XCTAssertNil(WorkoutRow.durationMetric(for: zeroDurationWorkout))
        XCTAssertNil(WorkoutRow.durationMetric(for: corruptedDurationWorkout))
    }

    func testWorkoutDetailSummaryMetrics_includeDurationOnlyForCompletedPositiveDurations() {
        let completedWorkout = Workout(name: "Completed Workout", duration: 3725, isCompleted: true)
        let completedMetrics = WorkoutDetailView.summaryMetrics(for: completedWorkout)

        XCTAssertEqual(completedMetrics.last?.title, "Duration")
        XCTAssertEqual(completedMetrics.last?.value, "1h 2m 5s")

        let incompleteWorkout = Workout(name: "Incomplete Workout", duration: 3725, isCompleted: false)
        XCTAssertFalse(WorkoutDetailView.summaryMetrics(for: incompleteWorkout).contains(where: { $0.title == "Duration" }))

        let corruptedWorkout = Workout(name: "Corrupted Workout", duration: -.infinity, isCompleted: true)
        XCTAssertFalse(WorkoutDetailView.summaryMetrics(for: corruptedWorkout).contains(where: { $0.title == "Duration" }))
    }

    func testWorkoutDetailSummaryMetrics_includeBodyweightRepsForMixedSessions() {
        let workout = Workout(name: "Mixed Session")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let pullup = Exercise(name: "Pull-Up", category: .bodyweight, primaryMuscleGroups: [.back])

        _ = workout.addSet(exercise: bench, weight: 225, reps: 5)
        _ = workout.addSet(exercise: pullup, weight: 0, reps: 12)

        let metrics = WorkoutDetailView.summaryMetrics(for: workout)
        let volumeMetric = metrics.first(where: { $0.title == "Volume" })
        let bodyweightMetric = metrics.first(where: { $0.title == "Bodyweight Reps" })

        XCTAssertEqual(volumeMetric?.value, "1125 lb")
        XCTAssertEqual(bodyweightMetric?.value, "12 reps")
    }

    func testWorkoutDetailSummaryMetrics_useNeutralWorkCopyWhenNoCompletedWorkExists() {
        let completedWorkout = Workout(name: "Completed Placeholder", isCompleted: true)
        let incompleteWorkout = Workout(name: "Draft Placeholder")
        let emptyWorkout = Workout(name: "Empty Placeholder")
        let warmupOnlyWorkout = Workout(name: "Warm-up Only Placeholder", isCompleted: true)
        let warmupOnlyDraft = Workout(name: "Warm-up Draft Placeholder")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = completedWorkout.addSet(exercise: bench, weight: 185, reps: 0)
        _ = incompleteWorkout.addSet(exercise: bench, weight: 185, reps: 0)
        _ = warmupOnlyWorkout.addSet(exercise: bench, weight: 45, reps: 12, isWarmup: true)
        _ = warmupOnlyDraft.addSet(exercise: bench, weight: 45, reps: 10, isWarmup: true)

        let completedMetric = WorkoutDetailView.summaryMetrics(for: completedWorkout).first(where: { $0.title == "Work" })
        let incompleteMetric = WorkoutDetailView.summaryMetrics(for: incompleteWorkout).first(where: { $0.title == "Work" })
        let emptyMetric = WorkoutDetailView.summaryMetrics(for: emptyWorkout).first(where: { $0.title == "Work" })
        let warmupOnlyMetric = WorkoutDetailView.summaryMetrics(for: warmupOnlyWorkout).first(where: { $0.title == "Work" })
        let warmupOnlyDraftMetric = WorkoutDetailView.summaryMetrics(for: warmupOnlyDraft).first(where: { $0.title == "Work" })

        XCTAssertEqual(completedMetric?.value, "No sets logged")
        XCTAssertEqual(incompleteMetric?.value, "Not logged yet")
        XCTAssertEqual(emptyMetric?.value, "Not started")
        XCTAssertEqual(warmupOnlyMetric?.value, "Warm-up sets only")
        XCTAssertEqual(warmupOnlyDraftMetric?.value, "Warm-up sets only")
        XCTAssertFalse(WorkoutDetailView.summaryMetrics(for: completedWorkout).contains(where: { $0.title == "Volume" }))
    }

    func testWorkoutDetailSummaryMetrics_preferCompletedWorkingSetExerciseCountWithFallback() {
        let workout = Workout(name: "Workout Detail Exercise Count")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])

        _ = workout.addSet(exercise: bench, weight: 225, reps: 5)
        _ = workout.addSet(exercise: squat, weight: 95, reps: 8, isWarmup: true)

        let exerciseMetric = WorkoutDetailView.summaryMetrics(for: workout).first(where: { $0.title == "Exercises" })
        XCTAssertEqual(exerciseMetric?.value, "1")

        let fallbackWorkout = Workout(name: "Workout Detail Fallback")
        _ = fallbackWorkout.addSet(exercise: bench, weight: 135, reps: 0)
        _ = fallbackWorkout.addSet(exercise: squat, weight: 185, reps: 0)

        let fallbackMetric = WorkoutDetailView.summaryMetrics(for: fallbackWorkout).first(where: { $0.title == "Exercises" })
        XCTAssertEqual(fallbackMetric?.value, "2")

        let completedPlaceholderWorkout = Workout(name: "Completed Placeholder Detail", isCompleted: true)
        _ = completedPlaceholderWorkout.addSet(exercise: bench, weight: 135, reps: 0)
        _ = completedPlaceholderWorkout.addSet(exercise: squat, weight: 185, reps: 0)

        let completedPlaceholderMetric = WorkoutDetailView.summaryMetrics(for: completedPlaceholderWorkout).first(where: { $0.title == "Exercises" })
        XCTAssertEqual(
            completedPlaceholderMetric?.value,
            "0",
            "Completed placeholder-only workouts should not inflate the summary exercise count"
        )

        let warmupOnlyWorkout = Workout(name: "Completed Warmup Detail", isCompleted: true)
        _ = warmupOnlyWorkout.addSet(exercise: bench, weight: 45, reps: 10, isWarmup: true)

        let warmupOnlyMetric = WorkoutDetailView.summaryMetrics(for: warmupOnlyWorkout).first(where: { $0.title == "Exercises" })
        XCTAssertEqual(
            warmupOnlyMetric?.value,
            "1",
            "Completed warm-up-only workouts should preserve logged exercise context"
        )
    }

    func testWorkoutDetailSummaryMetrics_preferCompletedWorkingSetCountWithFallback() {
        let workout = Workout(name: "Workout Detail Set Count")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: bench, weight: 45, reps: 10, isWarmup: true)
        _ = workout.addSet(exercise: bench, weight: 225, reps: 5)
        _ = workout.addSet(exercise: bench, weight: 185, reps: 0)

        let setMetric = WorkoutDetailView.summaryMetrics(for: workout).first(where: { $0.title == "Sets" })
        XCTAssertEqual(setMetric?.value, "1")

        let fallbackWorkout = Workout(name: "Workout Detail Set Fallback")
        _ = fallbackWorkout.addSet(exercise: bench, weight: 135, reps: 0)
        _ = fallbackWorkout.addSet(exercise: bench, weight: 185, reps: 0)

        let fallbackMetric = WorkoutDetailView.summaryMetrics(for: fallbackWorkout).first(where: { $0.title == "Sets" })
        XCTAssertEqual(fallbackMetric?.value, "2")
    }

    func testWorkoutDetailSummaryMetrics_completedPlaceholderSetsDoNotInflateSetCount() {
        let workout = Workout(name: "Completed Placeholder Detail", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: bench, weight: 185, reps: 0)
        _ = workout.addSet(exercise: bench, weight: 165, reps: 0)

        let setMetric = WorkoutDetailView.summaryMetrics(for: workout).first(where: { $0.title == "Sets" })
        let workMetric = WorkoutDetailView.summaryMetrics(for: workout).first(where: { $0.title == "Work" })

        XCTAssertEqual(setMetric?.value, "0")
        XCTAssertEqual(workMetric?.value, "No sets logged")
    }

    func testWorkoutDetailSummaryMetrics_completedPlaceholderSetsFallBackToLoggedWarmups() {
        let workout = Workout(name: "Completed Warmup Detail", isCompleted: true)
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])

        _ = workout.addSet(exercise: squat, weight: 45, reps: 10, isWarmup: true)
        _ = workout.addSet(exercise: squat, weight: 225, reps: 0)
        _ = workout.addSet(exercise: squat, weight: 205, reps: 0)

        let setMetric = WorkoutDetailView.summaryMetrics(for: workout).first(where: { $0.title == "Sets" })
        let workMetric = WorkoutDetailView.summaryMetrics(for: workout).first(where: { $0.title == "Work" })

        XCTAssertEqual(setMetric?.value, "1")
        XCTAssertEqual(workMetric?.value, "Warm-up sets only")
    }

    func testWorkoutDetailSummaryMetrics_incompleteWarmupOnlyDraftIgnoresUntouchedPlaceholderCounts() {
        let workout = Workout(name: "Warm-up Draft Detail")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])

        _ = workout.addSet(exercise: bench, weight: 45, reps: 10, isWarmup: true)
        _ = workout.addSet(exercise: squat, weight: 225, reps: 0)
        _ = workout.addSet(exercise: squat, weight: 205, reps: 0)

        let metrics = WorkoutDetailView.summaryMetrics(for: workout)
        let exerciseMetric = metrics.first(where: { $0.title == "Exercises" })
        let setMetric = metrics.first(where: { $0.title == "Sets" })
        let workMetric = metrics.first(where: { $0.title == "Work" })

        XCTAssertEqual(exerciseMetric?.value, "1")
        XCTAssertEqual(setMetric?.value, "1")
        XCTAssertEqual(workMetric?.value, "Warm-up sets only")
    }

    func testWorkoutDetailSummaryMetrics_fallBackToNonWarmupSetsBeforeCountingWarmups() {
        let workout = Workout(name: "Workout Detail Warmup Fallback")
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])

        _ = workout.addSet(exercise: squat, weight: 45, reps: 8, isWarmup: true)
        _ = workout.addSet(exercise: squat, weight: 95, reps: 5, isWarmup: true)
        _ = workout.addSet(exercise: squat, weight: 225, reps: 0)
        _ = workout.addSet(exercise: squat, weight: 205, reps: 0)

        let setMetric = WorkoutDetailView.summaryMetrics(for: workout).first(where: { $0.title == "Sets" })
        XCTAssertEqual(setMetric?.value, "2")
    }

    func testWorkoutDetailNormalizedNotes_collapsesWhitespaceAndHidesBlankNotes() {
        let workoutWithNotes = Workout(name: "Notes Workout", notes: "  Great\n\n session   today  ")
        XCTAssertEqual(WorkoutDetailView.normalizedNotes(for: workoutWithNotes), "Great session today")

        let blankNotesWorkout = Workout(name: "Blank Notes", notes: " \n\t ")
        XCTAssertNil(WorkoutDetailView.normalizedNotes(for: blankNotesWorkout))
    }

    func testWorkoutDetailEmptyState_describesZeroSetCompletedAndDraftWorkouts() {
        let completedWorkout = Workout(name: "Legacy Import", isCompleted: true)
        let draftWorkout = Workout(name: "Draft")
        let loggedWorkout = Workout(name: "Logged")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = loggedWorkout.addSet(exercise: bench, weight: 225, reps: 5)

        let completedState = WorkoutDetailView.exerciseDetailsEmptyState(for: completedWorkout)
        let draftState = WorkoutDetailView.exerciseDetailsEmptyState(for: draftWorkout)
        let loggedState = WorkoutDetailView.exerciseDetailsEmptyState(for: loggedWorkout)

        XCTAssertEqual(completedState?.title, "No exercise details saved")
        XCTAssertEqual(
            completedState?.subtitle,
            "This workout was completed without any persisted exercise sets, so there’s nothing more to review here."
        )
        XCTAssertEqual(draftState?.title, "No exercises added yet")
        XCTAssertEqual(
            draftState?.subtitle,
            "Add an exercise to start logging sets and see your workout details here."
        )
        XCTAssertNil(loggedState)
    }

    func testWorkoutDetailDisplayName_fallsBackForBlankAndNormalizesWhitespace() {
        let blankNameWorkout = Workout(name: "   \n   ")
        XCTAssertEqual(WorkoutDetailView.displayName(for: blankNameWorkout), "Workout")

        let spacedNameWorkout = Workout(name: "  Upper   Body\nSession  ")
        XCTAssertEqual(WorkoutDetailView.displayName(for: spacedNameWorkout), "Upper Body Session")
    }

    func testWorkoutDetailDisplayExerciseName_fallsBackForBlankAndNormalizesWhitespace() {
        let blankExercise = Exercise(name: "   \n   ", category: .compound, primaryMuscleGroups: [.chest])
        XCTAssertEqual(WorkoutDetailView.displayExerciseName(blankExercise), "Exercise")

        let spacedExercise = Exercise(name: "  Incline   Bench\nPress  ", category: .compound, primaryMuscleGroups: [.chest])
        XCTAssertEqual(WorkoutDetailView.displayExerciseName(spacedExercise), "Incline Bench Press")
    }

    func testWorkoutDetailDisplayedExerciseGroups_hideCompletedPlaceholderOnlyExercisesWhenRealWorkExists() {
        let workout = Workout(name: "Mixed Completed Detail", isCompleted: true)
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])

        _ = workout.addSet(exercise: bench, weight: 225, reps: 5)
        _ = workout.addSet(exercise: squat, weight: 135, reps: 0)
        _ = workout.addSet(exercise: squat, weight: 95, reps: 0, isWarmup: true)

        let displayedGroups = WorkoutDetailView.displayedExerciseGroups(for: workout)

        XCTAssertEqual(displayedGroups.count, 1)
        XCTAssertEqual(displayedGroups.first?.exercise.name, "Bench Press")
    }

    func testWorkoutDetailDisplayedExerciseGroups_preserveWarmupOnlyContextWhenNoWorkingSetsWereLogged() {
        let workout = Workout(name: "Warmup Only Detail", isCompleted: true)
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: squat, weight: 45, reps: 10, isWarmup: true)
        _ = workout.addSet(exercise: bench, weight: 185, reps: 0)

        let displayedGroups = WorkoutDetailView.displayedExerciseGroups(for: workout)

        XCTAssertEqual(displayedGroups.count, 1)
        XCTAssertEqual(displayedGroups.first?.exercise.name, "Squat")
    }

    func testWorkoutRowSecondaryMetric_prefersBodyweightRepsWhenVolumeIsZero() {
        let workout = Workout(name: "Bodyweight Workout")
        let pullUp = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])

        _ = workout.addSet(exercise: pullUp, weight: 0, reps: 8)
        _ = workout.addSet(exercise: pullUp, weight: 0, reps: 6)

        let metric = WorkoutRow.secondaryMetric(for: workout)

        XCTAssertEqual(metric?.label, "Total Reps")
        XCTAssertEqual(metric?.value, "14 reps")
    }

    func testWorkoutRowSecondaryMetric_prefersVolumeWhenWeightedWorkExists() {
        let workout = Workout(name: "Mixed Workout")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let pullUp = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])

        _ = workout.addSet(exercise: bench, weight: 185, reps: 5)
        _ = workout.addSet(exercise: pullUp, weight: 0, reps: 10)

        let metric = WorkoutRow.secondaryMetric(for: workout)

        XCTAssertEqual(metric?.label, "Total Volume")
        XCTAssertEqual(metric?.value, "925 lb")
    }

    func testWorkoutRowSupplementalMetric_surfacesBodyweightRepsForMixedWorkout() {
        let workout = Workout(name: "Mixed Workout")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let pullUp = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])

        _ = workout.addSet(exercise: bench, weight: 185, reps: 5)
        _ = workout.addSet(exercise: pullUp, weight: 0, reps: 10)

        let metric = WorkoutRow.supplementalMetric(for: workout)

        XCTAssertEqual(metric?.label, "Bodyweight Reps")
        XCTAssertEqual(metric?.value, "10 reps")
    }

    func testWorkoutRowSupplementalMetric_hiddenForNonMixedWorkouts() {
        let weightedWorkout = Workout(name: "Weighted Workout")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = weightedWorkout.addSet(exercise: bench, weight: 225, reps: 5)

        XCTAssertNil(WorkoutRow.supplementalMetric(for: weightedWorkout))

        let bodyweightWorkout = Workout(name: "Bodyweight Workout")
        let pullUp = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])
        _ = bodyweightWorkout.addSet(exercise: pullUp, weight: 0, reps: 8)

        XCTAssertNil(WorkoutRow.supplementalMetric(for: bodyweightWorkout))
    }

    func testExerciseDetailRecentHistoryEntries_sortByWorkoutDateInsteadOfCorruptedSetTimestamp() {
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        let olderWorkout = Workout(
            date: Date(timeIntervalSinceReferenceDate: 1_000),
            name: "Older Workout",
            isCompleted: true
        )
        let olderSet = olderWorkout.addSet(exercise: exercise, weight: 225, reps: 5)
        olderSet.completedAt = Date(timeIntervalSinceReferenceDate: 5_000)

        let newerWorkout = Workout(
            date: Date(timeIntervalSinceReferenceDate: 2_000),
            name: "Newer Workout",
            isCompleted: true
        )
        let newerSet = newerWorkout.addSet(exercise: exercise, weight: 205, reps: 8)
        newerSet.completedAt = Date(timeIntervalSinceReferenceDate: 500)

        let entries = ExerciseDetailView.recentHistoryEntries(from: [
            (workout: olderWorkout, sets: [olderSet]),
            (workout: newerWorkout, sets: [newerSet])
        ])

        XCTAssertEqual(entries.map { $0.workout.name }, ["Newer Workout", "Older Workout"])
    }

    func testExerciseDetailRecentHistoryEntries_ignoresWorkoutsWithoutCompletedWorkingSets() {
        let exercise = Exercise(name: "Pull-up", category: .bodyweight, primaryMuscleGroups: [.back])

        let completedWorkout = Workout(name: "Completed", isCompleted: true)
        let completedSet = completedWorkout.addSet(exercise: exercise, weight: 0, reps: 10)

        let placeholderWorkout = Workout(name: "Placeholder", isCompleted: true)
        let placeholderSet = placeholderWorkout.addSet(exercise: exercise, weight: 0, reps: 0)

        let entries = ExerciseDetailView.recentHistoryEntries(from: [
            (workout: completedWorkout, sets: [completedSet]),
            (workout: placeholderWorkout, sets: [placeholderSet])
        ])

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.workout.name, "Completed")
        XCTAssertEqual(entries.first?.set.formattedWeightReps, "BW × 10 reps")
    }

    func testExerciseDetailDisplayName_fallsBackForBlankAndNormalizesWhitespace() {
        let blankExercise = Exercise(name: "   \n   ", category: .compound, primaryMuscleGroups: [.chest])
        XCTAssertEqual(ExerciseDetailView.displayName(for: blankExercise), "Exercise")

        let spacedExercise = Exercise(name: "  Incline   Bench\nPress  ", category: .compound, primaryMuscleGroups: [.chest])
        XCTAssertEqual(ExerciseDetailView.displayName(for: spacedExercise), "Incline Bench Press")
    }

    func testExerciseDisplayName_fallsBackForBlankAndNormalizesWhitespace() {
        let blankExercise = Exercise(name: "   \n   ", category: .compound, primaryMuscleGroups: [.chest])
        XCTAssertEqual(blankExercise.displayName, "Exercise")

        let spacedExercise = Exercise(name: "  Incline   Bench\nPress  ", category: .compound, primaryMuscleGroups: [.chest])
        XCTAssertEqual(spacedExercise.displayName, "Incline Bench Press")
    }

    func testExerciseDisplayName_clampsVeryLongNames() {
        let longName = String(repeating: "A", count: 120)
        let exercise = Exercise(name: longName, category: .compound, primaryMuscleGroups: [.chest])

        XCTAssertEqual(exercise.displayName.count, 80)
    }

    func testExercisePrimaryMuscleGroupSummary_usesDisplayNames() {
        let exercise = Exercise(
            name: "Back Extension",
            category: .bodyweight,
            primaryMuscleGroups: [.lowerBack, .glutes]
        )

        XCTAssertEqual(
            exercise.primaryMuscleGroupSummary,
            "Lower Back, Glutes",
            "Exercise picker rows should use muscle-group display names so camel-cased enum values never leak into UI"
        )
    }

    func testExerciseDetailNormalizedInstructions_collapsesWhitespaceAndHidesBlankInstructions() {
        let exerciseWithInstructions = Exercise(
            name: "Bench Press",
            category: .compound,
            primaryMuscleGroups: [.chest],
            instructions: "  Keep\n\n shoulders   packed  "
        )
        XCTAssertEqual(
            ExerciseDetailView.normalizedInstructions(for: exerciseWithInstructions),
            "Keep shoulders packed"
        )

        let blankInstructionsExercise = Exercise(
            name: "Bench Press",
            category: .compound,
            primaryMuscleGroups: [.chest],
            instructions: " \n\t "
        )
        XCTAssertNil(ExerciseDetailView.normalizedInstructions(for: blankInstructionsExercise))
    }

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
