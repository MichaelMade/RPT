//
//  HomeViewModel.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class HomeViewModel: ObservableObject {
    private let workoutManager: WorkoutManager
    private let userManager: UserManager
    
    @Published var recentWorkouts: [Workout] = []
    @Published var currentWorkout: Workout?
    @Published var userStats: (totalWorkouts: Int, totalVolume: Double, workoutStreak: Int)?
    @Published var lifetimeWorkMetricTitle: String = "Volume"
    @Published var lifetimeWorkMetricValue: String = "0"
    @Published var lifetimeWorkMetricSubtitle: String = "lb lifted"
    
    init(workoutManager: WorkoutManager? = nil,
         userManager: UserManager? = nil) {
        self.workoutManager = workoutManager ?? WorkoutManager.shared
        self.userManager = userManager ?? UserManager.shared
    }
    
    func loadRecentWorkouts() {
        let now = Date()
        let fetchedRecentWorkouts = workoutManager.getRecentWorkouts(limit: 25)
        let allWorkouts = workoutManager.getWorkouts(from: .distantPast, to: now)

        recentWorkouts = resolvedRecentCompletedWorkouts(
            from: fetchedRecentWorkouts,
            fallbackAllWorkouts: allWorkouts,
            limit: 5
        )
        userStats = userManager.getUserStats()

        let completedWorkouts = allWorkouts.filter { $0.isCompleted }
        let totalBodyweightReps = completedWorkouts.reduce(0) { $0 + max(0, $1.totalBodyweightReps) }
        let lifetimeWorkMetric = lifetimeWorkMetric(
            totalVolume: userStats?.totalVolume ?? 0,
            totalBodyweightReps: totalBodyweightReps
        )
        lifetimeWorkMetricTitle = lifetimeWorkMetric.title
        lifetimeWorkMetricValue = lifetimeWorkMetric.value
        lifetimeWorkMetricSubtitle = lifetimeWorkMetric.subtitle

        let workoutStateManager = WorkoutStateManager.shared
        currentWorkout = workoutStateManager.firstResumableWorkout(in: workoutManager.getIncompleteWorkouts())
    }
    
    func startNewWorkout() {
        currentWorkout = workoutManager.createWorkout()
    }
    
    func resumeWorkout(_ workout: Workout) {
        currentWorkout = workout
    }

    func resumableWorkout(activeWorkout: Workout?) -> Workout? {
        let workoutStateManager = WorkoutStateManager.shared

        if workoutStateManager.shouldResume(activeWorkout) {
            return activeWorkout
        }

        if workoutStateManager.shouldResume(currentWorkout) {
            return currentWorkout
        }

        return nil
    }

    func canContinueWorkout(activeWorkout: Workout?) -> Bool {
        resumableWorkout(activeWorkout: activeWorkout) != nil
    }

    func resolvedActiveWorkoutBinding(currentBinding: Workout?, storedWorkout: Workout?) -> Workout? {
        WorkoutStateManager.shared.resolvedResumableWorkout(
            currentBinding: currentBinding,
            fallbackWorkouts: [storedWorkout].compactMap { $0 }
        )
    }

    func shouldReloadAfterWorkoutSheetPresentationChange(from oldValue: Bool, to newValue: Bool) -> Bool {
        oldValue && !newValue
    }
    
    func weeklyWorkoutCount() -> Int {
        let stats = workoutManager.calculateWorkoutStats(timeframe: .week)
        return max(0, stats.count)
    }

    func resumableWorkoutSummary(for workout: Workout, now: Date = Date()) -> String {
        var parts: [String] = [workoutStartedSummary(for: workout.date, now: now)]

        if let templateName = normalizedSummaryName(workout.startedFromTemplate) {
            parts.append("From \(templateName)")
        }

        if workout.sets.isEmpty {
            parts.append("No exercises added yet")
        } else {
            parts.append(WorkoutRow.exerciseCountText(for: workout))
            parts.append(WorkoutRow.setCountText(for: workout))
            parts.append(resumableWorkoutProgressText(for: workout))
        }

        return parts.joined(separator: " • ")
    }

    func resumableWorkoutProgressText(for workout: Workout) -> String {
        let totalExercises = max(0, workout.exerciseCount)
        let startedExercises = startedExerciseCount(for: workout)

        guard totalExercises > 0 else {
            return "No exercises added yet"
        }

        if startedExercises <= 0 {
            return totalExercises == 1
                ? "Exercise not started yet"
                : "No exercises started yet"
        }

        if startedExercises >= totalExercises {
            return totalExercises == 1
                ? "Exercise started"
                : "All \(totalExercises) exercises started"
        }

        let exerciseLabel = totalExercises == 1 ? "exercise" : "exercises"
        return "\(startedExercises) of \(totalExercises) \(exerciseLabel) started"
    }

    func startedExerciseCount(for workout: Workout) -> Int {
        Set(
            workout.sets
                .filter(\.isCompletedLoggedSet)
                .compactMap { $0.exercise }
        ).count
    }

    func workoutStartedSummary(
        for startDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        var displayCalendar = calendar
        displayCalendar.timeZone = timeZone

        let safeInterval = max(0, now.timeIntervalSince(startDate))

        if displayCalendar.isDate(startDate, inSameDayAs: now) {
            if safeInterval < 60 {
                return "Started just now"
            }

            if safeInterval < 3600 {
                let minutes = max(1, Int(floor(safeInterval / 60)))
                return "Started \(minutes)m ago"
            }

            let hours = max(1, Int(floor(safeInterval / 3600)))
            return "Started \(hours)h ago"
        }

        return "Started " + WorkoutRow.relativeDateText(
            for: startDate,
            now: now,
            calendar: displayCalendar,
            locale: locale,
            timeZone: timeZone
        )
    }

    func calculateWeeklyProgress() -> Double {
        weeklyProgress(forWorkoutCount: weeklyWorkoutCount())
    }

    func weeklyProgress(forWorkoutCount count: Int) -> Double {
        guard count > 0 else { return 0 }
        return min(1.0, Double(count) / 7.0)
    }

    func weeklyProgressSummary(forWorkoutCount count: Int) -> String {
        let safeCount = max(0, count)
        let displayedCount = min(7, safeCount)
        return "\(displayedCount) of 7 workouts"
    }

    func weeklyProgressSubtitle(forWorkoutCount count: Int) -> String {
        let safeCount = max(0, count)

        if safeCount == 0 {
            return "Log a workout to start your weekly streak."
        }

        if safeCount >= 7 {
            return "You’ve hit your 7-workout pace for the last 7 days."
        }

        let remainingCount = 7 - safeCount
        let remainingLabel = remainingCount == 1 ? "workout" : "workouts"
        return "\(remainingCount) more \(remainingLabel) to fill the last-7-days goal."
    }

    func completedRecentWorkouts(from workouts: [Workout], limit: Int) -> [Workout] {
        guard limit > 0 else { return [] }

        return workouts
            .filter { $0.isCompleted }
            .sorted(by: { $0.date > $1.date })
            .prefix(limit)
            .map { $0 }
    }

    func resolvedRecentCompletedWorkouts(from recentSlice: [Workout], fallbackAllWorkouts: [Workout]?, limit: Int) -> [Workout] {
        let recentCompleted = completedRecentWorkouts(from: recentSlice, limit: limit)

        guard recentCompleted.count < limit else {
            return recentCompleted
        }

        let allWorkouts = fallbackAllWorkouts ?? workoutManager.getWorkouts(from: .distantPast, to: Date())

        return completedRecentWorkouts(from: allWorkouts, limit: limit)
    }

    func recentWorkoutsEmptyState(activeWorkout: Workout?) -> (title: String, subtitle: String) {
        if resumableWorkout(activeWorkout: activeWorkout) != nil {
            return (
                title: "No completed workouts yet",
                subtitle: "Finish your current workout to see it show up here with your latest stats."
            )
        }

        return (
            title: "No recent workouts yet",
            subtitle: "Complete a workout and your latest sessions will show up here for quick review."
        )
    }

    func startFreshWorkoutMessage(for workout: Workout, now: Date = Date()) -> String {
        "You already have \(resumableWorkoutSummary(for: workout, now: now)). Save it for later, discard it, or keep going."
    }

    func shouldResumeIncompleteWorkout(workoutDate: Date?, discardTimestamp: Date?, wasAnyWorkoutDiscarded: Bool) -> Bool {
        guard let workoutDate else { return false }

        guard wasAnyWorkoutDiscarded else {
            return true
        }

        guard let discardTimestamp else {
            // Fail open for legacy/corrupted discard state that is missing timestamp.
            // Hiding a valid resumable workout is worse UX than allowing resume.
            return true
        }

        return workoutDate >= discardTimestamp
    }
    
    func lifetimeWorkMetric(totalVolume: Double, totalBodyweightReps: Int) -> (title: String, value: String, subtitle: String) {
        let safeVolume = totalVolume.isFinite ? max(0, totalVolume) : 0
        let safeBodyweightReps = max(0, totalBodyweightReps)

        if safeVolume > 0 {
            return (
                title: "Volume",
                value: formatTotalVolume(safeVolume),
                subtitle: "lb lifted"
            )
        }

        if safeBodyweightReps > 0 {
            return (
                title: "Reps",
                value: "\(safeBodyweightReps)",
                subtitle: "bodyweight reps"
            )
        }

        return (
            title: "Volume",
            value: "0",
            subtitle: "lb lifted"
        )
    }

    func formatTotalVolume() -> String {
        guard let stats = userStats else { return "0" }
        return formatTotalVolume(stats.totalVolume)
    }

    private func formatTotalVolume(_ totalVolume: Double) -> String {
        let safeVolume = totalVolume.isFinite ? max(0, totalVolume) : 0
        let truncatedVolume = floor(safeVolume * 10) / 10

        if truncatedVolume >= 1_000_000 {
            let millions = truncatedVolume / 1_000_000
            let truncatedMillions = floor(millions * 10) / 10
            let isWholeMillions = truncatedMillions.truncatingRemainder(dividingBy: 1) == 0

            return isWholeMillions
                ? "\(Int(truncatedMillions))M"
                : String(format: "%.1fM", truncatedMillions)
        }

        if truncatedVolume >= 1000 {
            let thousands = truncatedVolume / 1000
            let truncatedThousands = floor(thousands * 10) / 10
            let isWholeThousands = truncatedThousands.truncatingRemainder(dividingBy: 1) == 0

            return isWholeThousands
                ? "\(Int(truncatedThousands))k"
                : String(format: "%.1fk", truncatedThousands)
        }

        return "\(Int(floor(truncatedVolume)))"
    }

    private func normalizedSummaryName(_ raw: String?) -> String? {
        guard let raw else { return nil }

        let collapsedName = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedName.isEmpty else {
            return nil
        }

        return String(collapsedName.prefix(80))
    }
}
