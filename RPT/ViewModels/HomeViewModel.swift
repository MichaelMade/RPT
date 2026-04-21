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

        if WorkoutStateManager.shared.wasAnyWorkoutDiscarded() {
            currentWorkout = nil
            return
        }

        currentWorkout = workoutManager.getIncompleteWorkouts().first
    }
    
    func startNewWorkout() {
        currentWorkout = workoutManager.createWorkout()
    }
    
    func resumeWorkout(_ workout: Workout) {
        currentWorkout = workout
    }
    
    func calculateWeeklyProgress() -> Double {
        let stats = workoutManager.calculateWorkoutStats(timeframe: .week)
        return stats.count > 0 ? Double(stats.count) / 7.0 : 0
    }
    
    func formatTotalVolume() -> String {
        guard let stats = userStats else { return "0" }

        let safeVolume = stats.totalVolume.isFinite ? max(0, stats.totalVolume) : 0

        if safeVolume >= 1000 {
            let thousands = safeVolume / 1000
            let roundedThousands = (thousands * 10).rounded() / 10
            let isWholeThousands = roundedThousands.truncatingRemainder(dividingBy: 1) == 0
            return isWholeThousands ?
                "\(Int(roundedThousands))k" :
                String(format: "%.1fk", roundedThousands)
        } else {
            return "\(Int(safeVolume))"
        }
    }
}
