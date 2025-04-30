//
//  Exercise.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import Foundation
import SwiftData

@Model
final class Exercise {
    var name: String
    var category: ExerciseCategory
    var primaryMuscleGroups: [MuscleGroup]
    var secondaryMuscleGroups: [MuscleGroup]
    var instructions: String
    var isCustom: Bool
    
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.exercise)
    var sets: [ExerciseSet]
    
    init(name: String,
         category: ExerciseCategory,
         primaryMuscleGroups: [MuscleGroup],
         secondaryMuscleGroups: [MuscleGroup] = [],
         instructions: String = "",
         isCustom: Bool = false) {
        self.name = name
        self.category = category
        self.primaryMuscleGroups = primaryMuscleGroups
        self.secondaryMuscleGroups = secondaryMuscleGroups
        self.instructions = instructions
        self.isCustom = isCustom
        self.sets = []
    }
}
