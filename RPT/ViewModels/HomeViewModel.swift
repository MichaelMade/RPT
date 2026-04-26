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
    
    init(workoutManager: WorkoutManager? = nil,
         userManager: UserManager? = nil) {
        self.workoutManager = workoutManager ?? WorkoutManager.shared
        self.userManager = userManager ?? UserManager.shared
    }
    
    func loadRecentWorkouts() {
        let fetchedRecentWorkouts = workoutManager.getRecentWorkouts(limit: 25)
        recentWorkouts = completedRecentWorkouts(from: fetchedRecentWorkouts, limit: 5)
        userStats = userManager.getUserStats()

        let incompleteWorkout = workoutManager.getIncompleteWorkouts().first
        let workoutStateManager = WorkoutStateManager.shared
        let shouldResume = shouldResumeIncompleteWorkout(
            workoutDate: incompleteWorkout?.date,
            discardTimestamp: workoutStateManager.discardTimestamp,
            wasAnyWorkoutDiscarded: workoutStateManager.wasAnyWorkoutDiscarded()
        )

        currentWorkout = shouldResume ? incompleteWorkout : nil
    }
    
    func startNewWorkout() {
        currentWorkout = workoutManager.createWorkout()
    }
    
    func resumeWorkout(_ workout: Workout) {
        currentWorkout = workout
    }

    func resumableWorkout(activeWorkout: Workout?) -> Workout? {
        if let activeWorkout, !activeWorkout.isCompleted {
            return activeWorkout
        }

        if let currentWorkout, !currentWorkout.isCompleted {
            return currentWorkout
        }

        return nil
    }

    func canContinueWorkout(activeWorkout: Workout?) -> Bool {
        resumableWorkout(activeWorkout: activeWorkout) != nil
    }
    
    func calculateWeeklyProgress() -> Double {
        let stats = workoutManager.calculateWorkoutStats(timeframe: .week)
        return weeklyProgress(forWorkoutCount: stats.count)
    }

    func weeklyProgress(forWorkoutCount count: Int) -> Double {
        guard count > 0 else { return 0 }
        return min(1.0, Double(count) / 7.0)
    }

    func completedRecentWorkouts(from workouts: [Workout], limit: Int) -> [Workout] {
        guard limit > 0 else { return [] }

        return workouts
            .filter { $0.isCompleted }
            .sorted(by: { $0.date > $1.date })
            .prefix(limit)
            .map { $0 }
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
    
    func formatTotalVolume() -> String {
        guard let stats = userStats else { return "0" }

        let safeVolume = stats.totalVolume.isFinite ? max(0, stats.totalVolume) : 0
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
}
