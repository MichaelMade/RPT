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

    static func hasCompletedValues(weight: Int, reps: Int, exerciseCategory: ExerciseCategory? = nil) -> Bool {
        guard reps > 0 else {
            return false
        }

        guard weight >= 0 else {
            return false
        }

        if weight > 0 {
            return true
        }

        return exerciseCategory == .bodyweight
    }

    var hasCompletedValues: Bool {
        Self.hasCompletedValues(weight: weight, reps: reps, exerciseCategory: exercise?.category)
    }

    var isCompletedLoggedSet: Bool {
        hasCompletedValues && completedAt != .distantPast
    }

    var isCompletedWorkingSet: Bool {
        !isWarmup && isCompletedLoggedSet
    }

    static func sanitizedRPE(_ rpe: Int?) -> Int? {
        guard let rpe, (1...10).contains(rpe) else {
            return nil
        }

        return rpe
    }

    var displayRPE: Int? {
        Self.sanitizedRPE(rpe)
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

    static func formattedWeightReps(weight: Int, reps: Int, exerciseCategory: ExerciseCategory? = nil) -> String {
        let safeWeight = max(0, weight)
        let safeReps = max(0, reps)
        let repsText = safeReps == 1 ? "1 rep" : "\(safeReps) reps"

        if safeWeight == 0, exerciseCategory == .bodyweight {
            return "BW × \(repsText)"
        }

        return "\(safeWeight) lb × \(repsText)"
    }

    var formattedWeightReps: String {
        Self.formattedWeightReps(weight: weight, reps: reps, exerciseCategory: exercise?.category)
    }
}
