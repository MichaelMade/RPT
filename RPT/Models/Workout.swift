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
        Dictionary(grouping: sets.sorted(by: { $0.completedAt < $1.completedAt }), by: { $0.exercise! })
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
    
    // Generate workout summary
    func generateSummary() -> String {
        let exerciseNames = Set(sets.compactMap { $0.exercise?.name })
        let exerciseList = exerciseNames.joined(separator: ", ")
        
        let volumeFormatted = String(format: "%.1f", totalVolume)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dateString = dateFormatter.string(from: date)
        
        var summary = "\(name) - \(dateString)\n"
        summary += "Exercises: \(exerciseList)\n"
        summary += "Sets: \(workingSetsCount)\n"
        summary += "Total Volume: \(volumeFormatted) lb\n"
        
        if !notes.isEmpty {
            summary += "Notes: \(notes)"
        }
        
        return summary
    }
    
    // Mark workout as completed
    func complete() {
        isCompleted = true
        
        // If duration hasn't been set, calculate it now
        if duration == 0 {
            duration = Date().timeIntervalSince(date)
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
        
        // Group previous workout's sets by exercise and find the best set
        for (exercise, exerciseSets) in exerciseGroups {
            // Skip warmup sets
            let workingSets = exerciseSets.filter { !$0.isWarmup }
            guard !workingSets.isEmpty else { continue }
            
            // Find the best weight for each set number
            let setsByNumber = Dictionary(grouping: workingSets) { $0.completedAt }
            let sortedSets = setsByNumber.values.sorted { $0[0].completedAt < $1[0].completedAt }
            
            // Create new sets with increased weights
            for (index, previousSets) in sortedSets.enumerated() {
                guard let previousSet = previousSets.first else { continue }
                
                // For RPT, we only increase the first set, others follow the percentage drop
                if index == 0 {
                    // Increase first set weight (convert to double for calculation, then round back to int)
                    let calculatedWeight = Double(previousSet.weight) * (1.0 + percentageIncrease)
                    let roundedWeight = Int(round(calculatedWeight / 5.0) * 5.0) // Round to nearest 5
                    
                    // Create the first set
                    _ = followUp.addSet(
                        exercise: exercise,
                        weight: roundedWeight,
                        reps: previousSet.reps,
                        isWarmup: false,
                        rpe: previousSet.rpe
                    )
                } else {
                    // For subsequent sets, maintain the same RPT percentage drop from the first set
                    guard let firstSetWeight = sortedSets.first?.first?.weight,
                          firstSetWeight > 0 else { continue }
                    
                    // Calculate the percentage drop from the first set in the original workout
                    let originalDropPercentage = 1.0 - (Double(previousSet.weight) / Double(firstSetWeight))
                    
                    // Apply the same percentage drop to the new first set weight
                    let newFirstSetWeight = followUp.exerciseGroups[exercise]?.first?.weight ?? 0
                    let calculatedWeight = Double(newFirstSetWeight) * (1.0 - originalDropPercentage)
                    let roundedWeight = Int(round(calculatedWeight / 5.0) * 5.0) // Round to nearest 5
                    
                    // Create the set
                    _ = followUp.addSet(
                        exercise: exercise,
                        weight: roundedWeight,
                        reps: previousSet.reps,
                        isWarmup: false,
                        rpe: previousSet.rpe
                    )
                }
            }
        }
        
        return followUp
    }
    
    // Format total volume with lb unit
    func formattedTotalVolume() -> String {
        let isWholeNumber = totalVolume.truncatingRemainder(dividingBy: 1) == 0
        return isWholeNumber ? "\(Int(totalVolume)) lb" : String(format: "%.1f lb", totalVolume)
    }
    
    // Generate workout summary
    func generateFormattedSummary() -> String {
        let exerciseNames = Set(sets.compactMap { $0.exercise?.name })
        let exerciseList = exerciseNames.joined(separator: ", ")
        
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
