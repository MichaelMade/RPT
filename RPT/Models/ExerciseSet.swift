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
    var weight: Double
    var reps: Int
    var completedAt: Date
    var isWarmup: Bool
    var rpe: Int? // Rate of Perceived Exertion (1-10)
    var notes: String
    
    @Relationship(deleteRule: .nullify)
    var exercise: Exercise?
    
    @Relationship(deleteRule: .nullify)
    var workout: Workout?
    
    init(weight: Double,
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
}
