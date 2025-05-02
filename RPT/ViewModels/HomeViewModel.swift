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
        
        // Check for discarded state - if a workout was discarded, don't load incomplete
        let workoutStateManager = WorkoutStateManager.shared
        if workoutStateManager.wasAnyWorkoutDiscarded() {
            // Don't load incomplete workouts if any was discarded
            print("HomeViewModel - Not loading incomplete workouts due to discard state")
            currentWorkout = nil
            return
        }
        
        // Check if there's a saved but incomplete workout
        let incompleteWorkouts = workoutManager.getIncompleteWorkouts()
        if let lastIncomplete = incompleteWorkouts.first {
            // Set as current workout so it can be continued
            currentWorkout = lastIncomplete
            print("HomeViewModel - Found incomplete workout: \(lastIncomplete.name)")
        } else {
            // No incomplete workouts found
            currentWorkout = nil
        }
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
        
        let isWholeNumber = stats.totalVolume.truncatingRemainder(dividingBy: 1) == 0
        
        if stats.totalVolume > 1000 {
            let thousands = stats.totalVolume / 1000
            return isWholeNumber ? 
                "\(Int(thousands))k" : 
                String(format: "%.1fk", thousands)
        } else {
            return "\(Int(stats.totalVolume))"
        }
    }
}
