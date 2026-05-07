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
    enum MutationResult: Equatable {
        case success
        case missingName
        case noExercises
        case duplicateName
        case duplicateExercise
        case persistenceFailure

        var alertTitle: String {
            switch self {
            case .missingName:
                return "Template Name Required"
            case .noExercises:
                return "Add an Exercise First"
            case .duplicateName:
                return "Template Already Exists"
            case .duplicateExercise:
                return "Duplicate Exercise in Template"
            case .persistenceFailure, .success:
                return "Unable to Save Template"
            }
        }

        var alertMessage: String {
            switch self {
            case .missingName:
                return "Enter a template name before saving this workout plan."
            case .noExercises:
                return "Add at least one exercise before saving this template."
            case .duplicateName:
                return "A template with this name already exists. Please choose a different name."
            case .duplicateExercise:
                return "Each exercise can only appear once in a template. Remove or replace the duplicate entry before saving."
            case .persistenceFailure:
                return "Your template changes could not be saved right now. Please try again."
            case .success:
                return ""
            }
        }
    }

    enum DeletionResult: Equatable {
        case success
        case persistenceFailure

        var alertTitle: String {
            switch self {
            case .success:
                return ""
            case .persistenceFailure:
                return "Unable to Delete Template"
            }
        }

        var alertMessage: String {
            switch self {
            case .success:
                return ""
            case .persistenceFailure:
                return "This template could not be deleted right now. Please try again."
            }
        }
    }

    enum DraftValidationResult: Equatable {
        case valid
        case missingName
        case noExercises
        case duplicateName
        case duplicateExercise

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
            case .duplicateExercise:
                return "Each exercise can only appear once in a template. Remove or replace the duplicate entry to save."
            }
        }
    }

    private let dataManager: DataManaging
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

    static func hasDuplicateExerciseNames(_ exercises: [TemplateExercise]) -> Bool {
        var seen = Set<String>()

        for exercise in exercises {
            let lookupKey = ExerciseManager.normalizedNameLookupKey(exercise.exerciseName)
            if !seen.insert(lookupKey).inserted {
                return true
            }
        }

        return false
    }

    init(
        dataManager: DataManaging = DataManager.shared,
        exerciseManager: ExerciseManager = ExerciseManager.shared,
        seedDefaultTemplates: Bool = true
    ) {
        self.dataManager = dataManager
        self.modelContext = dataManager.getModelContext()
        self.exerciseManager = exerciseManager

        if seedDefaultTemplates {
            createDefaultTemplatesIfNeeded()
        }
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

    func unavailableExerciseNames(in template: WorkoutTemplate) -> [String] {
        var seenMissingExercises = Set<String>()

        return template.exercises.compactMap { templateExercise in
            let normalizedExerciseName = ExerciseManager.normalizedNameLookupKey(templateExercise.exerciseName)

            guard exerciseManager.fetchExercise(withName: templateExercise.exerciseName) == nil,
                  seenMissingExercises.insert(normalizedExerciseName).inserted else {
                return nil
            }

            return TemplateExercise.normalizedDisplayName(templateExercise.exerciseName)
        }
    }

    func availableExerciseCount(in template: WorkoutTemplate) -> Int {
        uniqueResolvableTemplateExercises(in: template).count
    }

    func startWorkoutActionTitle(for template: WorkoutTemplate) -> String {
        let availableCount = availableExerciseCount(in: template)
        let unavailableCount = unavailableExerciseNames(in: template).count

        guard unavailableCount > 0, availableCount > 0 else {
            return "Start Workout"
        }

        return "Start Partial Workout"
    }

    func partialStartConfirmationMessage(for template: WorkoutTemplate) -> String? {
        let unavailableExerciseNames = unavailableExerciseNames(in: template)
        let availableCount = availableExerciseCount(in: template)

        guard !unavailableExerciseNames.isEmpty, availableCount > 0 else {
            return nil
        }

        let skippedSummary: String
        if unavailableExerciseNames.count == 1 {
            skippedSummary = "1 template exercise will be skipped for now: \(unavailableExerciseNames[0])."
        } else {
            let previewNames = unavailableExerciseNames.prefix(3).joined(separator: ", ")
            let remainingCount = unavailableExerciseNames.count - min(unavailableExerciseNames.count, 3)
            let suffix = remainingCount > 0 ? ", and \(remainingCount) more" : ""
            skippedSummary = "\(unavailableExerciseNames.count) template exercises will be skipped for now: \(previewNames)\(suffix)."
        }

        let availableSummary = availableCount == 1
            ? "Start this workout with the remaining 1 available exercise?"
            : "Start this workout with the remaining \(availableCount) available exercises?"

        return "\(skippedSummary) \(availableSummary)"
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

        guard !Self.hasDuplicateExerciseNames(exercises) else {
            return .duplicateExercise
        }

        let duplicateExists = fetchAllTemplates().contains {
            $0.id != excludedTemplateId && Self.namesCollide($0.name, sanitizedName)
        }

        return duplicateExists ? .duplicateName : .valid
    }

    // MARK: - Mutation Operations

    @discardableResult
    func createTemplate(name: String, exercises: [TemplateExercise], notes: String = "") -> MutationResult {
        let validationResult = validateDraft(name: name, exercises: exercises)
        guard validationResult == .valid else {
            return mutationResult(for: validationResult)
        }

        let sanitizedName = Self.sanitizeTemplateName(name)

        let template = WorkoutTemplate(name: sanitizedName, exercises: exercises, notes: notes)
        modelContext.insert(template)

        do {
            try modelContext.save()
            return .success
        } catch {
            modelContext.delete(template)
            return .persistenceFailure
        }
    }

    @discardableResult
    func updateTemplate(_ template: WorkoutTemplate, name: String, exercises: [TemplateExercise], notes: String) -> MutationResult {
        let validationResult = validateDraft(name: name, exercises: exercises, excludingTemplateId: template.id)
        guard validationResult == .valid else {
            return mutationResult(for: validationResult)
        }

        let sanitizedName = Self.sanitizeTemplateName(name)
        let originalName = template.name
        let originalNotes = template.notes
        let originalExercises = template.exercises

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

        do {
            try modelContext.save()
            return .success
        } catch {
            template.name = originalName
            template.notes = originalNotes
            template.exercises = originalExercises
            return .persistenceFailure
        }
    }

    @discardableResult
    func deleteTemplate(_ template: WorkoutTemplate) -> DeletionResult {
        modelContext.delete(template)

        do {
            try dataManager.saveChanges()
            return .success
        } catch {
            modelContext.insert(template)
            return .persistenceFailure
        }
    }

    // MARK: - Workout Creation

    func createWorkoutFromTemplate(_ template: WorkoutTemplate) -> Workout? {
        // Create the workout with the template name
        let workout = Workout(name: template.name, startedFromTemplate: template.name)
        modelContext.insert(workout)
        var createdSetCount = 0

        // Get current date/time to stagger completion times slightly for ordering
        let now = Date()

        // Find exercises for template exercise names and add them to the workout.
        // If stale/imported data contains duplicate template exercises, keep the first
        // resolvable entry so starts stay deterministic instead of duplicating sections.
        for (index, resolvedTemplateExercise) in uniqueResolvableTemplateExercises(in: template).enumerated() {
            let templateExercise = resolvedTemplateExercise.templateExercise
            let exercise = resolvedTemplateExercise.exercise

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
                createdSetCount += 1
            }
        }

        guard createdSetCount > 0 else {
            modelContext.delete(workout)
            return nil
        }

        do {
            try modelContext.save()
            return workout
        } catch {
            modelContext.delete(workout)
            return nil
        }
    }

    // MARK: - Template Management

    @discardableResult
    func addExerciseToTemplate(_ template: WorkoutTemplate, exerciseName: String) -> Bool {
        let normalizedExerciseName = ExerciseManager.normalizedNameLookupKey(exerciseName)
        guard !template.exercises.contains(where: {
            ExerciseManager.normalizedNameLookupKey($0.exerciseName) == normalizedExerciseName
        }) else {
            return false
        }

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

        do {
            try dataManager.saveChanges()
            return true
        } catch {
            template.exercises.removeAll { $0.id == newExercise.id }
            return false
        }
    }

    @discardableResult
    func updateTemplateExercise(_ template: WorkoutTemplate, exerciseId: UUID, updatedExercise: TemplateExercise) -> Bool {
        guard let index = template.exercises.firstIndex(where: { $0.id == exerciseId }) else {
            return false
        }

        let originalExercise = template.exercises[index]
        template.exercises[index] = updatedExercise

        do {
            try dataManager.saveChanges()
            return true
        } catch {
            template.exercises[index] = originalExercise
            return false
        }
    }

    @discardableResult
    func removeExerciseFromTemplate(_ template: WorkoutTemplate, exerciseId: UUID) -> Bool {
        guard let index = template.exercises.firstIndex(where: { $0.id == exerciseId }) else {
            return false
        }

        let removedExercise = template.exercises.remove(at: index)

        do {
            try dataManager.saveChanges()
            return true
        } catch {
            template.exercises.insert(removedExercise, at: index)
            return false
        }
    }

    // MARK: - Private Helpers

    private func mutationResult(for validationResult: DraftValidationResult) -> MutationResult {
        switch validationResult {
        case .valid:
            return .success
        case .missingName:
            return .missingName
        case .noExercises:
            return .noExercises
        case .duplicateName:
            return .duplicateName
        case .duplicateExercise:
            return .duplicateExercise
        }
    }

    private func uniqueResolvableTemplateExercises(in template: WorkoutTemplate) -> [(templateExercise: TemplateExercise, exercise: Exercise)] {
        var seenExerciseNames = Set<String>()

        return template.exercises.compactMap { templateExercise in
            let normalizedExerciseName = ExerciseManager.normalizedNameLookupKey(templateExercise.exerciseName)

            guard seenExerciseNames.insert(normalizedExerciseName).inserted,
                  let exercise = exerciseManager.fetchExercise(withName: templateExercise.exerciseName) else {
                return nil
            }

            return (templateExercise: templateExercise, exercise: exercise)
        }
    }

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
