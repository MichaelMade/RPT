//
//  Workout.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import Foundation
import SwiftData

@Model
final class Workout {
    var date: Date
    var name: String
    var notes: String
    var duration: TimeInterval
    var isCompleted: Bool
    var startedFromTemplate: String?
    
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workout)
    var sets: [ExerciseSet]
    
    @Relationship(deleteRule: .nullify)
    var user: User?
    
    init(
        date: Date = Date(),
        name: String = "Workout",
        notes: String = "",
        duration: TimeInterval = 0,
        isCompleted: Bool = false,
        startedFromTemplate: String? = nil
    ) {
        self.date = date
        self.name = name
        self.notes = notes
        self.duration = duration
        self.isCompleted = isCompleted
        self.startedFromTemplate = startedFromTemplate
        self.sets = []
    }
    
    // Calculate exercise count
    var exerciseCount: Int {
        Set(sets.compactMap { $0.exercise }).count
    }
    
    // Calculate total volume
    var totalVolume: Double {
        sets.reduce(0.0) { $0 + (Double($1.weight) * Double($1.reps)) }
    }
    
    // Calculate total working sets (non-warmup)
    var workingSetsCount: Int {
        sets.filter { !$0.isWarmup }.count
    }
    
    // Group sets by exercise
    var exerciseGroups: [Exercise: [ExerciseSet]] {
        let setsWithExercise = sets.compactMap { set -> (Exercise, ExerciseSet)? in
            guard let exercise = set.exercise else { return nil }
            return (exercise, set)
        }
        let sorted = setsWithExercise.sorted { $0.1.completedAt < $1.1.completedAt }
        return Dictionary(grouping: sorted, by: { $0.0 }).mapValues { $0.map { $0.1 } }
    }
    
    // Calculate best set for each exercise
    var bestSets: [Exercise: ExerciseSet] {
        var result: [Exercise: ExerciseSet] = [:]
        
        for (exercise, sets) in exerciseGroups {
            if let bestSet = sets.max(by: { $0.weight < $1.weight }) {
                result[exercise] = bestSet
            }
        }
        
        return result
    }
    
    // Mark workout as completed
    func complete() {
        isCompleted = true

        let safeDuration = duration.isFinite ? max(0, duration) : 0
        duration = safeDuration

        if duration == 0 {
            let rawDuration = Date().timeIntervalSince(date)
            duration = rawDuration.isFinite ? max(0, rawDuration) : 0
        }
    }
    
    // Add a new set to the workout
    func addSet(exercise: Exercise, weight: Int, reps: Int, isWarmup: Bool = false, rpe: Int? = nil) -> ExerciseSet {
        let newSet = ExerciseSet(
            weight: weight,
            reps: reps,
            exercise: exercise,
            workout: self,
            isWarmup: isWarmup,
            rpe: rpe
        )
        
        sets.append(newSet)
        return newSet
    }
    
    // Create a follow-up workout with the same exercises but increased weights
    func createFollowUpWorkout(percentageIncrease: Double = 0.025) -> Workout {
        let followUp = Workout(
            name: "Follow-up: \(name)",
            startedFromTemplate: startedFromTemplate
        )
        
        for (exercise, exerciseSets) in exerciseGroups {
            let workingSets = exerciseSets.filter { !$0.isWarmup }
            guard !workingSets.isEmpty else { continue }

            let sortedSets = workingSets.sorted { $0.completedAt < $1.completedAt }
            guard let originalFirstWeight = sortedSets.first?.weight, originalFirstWeight > 0 else { continue }

            var newFirstSetWeight = 0

            for (index, previousSet) in sortedSets.enumerated() {
                let roundedWeight: Int
                if index == 0 {
                    let calculatedWeight = Double(previousSet.weight) * (1.0 + percentageIncrease)
                    roundedWeight = Int(round(calculatedWeight / 5.0) * 5.0)
                    newFirstSetWeight = roundedWeight
                } else {
                    let dropPercentage = 1.0 - (Double(previousSet.weight) / Double(originalFirstWeight))
                    let calculatedWeight = Double(newFirstSetWeight) * (1.0 - dropPercentage)
                    roundedWeight = Int(round(calculatedWeight / 5.0) * 5.0)
                }

                _ = followUp.addSet(
                    exercise: exercise,
                    weight: roundedWeight,
                    reps: previousSet.reps,
                    isWarmup: false,
                    rpe: previousSet.rpe
                )
            }
        }

        return followUp
    }
    
    // Format total volume with lb unit
    func formattedTotalVolume() -> String {
        let safeTotalVolume = totalVolume.isFinite ? max(0, totalVolume) : 0
        let isWholeNumber = safeTotalVolume.truncatingRemainder(dividingBy: 1) == 0
        return isWholeNumber ? "\(Int(safeTotalVolume)) lb" : String(format: "%.1f lb", safeTotalVolume)
    }
    
    // Generate workout summary
    func generateFormattedSummary() -> String {
        let exerciseNames = Set(sets.compactMap { $0.exercise?.name })
        let exerciseList = exerciseNames.isEmpty
            ? "None"
            : exerciseNames.sorted().joined(separator: ", ")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dateString = dateFormatter.string(from: date)
        
        var summary = "\(name) - \(dateString)\n"
        summary += "Exercises: \(exerciseList)\n"
        summary += "Sets: \(workingSetsCount)\n"
        summary += "Total Volume: \(formattedTotalVolume())\n"
        
        if !notes.isEmpty {
            summary += "Notes: \(notes)"
        }
        
        return summary
    }
}
