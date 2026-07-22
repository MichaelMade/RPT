//
//  HomeViewModel.swift
//  RPT
//
//  Data for the Home dashboard: recent history, the week-at-a-glance
//  goal ring, and quick lifetime stats.
//

import Foundation
import SwiftUI

@MainActor
class HomeViewModel: ObservableObject {
    @Published var recentWorkouts: [Workout] = []
    @Published var workoutsThisWeek: Int = 0
    @Published var volumeThisWeek: Double = 0
    @Published var totalWorkouts: Int = 0
    @Published var workoutStreak: Int = 0

    private let workoutManager: WorkoutManager
    private let userManager: UserManager
    private let settingsManager: SettingsManager

    init(
        workoutManager: WorkoutManager? = nil,
        userManager: UserManager? = nil,
        settingsManager: SettingsManager? = nil
    ) {
        self.workoutManager = workoutManager ?? WorkoutManager.shared
        self.userManager = userManager ?? UserManager.shared
        self.settingsManager = settingsManager ?? SettingsManager.shared
    }

    var weeklyGoal: Int {
        settingsManager.settings.weeklyWorkoutGoal
    }

    var weeklyGoalProgress: Double {
        guard weeklyGoal > 0 else { return 0 }
        return min(1, Double(workoutsThisWeek) / Double(weeklyGoal))
    }

    func refresh() {
        let allRecent = workoutManager.getRecentWorkouts(limit: 30)
        recentWorkouts = Array(allRecent.filter(\.isCompleted).prefix(5))

        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            ?? calendar.startOfDay(for: now)

        let thisWeek = allRecent.filter { $0.isCompleted && $0.date >= weekStart && $0.date <= now }
        workoutsThisWeek = thisWeek.count
        volumeThisWeek = thisWeek.reduce(0.0) { partial, workout in
            let safeVolume = workout.totalVolume.isFinite ? max(0, workout.totalVolume) : 0
            return partial + safeVolume
        }

        let stats = userManager.getUserStats()
        totalWorkouts = stats.totalWorkouts
        workoutStreak = stats.workoutStreak
    }

    func deleteWorkout(_ workout: Workout) -> Bool {
        let didDelete = workoutManager.deleteWorkoutSafely(workout)
        if didDelete {
            refresh()
        }
        return didDelete
    }

    func formattedVolume(_ volume: Double) -> String {
        workoutManager.formatVolume(volume)
    }
}
