//
//  User.swift
//  RPT
//
//  Created by Michael Moore on 4/28/25.
//

import Foundation
import SwiftData

@Model
final class User {
    var id: UUID
    var username: String
    var email: String
    var dateJoined: Date
    var height: Double? // in inches
    var weight: Double? // in pounds
    var birthdate: Date?
    var profileImageName: String?
    var settings: UserSettings?
    
    // Tracking data
    var lastActive: Date
    var workoutStreak: Int
    var totalWorkouts: Int
    var totalVolume: Double
    var personalBests: [String: Int] // Exercise name: weight
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Workout.user)
    var workouts: [Workout]
    
    init(
        id: UUID = UUID(),
        username: String,
        email: String,
        dateJoined: Date = Date(),
        height: Double? = nil,
        weight: Double? = nil,
        birthdate: Date? = nil,
        profileImageName: String? = nil,
        lastActive: Date = Date(),
        workoutStreak: Int = 0,
        totalWorkouts: Int = 0,
        totalVolume: Double = 0.0,
        personalBests: [String: Int] = [:]
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.dateJoined = dateJoined
        self.height = height
        self.weight = weight
        self.birthdate = birthdate
        self.profileImageName = profileImageName
        self.lastActive = lastActive
        self.workoutStreak = workoutStreak
        self.totalWorkouts = totalWorkouts
        self.totalVolume = totalVolume
        self.personalBests = personalBests
        self.workouts = []
    }
    
    // Calculate age from birthdate if available
    var age: Int? {
        guard let birthdate = birthdate else { return nil }
        
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthdate, to: Date())
        return ageComponents.year
    }
    
    // Calculate BMI if height and weight are available
    var bmi: Double? {
        guard let height = height, let weight = weight, height > 0 else { return nil }
        
        // BMI = 703 * weight(lb) / height(in)²
        return 703 * weight / (height * height)
    }
    
    // Update user stats after completing a workout
    func updateStats(with workout: Workout) {
        lastActive = Date()
        totalWorkouts += 1

        let completedWorkingVolume = workout.sets
            .filter(\.isCompletedWorkingSet)
            .reduce(0.0) { $0 + (Double($1.weight) * Double($1.reps)) }
        let safeWorkoutVolume = completedWorkingVolume.isFinite ? max(0, completedWorkingVolume) : 0
        totalVolume += safeWorkoutVolume

        updateWorkoutStreak(currentWorkout: workout)
        updatePersonalBests(with: workout)
    }

    // Register a completed workout exactly once to prevent duplicate lifetime stats.
    // Returns true when the workout was newly registered, false when it was already linked.
    @discardableResult
    func registerCompletedWorkoutIfNeeded(_ workout: Workout) -> Bool {
        if workout.user?.id != id {
            workout.user = self
        }

        let isAlreadyRegistered = workouts.contains { $0.id == workout.id }
        guard !isAlreadyRegistered else {
            return false
        }

        workouts.append(workout)
        updateStats(with: workout)
        return true
    }

    // Check and update the workout streak, excluding the just-completed workout
    private func updateWorkoutStreak(currentWorkout: Workout) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return }

        let previousDates = workouts.filter { $0 !== currentWorkout }.map { $0.date }
        let latestPreviousDay = previousDates.max().map { calendar.startOfDay(for: $0) }

        if latestPreviousDay == today {
            // Another workout already counted today; streak unchanged
            return
        } else if latestPreviousDay == yesterday {
            workoutStreak += 1
        } else {
            workoutStreak = 1
        }
    }

    // Update personal bests based on the workout (working sets only)
    private func updatePersonalBests(with workout: Workout) {
        for set in workout.sets where set.isCompletedWorkingSet {
            guard let exercise = set.exercise else { continue }

            let currentBest = personalBests[exercise.name] ?? 0
            if set.weight > currentBest {
                personalBests[exercise.name] = set.weight
            }
        }
    }
}
