//
//  Exercise.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import Foundation
import SwiftData

private enum ExerciseTextFormatter {
    static func collapsed(_ raw: String) -> String? {
        let collapsed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsed.isEmpty else {
            return nil
        }

        return collapsed
    }
}

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
    
    static func normalizedDisplayName(_ raw: String) -> String {
        let collapsedName = ExerciseTextFormatter.collapsed(raw) ?? "Exercise"
        return String(collapsedName.prefix(80))
    }

    static func normalizedDisplayInstructions(_ raw: String) -> String? {
        ExerciseTextFormatter.collapsed(raw)
    }

    var displayName: String {
        Self.normalizedDisplayName(name)
    }

    var primaryMuscleGroupSummary: String {
        primaryMuscleGroups.map(\.displayName).joined(separator: ", ")
    }

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
