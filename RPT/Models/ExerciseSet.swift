//
//  ExerciseSet.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import Foundation
import SwiftData

@Model
final class ExerciseSet {
    var weight: Int // Weight in pounds, rounded to nearest 5
    var reps: Int
    var completedAt: Date
    var isWarmup: Bool
    var rpe: Int? // Rate of Perceived Exertion (1-10)
    var notes: String
    
    @Relationship(deleteRule: .nullify)
    var exercise: Exercise?
    
    @Relationship(deleteRule: .nullify)
    var workout: Workout?
    
    init(weight: Int,
         reps: Int,
         exercise: Exercise,
         workout: Workout? = nil,
         completedAt: Date = Date(),
         isWarmup: Bool = false,
         rpe: Int? = nil,
         notes: String = "") {
        self.weight = weight
        self.reps = reps
        self.exercise = exercise
        self.workout = workout
        self.completedAt = completedAt
        self.isWarmup = isWarmup
        self.rpe = rpe
        self.notes = notes
    }

    static func hasCompletedValues(weight: Int, reps: Int) -> Bool {
        weight > 0 && reps > 0
    }

    var hasCompletedValues: Bool {
        Self.hasCompletedValues(weight: weight, reps: reps)
    }

    var isCompletedWorkingSet: Bool {
        !isWarmup && hasCompletedValues && completedAt != .distantPast
    }

    /// Returns true when this set should rank above another set for "best set" selection.
    /// Priority: heavier weight, then higher reps, then more recent completion.
    func isBetterPerformance(than other: ExerciseSet) -> Bool {
        if weight != other.weight {
            return weight > other.weight
        }

        if reps != other.reps {
            return reps > other.reps
        }

        return completedAt > other.completedAt
    }

    var formattedWeightReps: String {
        "\(weight) lb × \(reps)"
    }
}
