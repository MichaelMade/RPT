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
    // Returns true when the workout was newly registered, false when it was already linked
    // or when the workout is not actually completed.
    @discardableResult
    func registerCompletedWorkoutIfNeeded(_ workout: Workout) -> Bool {
        guard workout.isCompleted else {
            return false
        }

        // Check registration BEFORE touching the relationship: setting
        // `workout.user` makes SwiftData's inverse maintenance append the
        // workout to `workouts`, which would make this guard always trip
        // and silently skip the stats update.
        let isAlreadyRegistered = workouts.contains { $0.id == workout.id }

        if workout.user?.id != id {
            workout.user = self
        }

        guard !isAlreadyRegistered else {
            return false
        }

        if !workouts.contains(where: { $0.id == workout.id }) {
            workouts.append(workout)
        }
        updateStats(with: workout)
        return true
    }

    /// Length of the unbroken run of training days that ends on the most
    /// recent training day in `dates`. Several workouts on one day count once.
    static func consecutiveTrainingDays(in dates: [Date], calendar: Calendar = .current) -> Int {
        let trainingDays = Set(dates.map { calendar.startOfDay(for: $0) })
        guard var day = trainingDays.max() else { return 0 }

        var length = 1
        while let previous = calendar.date(byAdding: .day, value: -1, to: day).map({ calendar.startOfDay(for: $0) }),
              previous < day,
              trainingDays.contains(previous) {
            length += 1
            day = previous
        }

        return length
    }

    // Recompute the streak from the registered workouts' own days rather than
    // counting up from the previous value. Counting incrementally drifted
    // whenever history changed out of order: a deleted workout left the old
    // number in place, and finishing an older-dated draft reset a live chain.
    private func updateWorkoutStreak(currentWorkout: Workout) {
        var trainingDates = workouts.map(\.date)
        if !workouts.contains(where: { $0 === currentWorkout }) {
            trainingDates.append(currentWorkout.date)
        }

        workoutStreak = Self.consecutiveTrainingDays(in: trainingDates)
    }

    /// The streak as the user should see it right now, derived from the
    /// registered workouts so it stays right after a workout is deleted. A
    /// chain only counts as current while it can still be extended — that
    /// is, while the most recent training day is today or yesterday.
    func currentWorkoutStreak(asOf now: Date = Date()) -> Int {
        let trainingDates = workouts.map(\.date)
        guard let latestWorkoutDate = trainingDates.max() else { return 0 }

        let calendar = Calendar.current
        let latestDay = calendar.startOfDay(for: latestWorkoutDate)
        let today = calendar.startOfDay(for: now)
        guard let dayGap = calendar.dateComponents([.day], from: latestDay, to: today).day,
              dayGap <= 1 else {
            return 0
        }

        return Self.consecutiveTrainingDays(in: trainingDates, calendar: calendar)
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
