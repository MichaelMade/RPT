//
//  TemplateManager.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class TemplateManager {
    private let modelContext: ModelContext
    private let exerciseManager: ExerciseManager
    static let shared = TemplateManager()
    
    private init() {
        let dataManager = DataManager.shared
        self.modelContext = dataManager.getModelContext()
        self.exerciseManager = ExerciseManager.shared
        createDefaultTemplatesIfNeeded()
    }
    
    // MARK: - Fetch Operations
    
    func fetchAllTemplates() -> [WorkoutTemplate] {
        let descriptor = FetchDescriptor<WorkoutTemplate>(sortBy: [SortDescriptor(\.name)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func fetchTemplateByName(_ name: String) -> WorkoutTemplate? {
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate<WorkoutTemplate> { $0.name == name }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    func fetchTemplate(byId id: String) -> WorkoutTemplate? {
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate<WorkoutTemplate> { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    // MARK: - Mutation Operations
    
    func createTemplate(name: String, exercises: [TemplateExercise], notes: String = "") -> WorkoutTemplate {
        let template = WorkoutTemplate(name: name, exercises: exercises, notes: notes)
        modelContext.insert(template)
        try? modelContext.save()
        return template
    }
    
    func updateTemplate(_ template: WorkoutTemplate, name: String, exercises: [TemplateExercise], notes: String) {
        // Update the template properties
        template.name = name
        template.notes = notes
        
        // Force SwiftData to recognize the change by completely replacing the exercises array
        var updatedExercises: [TemplateExercise] = []
        
        // Create a fresh copy of each exercise to ensure all changes are captured
        for exercise in exercises {
            let newExercise = TemplateExercise(
                id: exercise.id,
                exerciseName: exercise.exerciseName,
                suggestedSets: exercise.suggestedSets,
                repRanges: exercise.repRanges,
                notes: exercise.notes
            )
            
            updatedExercises.append(newExercise)
        }
        
        // Replace the entire array to force SwiftData to detect the change
        template.exercises = []
        template.exercises = updatedExercises
        
        // Save the changes
        try? modelContext.save()
    }
    
    func deleteTemplate(_ template: WorkoutTemplate) {
        modelContext.delete(template)
        try? modelContext.save()
    }
    
    // MARK: - Workout Creation
    
func createWorkoutFromTemplate(_ template: WorkoutTemplate) -> Workout {
    // Create the workout with the template name
    let workout = Workout(name: template.name, startedFromTemplate: template.name)
    modelContext.insert(workout)
    
    // Get current date/time to stagger completion times slightly for ordering
    let now = Date()
    
    // Find exercises for template exercise names and add them to the workout
    // Process exercises in the order they appear in the template
    for (index, templateExercise) in template.exercises.enumerated() {
        // Find the actual exercise object
        guard let exercise = exerciseManager.fetchExercise(withName: templateExercise.exerciseName) else {
            continue
        }
        
        // Create sets based on rep ranges
        for (setIndex, repRange) in templateExercise.repRanges.sorted(by: { $0.setNumber < $1.setNumber }).enumerated() {
            // Use the middle of the rep range as the target
            let targetReps = (repRange.minReps + repRange.maxReps) / 2
            
            // Create a set with a slightly offset completedAt time to maintain order
            // This adds a small time offset for each exercise and each set within an exercise
            let completionTime = now.addingTimeInterval(Double(index) + (Double(setIndex) / 10.0))
            
            let newSet = ExerciseSet(
                weight: 0, // User will input actual weight during workout
                reps: targetReps,
                exercise: exercise,
                workout: workout,
                completedAt: completionTime
            )
            
            workout.sets.append(newSet)
        }
    }
    
    try? modelContext.save()
    return workout
}
    
    // MARK: - Template Management
    
    func addExerciseToTemplate(_ template: WorkoutTemplate, exerciseName: String) {
        // Create default template exercise with RPT pattern
        let newExercise = TemplateExercise(
            exerciseName: exerciseName,
            suggestedSets: 3,
            repRanges: [
                TemplateRepRange(setNumber: 1, minReps: 6, maxReps: 8, percentageOfFirstSet: 1.0),
                TemplateRepRange(setNumber: 2, minReps: 8, maxReps: 10, percentageOfFirstSet: 0.9),
                TemplateRepRange(setNumber: 3, minReps: 10, maxReps: 12, percentageOfFirstSet: 0.8)
            ],
            notes: ""
        )
        
        template.exercises.append(newExercise)
        try? modelContext.save()
    }
    
    func updateTemplateExercise(_ template: WorkoutTemplate, exerciseId: UUID, updatedExercise: TemplateExercise) {
        if let index = template.exercises.firstIndex(where: { $0.id == exerciseId }) {
            template.exercises[index] = updatedExercise
            try? modelContext.save()
        }
    }
    
    func removeExerciseFromTemplate(_ template: WorkoutTemplate, exerciseId: UUID) {
        template.exercises.removeAll { $0.id == exerciseId }
        try? modelContext.save()
    }
    
    // MARK: - Private Helpers
    
    private func createDefaultTemplatesIfNeeded() {
        var descriptor = FetchDescriptor<WorkoutTemplate>()
        descriptor.fetchLimit = 1
        
        // Check if any templates exist
        if let count = try? modelContext.fetchCount(descriptor), count > 0 {
            return // Templates already exist
        }
        
        // Create default template
        let upperBodyRPT = WorkoutTemplate(
            name: "Upper Body RPT",
            exercises: [
                TemplateExercise(
                    exerciseName: "Barbell Bench Press",
                    suggestedSets: 3,
                    repRanges: [
                        TemplateRepRange(setNumber: 1, minReps: 4, maxReps: 6, percentageOfFirstSet: 1.0),
                        TemplateRepRange(setNumber: 2, minReps: 6, maxReps: 8, percentageOfFirstSet: 0.9),
                        TemplateRepRange(setNumber: 3, minReps: 8, maxReps: 10, percentageOfFirstSet: 0.8)
                    ],
                    notes: "Focus on chest contraction"
                ),
                TemplateExercise(
                    exerciseName: "Pull-up",
                    suggestedSets: 3,
                    repRanges: [
                        TemplateRepRange(setNumber: 1, minReps: 6, maxReps: 8, percentageOfFirstSet: 1.0),
                        TemplateRepRange(setNumber: 2, minReps: 8, maxReps: 10, percentageOfFirstSet: 0.9),
                        TemplateRepRange(setNumber: 3, minReps: 10, maxReps: 12, percentageOfFirstSet: 0.8)
                    ],
                    notes: "Add weight if needed"
                )
            ],
            notes: "Rest 2-3 minutes between exercises"
        )
        
        // Insert template
        modelContext.insert(upperBodyRPT)
        try? modelContext.save()
    }
}
