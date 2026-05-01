//
//  StatsViewModel.swift
//  RPT
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class StatsViewModel: ObservableObject {
    struct WeeklyVolumePoint: Identifiable {
        let id = UUID()
        let weekStart: Date
        let volume: Double
    }

    struct MuscleGroupShare: Identifiable {
        let id = UUID()
        let group: MuscleGroup
        let setCount: Int
    }

    struct PersonalRecord: Identifiable {
        let id = UUID()
        let exerciseName: String
        let weight: Int
        let reps: Int
        let date: Date
        let exerciseCategory: ExerciseCategory? = nil

        var formattedWeightReps: String {
            ExerciseSet.formattedWeightReps(weight: weight, reps: reps, exerciseCategory: exerciseCategory)
        }
    }

    @Published var totalWorkouts: Int = 0
    @Published var totalVolume: Double = 0
    @Published var currentStreak: Int = 0
    @Published var weeksActive: Int = 0
    @Published var lifetimeWorkMetricTitle: String = "Volume"
    @Published var lifetimeWorkMetricValue: String = "0 lb"
    @Published var lifetimeWorkMetricSubtitle: String = "lifted"
    @Published var weeklyWorkoutCount: Int = 0
    @Published var weeklyWorkMetricTitle: String = "Volume"
    @Published var weeklyWorkMetricValue: String = "—"
    @Published var weeklyWorkMetricSubtitle: String = "lifted"
    @Published var weeklyAverageDuration: String = "0s"
    @Published var hasWeeklyAverageDuration: Bool = false
    @Published var weeklyVolume: [WeeklyVolumePoint] = []
    @Published var muscleGroupShare: [MuscleGroupShare] = []
    @Published var recentPRs: [PersonalRecord] = []

    private let workoutManager: WorkoutManager
    private let userManager: UserManager

    init(workoutManager: WorkoutManager? = nil, userManager: UserManager? = nil) {
        self.workoutManager = workoutManager ?? WorkoutManager.shared
        self.userManager = userManager ?? UserManager.shared
    }

    func reload() {
        let stats = userManager.getUserStats()
        totalWorkouts = stats.totalWorkouts
        totalVolume = sanitizedVolume(stats.totalVolume)
        currentStreak = stats.workoutStreak

        let now = Date()
        let thisWeekStart = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? .distantPast
        let thisWeek = workoutManager.calculateWorkoutStats(timeframe: .week)
        weeklyWorkoutCount = max(0, thisWeek.count)
        weeklyAverageDuration = workoutManager.formatDuration(thisWeek.averageDuration)
        hasWeeklyAverageDuration = thisWeek.averageDuration > 0

        // Use full history so long-time users don't lose older PRs/weekly activity
        // once they pass an arbitrary recent-workout cap.
        let allWorkouts = workoutManager
            .getWorkouts(from: .distantPast, to: now)
            .filter { $0.isCompleted }

        let lifetimeBodyweightReps = allWorkouts.reduce(0) { $0 + max(0, $1.totalBodyweightReps) }
        let lifetimeWorkMetric = lifetimeWorkMetric(
            totalVolume: totalVolume,
            totalBodyweightReps: lifetimeBodyweightReps
        )
        lifetimeWorkMetricTitle = lifetimeWorkMetric.title
        lifetimeWorkMetricValue = lifetimeWorkMetric.value
        lifetimeWorkMetricSubtitle = lifetimeWorkMetric.subtitle

        let thisWeekWorkouts = allWorkouts.filter { $0.date >= thisWeekStart }
        let thisWeekBodyweightReps = thisWeekWorkouts.reduce(0) { $0 + $1.totalBodyweightReps }
        let thisWeekTotalVolume = thisWeekWorkouts.reduce(0) { $0 + sanitizedVolume($1.totalVolume) }
        weeklyWorkMetricTitle = weeklyWorkMetricTitle(
            weeklyWorkoutCount: weeklyWorkoutCount,
            totalVolume: thisWeekTotalVolume,
            totalBodyweightReps: thisWeekBodyweightReps
        )
        weeklyWorkMetricValue = weeklyWorkMetricValue(
            weeklyWorkoutCount: weeklyWorkoutCount,
            formattedVolume: workoutManager.formatVolume(thisWeek.totalVolume),
            totalBodyweightReps: thisWeekBodyweightReps
        )
        weeklyWorkMetricSubtitle = weeklyWorkMetricSubtitle(
            weeklyWorkoutCount: weeklyWorkoutCount,
            totalVolume: thisWeekTotalVolume,
            totalBodyweightReps: thisWeekBodyweightReps
        )

        computeWeeklyVolume(from: allWorkouts)
        computeMuscleGroupShare(from: allWorkouts)
        computePRs(from: allWorkouts)
        weeksActive = Set(allWorkouts.map { weekAnchor(for: $0.date) }).count
    }

    // MARK: - Calculations

    private func computeWeeklyVolume(from workouts: [Workout]) {
        let now = Date()
        let cal = Calendar.current
        guard let twelveWeeksAgo = cal.date(byAdding: .weekOfYear, value: -11, to: weekAnchor(for: now)) else {
            weeklyVolume = []
            return
        }

        let recent = workouts.filter { $0.date >= twelveWeeksAgo }
        let grouped = Dictionary(grouping: recent) { weekAnchor(for: $0.date) }

        var points: [WeeklyVolumePoint] = []
        var cursor = twelveWeeksAgo
        while cursor <= now {
            let volume = (grouped[cursor] ?? []).reduce(0.0) { partial, workout in
                partial + sanitizedVolume(workout.totalVolume)
            }
            points.append(WeeklyVolumePoint(weekStart: cursor, volume: sanitizedVolume(volume)))
            cursor = cal.date(byAdding: .weekOfYear, value: 1, to: cursor) ?? cursor.addingTimeInterval(604800)
        }
        weeklyVolume = points
    }

    private func computeMuscleGroupShare(from workouts: [Workout]) {
        let cal = Calendar.current
        guard let fourWeeksAgo = cal.date(byAdding: .weekOfYear, value: -4, to: Date()) else {
            muscleGroupShare = []
            return
        }

        let recent = workouts.filter { $0.date >= fourWeeksAgo }
        var counts: [MuscleGroup: Int] = [:]

        for workout in recent {
            for set in workout.sets where set.isCompletedWorkingSet {
                guard let exercise = set.exercise else { continue }
                for group in exercise.primaryMuscleGroups {
                    counts[group, default: 0] += 1
                }
            }
        }

        muscleGroupShare = counts
            .map { MuscleGroupShare(group: $0.key, setCount: $0.value) }
            .sorted { $0.setCount > $1.setCount }
    }

    private func computePRs(from workouts: [Workout]) {
        var best: [String: PersonalRecord] = [:]

        for workout in workouts {
            for set in workout.sets where set.isCompletedWorkingSet {
                guard let rawName = set.exercise?.name,
                      let normalizedName = normalizedPRExerciseName(rawName)
                else {
                    continue
                }

                if let existing = best[normalizedName.key], !isBetterPRCandidate(set, than: existing) {
                    continue
                }

                best[normalizedName.key] = PersonalRecord(
                    exerciseName: normalizedName.display,
                    weight: set.weight,
                    reps: set.reps,
                    date: prReferenceDate(for: set),
                    exerciseCategory: set.exercise?.category
                )
            }
        }

        recentPRs = best.values
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }

    func isBetterPRCandidate(_ set: ExerciseSet, than existing: PersonalRecord) -> Bool {
        if set.weight != existing.weight {
            return set.weight > existing.weight
        }

        if set.reps != existing.reps {
            return set.reps > existing.reps
        }

        return prReferenceDate(for: set) > existing.date
    }

    func prReferenceDate(for set: ExerciseSet) -> Date {
        let workoutDate = set.workout?.date ?? .distantPast
        let completionDate = set.completedAt

        if workoutDate == .distantPast {
            return completionDate
        }

        return workoutDate
    }

    func normalizedPRExerciseName(_ rawName: String) -> (display: String, key: String)? {
        let collapsedName = rawName
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedName.isEmpty else {
            return nil
        }

        let normalizedKey = collapsedName.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )

        return (display: collapsedName, key: normalizedKey)
    }

    // MARK: - Helpers

    func lifetimeWorkMetric(totalVolume: Double, totalBodyweightReps: Int) -> (title: String, value: String, subtitle: String) {
        let safeVolume = sanitizedVolume(totalVolume)
        let safeBodyweightReps = max(0, totalBodyweightReps)

        if safeVolume > 0 {
            return (
                title: "Volume",
                value: formatVolumeForHeadline(safeVolume),
                subtitle: "lifted"
            )
        }

        if safeBodyweightReps > 0 {
            return (
                title: "Reps",
                value: "\(safeBodyweightReps)",
                subtitle: "bodyweight"
            )
        }

        return (
            title: "Volume",
            value: "0 lb",
            subtitle: "lifted"
        )
    }

    func weeklyWorkMetricTitle(weeklyWorkoutCount: Int, totalVolume: Double, totalBodyweightReps: Int) -> String {
        guard max(0, weeklyWorkoutCount) > 0 else {
            return "Work"
        }

        let safeVolume = sanitizedVolume(totalVolume)
        let safeBodyweightReps = max(0, totalBodyweightReps)

        if safeVolume > 0 {
            return "Volume"
        }

        if safeBodyweightReps > 0 {
            return "Reps"
        }

        return "Work"
    }

    func weeklyWorkMetricValue(weeklyWorkoutCount: Int, formattedVolume: String, totalBodyweightReps: Int) -> String {
        guard max(0, weeklyWorkoutCount) > 0 else {
            return "—"
        }

        if totalBodyweightReps > 0, formattedVolume == "0 lb" {
            return "\(totalBodyweightReps)"
        }

        return formattedVolume == "0 lb" ? "—" : formattedVolume
    }

    func weeklyWorkMetricSubtitle(weeklyWorkoutCount: Int, totalVolume: Double, totalBodyweightReps: Int) -> String {
        guard max(0, weeklyWorkoutCount) > 0 else {
            return "last 7 days"
        }

        return sanitizedVolume(totalVolume) > 0 ? "lifted" : (totalBodyweightReps > 0 ? "bodyweight" : "logged")
    }

    func sanitizedVolume(_ volume: Double) -> Double {
        volume.isFinite ? max(0, volume) : 0
    }

    private func formatVolumeForHeadline(_ volume: Double) -> String {
        let safeVolume = sanitizedVolume(volume)
        let truncatedVolume = floor(safeVolume * 10) / 10

        if truncatedVolume >= 1_000_000 {
            let millions = truncatedVolume / 1_000_000
            let truncatedMillions = floor(millions * 10) / 10
            let isWhole = truncatedMillions.truncatingRemainder(dividingBy: 1) == 0
            return isWhole
                ? "\(Int(truncatedMillions))M lb"
                : String(format: "%.1fM lb", truncatedMillions)
        }

        if truncatedVolume >= 1000 {
            let thousands = truncatedVolume / 1000
            let truncatedThousands = floor(thousands * 10) / 10
            let isWhole = truncatedThousands.truncatingRemainder(dividingBy: 1) == 0
            return isWhole
                ? "\(Int(truncatedThousands))k lb"
                : String(format: "%.1fk lb", truncatedThousands)
        }

        return "\(Int(floor(truncatedVolume))) lb"
    }

    private func weekAnchor(for date: Date) -> Date {
        let cal = Calendar.current
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: components) ?? date
    }
}
