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
    enum DraftValidationResult: Equatable {
        case valid
        case missingName
        case noExercises
        case duplicateName

        var helperText: String? {
            switch self {
            case .valid:
                return nil
            case .missingName:
                return "Enter a template name to save this workout plan."
            case .noExercises:
                return "Add at least one exercise before saving this template."
            case .duplicateName:
                return "A template with this name already exists. Choose a unique name to save."
            }
        }
    }

    private let modelContext: ModelContext
    private let exerciseManager: ExerciseManager
    static let shared = TemplateManager()

    static func sanitizeTemplateName(_ name: String) -> String {
        WorkoutTemplate.normalizedDisplayName(name)
    }

    private static let stableComparisonLocale = Locale(identifier: "en_US_POSIX")

    static func normalizedNameLookupKey(_ name: String, locale: Locale = stableComparisonLocale) -> String {
        sanitizeTemplateName(name)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: locale)
    }

    static func namesCollide(_ lhs: String, _ rhs: String) -> Bool {
        normalizedNameLookupKey(lhs) == normalizedNameLookupKey(rhs)
    }

    static func initialCompletedAt(weight: Int, reps: Int, fallbackDate: Date) -> Date {
        guard weight > 0, reps > 0 else {
            return .distantPast
        }

        return fallbackDate
    }

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

    func validateDraft(name: String, exercises: [TemplateExercise], excludingTemplateId excludedTemplateId: String? = nil) -> DraftValidationResult {
        let sanitizedName = Self.sanitizeTemplateName(name)
        let hasMeaningfulName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard hasMeaningfulName else {
            return .missingName
        }

        guard !exercises.isEmpty else {
            return .noExercises
        }

        let duplicateExists = fetchAllTemplates().contains {
            $0.id != excludedTemplateId && Self.namesCollide($0.name, sanitizedName)
        }

        return duplicateExists ? .duplicateName : .valid
    }

    // MARK: - Mutation Operations

    @discardableResult
    func createTemplate(name: String, exercises: [TemplateExercise], notes: String = "") -> Bool {
        guard validateDraft(name: name, exercises: exercises) == .valid else {
            return false
        }

        let sanitizedName = Self.sanitizeTemplateName(name)

        let template = WorkoutTemplate(name: sanitizedName, exercises: exercises, notes: notes)
        modelContext.insert(template)
        try? modelContext.save()
        return true
    }

    @discardableResult
    func updateTemplate(_ template: WorkoutTemplate, name: String, exercises: [TemplateExercise], notes: String) -> Bool {
        guard validateDraft(name: name, exercises: exercises, excludingTemplateId: template.id) == .valid else {
            return false
        }

        let sanitizedName = Self.sanitizeTemplateName(name)

        // Update the template properties
        template.name = sanitizedName
        template.notes = WorkoutTemplate.normalizedDisplayNotes(notes) ?? ""
        
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
        return true
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
            
            // Preserve deterministic set ordering while ensuring unstarted sets remain incomplete.
            let completionTime = now.addingTimeInterval(Double(index) + (Double(setIndex) / 10.0))
            let initialWeight = 0

            let newSet = ExerciseSet(
                weight: initialWeight, // User will input actual weight during workout
                reps: targetReps,
                exercise: exercise,
                workout: workout,
                completedAt: Self.initialCompletedAt(
                    weight: initialWeight,
                    reps: targetReps,
                    fallbackDate: completionTime
                )
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
