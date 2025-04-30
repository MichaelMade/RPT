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
