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
        recentWorkouts = workoutManager.getRecentWorkouts(limit: 5)
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
        activeWorkout ?? currentWorkout
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
        let roundedVolume = (safeVolume * 10).rounded() / 10

        if roundedVolume >= 1000 {
            let thousands = roundedVolume / 1000
            let roundedThousands = (thousands * 10).rounded() / 10
            let isWholeThousands = roundedThousands.truncatingRemainder(dividingBy: 1) == 0
            return isWholeThousands ?
                "\(Int(roundedThousands))k" :
                String(format: "%.1fk", roundedThousands)
        } else {
            let roundedWhole = Int(roundedVolume.rounded())
            if roundedWhole >= 1000 {
                return "1k"
            }
            return "\(roundedWhole)"
        }
    }
}
