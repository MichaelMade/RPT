//
//  WorkoutTemplate.swift
//  RPT
//
//  Created by Michael Moore on 4/28/25.
//

import Foundation
import SwiftData

@Model
final class WorkoutTemplate: Identifiable {
    @Attribute(.unique) var id: String
    var name: String
    var exercises: [TemplateExercise]
    var notes: String
    
    init(id: String = UUID().uuidString, name: String, exercises: [TemplateExercise] = [], notes: String = "") {
        self.id = id
        self.name = name
        self.exercises = exercises
        self.notes = notes
    }
}

// These are not SwiftData models but structs that will be encoded/decoded
struct TemplateExercise: Codable, Hashable, Identifiable {
    var id = UUID()
    var exerciseName: String
    var suggestedSets: Int
    var repRanges: [TemplateRepRange]
    var notes: String
    
    // Custom initializer to ensure suggestedSets and repRanges are in sync
    init(id: UUID = UUID(), exerciseName: String, suggestedSets: Int, repRanges: [TemplateRepRange], notes: String = "") {
        let normalizedSets = max(0, suggestedSets)
        self.id = id
        self.exerciseName = exerciseName
        self.suggestedSets = normalizedSets
        self.notes = notes

        guard normalizedSets > 0 else {
            self.repRanges = []
            return
        }

        var filteredRanges = repRanges.filter { $0.setNumber <= normalizedSets }

        for setNum in 1...normalizedSets where !filteredRanges.contains(where: { $0.setNumber == setNum }) {
            let percentageOfFirstSet = setNum == 1 ? 1.0 : max(1.0 - (Double(setNum - 1) * 0.1), 0.5)
            let baseMinReps = 6 + ((setNum - 1) * 2)
            let baseMaxReps = 8 + ((setNum - 1) * 2)

            filteredRanges.append(TemplateRepRange(
                setNumber: setNum,
                minReps: min(baseMinReps, 15),
                maxReps: min(baseMaxReps, 20),
                percentageOfFirstSet: percentageOfFirstSet
            ))
        }

        self.repRanges = filteredRanges
    }
    
    static func == (lhs: TemplateExercise, rhs: TemplateExercise) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct TemplateRepRange: Codable, Hashable {
    var setNumber: Int
    var minReps: Int
    var maxReps: Int
    var percentageOfFirstSet: Double? // For RPT calculations
}
