//
//  StatsViewModel.swift
//  RPT
//
//  Analytics over completed training history: weekly volume trend,
//  consistency heatmap, muscle group balance, and e1RM-based PRs.
//

import Foundation
import SwiftUI

struct WeeklyVolumePoint: Identifiable {
    let weekStart: Date
    let volume: Double

    var id: Date { weekStart }
}

struct MuscleGroupShare: Identifiable {
    let muscleGroup: MuscleGroup
    let workingSets: Int

    var id: MuscleGroup { muscleGroup }
}

struct PersonalRecordEntry: Identifiable {
    let exerciseName: String
    let weight: Int
    let reps: Int
    let estimatedOneRepMax: Double
    let date: Date

    var id: String { exerciseName }
}

@MainActor
class StatsViewModel: ObservableObject {
    @Published var completedWorkoutCount: Int = 0
    @Published var totalVolume: Double = 0
    @Published var averageDuration: TimeInterval = 0
    @Published var workoutStreak: Int = 0
    @Published var weeklyVolume: [WeeklyVolumePoint] = []
    @Published var muscleGroupShares: [MuscleGroupShare] = []
    @Published var personalRecords: [PersonalRecordEntry] = []
    @Published var dailyVolume: [Date: Double] = [:]

    private let workoutManager: WorkoutManager
    private let userManager: UserManager

    init(workoutManager: WorkoutManager? = nil, userManager: UserManager? = nil) {
        self.workoutManager = workoutManager ?? WorkoutManager.shared
        self.userManager = userManager ?? UserManager.shared
    }

    var allCompletedWorkouts: [Workout] {
        workoutManager
            .getWorkouts(from: .distantPast, to: Date())
            .filter(\.isCompleted)
    }

    func refresh() {
        let completed = allCompletedWorkouts
        let calendar = Calendar.current
        let now = Date()

        // Lifetime summary
        let aggregate = workoutManager.aggregateCompletedWorkoutStats(from: completed)
        completedWorkoutCount = aggregate.count
        totalVolume = aggregate.totalVolume
        averageDuration = aggregate.averageDuration
        workoutStreak = userManager.getUserStats().workoutStreak

        // Weekly volume — last 12 weeks, including empty weeks.
        var volumeByWeek: [Date: Double] = [:]
        for workout in completed {
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: workout.date)?.start else { continue }
            let safeVolume = workout.totalVolume.isFinite ? max(0, workout.totalVolume) : 0
            volumeByWeek[weekStart, default: 0] += safeVolume
        }

        var points: [WeeklyVolumePoint] = []
        if let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start {
            for offset in stride(from: 11, through: 0, by: -1) {
                guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart) else { continue }
                points.append(WeeklyVolumePoint(weekStart: weekStart, volume: volumeByWeek[weekStart] ?? 0))
            }
        }
        weeklyVolume = points

        // Daily intensity for the heatmap.
        var volumeByDay: [Date: Double] = [:]
        for workout in completed {
            let day = calendar.startOfDay(for: workout.date)
            let safeVolume = workout.totalVolume.isFinite ? max(0, workout.totalVolume) : 0
            // Bodyweight-only sessions still count as activity.
            volumeByDay[day, default: 0] += max(safeVolume, workout.workingSetsCount > 0 ? 1 : 0)
        }
        dailyVolume = volumeByDay

        // Muscle group balance — completed working sets in the last 4 weeks,
        // counting primary muscles fully.
        let fourWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -4, to: now) ?? .distantPast
        var setsByMuscle: [MuscleGroup: Int] = [:]

        for workout in completed where workout.date >= fourWeeksAgo {
            for set in workout.sets where set.isCompletedWorkingSet {
                guard let exercise = set.exercise else { continue }
                for muscle in exercise.primaryMuscleGroups {
                    setsByMuscle[muscle, default: 0] += 1
                }
            }
        }

        muscleGroupShares = setsByMuscle
            .map { MuscleGroupShare(muscleGroup: $0.key, workingSets: $0.value) }
            .sorted { $0.workingSets > $1.workingSets }

        // Personal records by estimated 1RM, one entry per exercise.
        var bestByExercise: [String: PersonalRecordEntry] = [:]

        for workout in completed {
            for set in workout.sets where set.isCompletedWorkingSet && set.weight > 0 {
                guard let exerciseName = set.exercise?.displayName else { continue }

                let estimate = OneRepMax.estimate(weight: set.weight, reps: set.reps)
                guard estimate > 0 else { continue }

                if let existing = bestByExercise[exerciseName], existing.estimatedOneRepMax >= estimate {
                    continue
                }

                bestByExercise[exerciseName] = PersonalRecordEntry(
                    exerciseName: exerciseName,
                    weight: set.weight,
                    reps: set.reps,
                    estimatedOneRepMax: estimate,
                    date: workout.date
                )
            }
        }

        personalRecords = bestByExercise.values
            .sorted { $0.estimatedOneRepMax > $1.estimatedOneRepMax }
    }

    func formattedVolume(_ volume: Double) -> String {
        workoutManager.formatVolume(volume)
    }

    func formattedDuration(_ duration: TimeInterval) -> String {
        workoutManager.formatDuration(duration)
    }
}
