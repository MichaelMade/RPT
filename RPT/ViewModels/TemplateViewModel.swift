//
//  TemplateViewModel.swift
//  RPT
//
//  Template library state: list, straightforward search over names,
//  notes, exercises, and muscle groups, plus CRUD passthrough.
//

import Foundation
import SwiftUI

@MainActor
class TemplateViewModel: ObservableObject {
    @Published var templates: [WorkoutTemplate] = []
    @Published var searchText: String = ""

    private let templateManager: TemplateManager
    private let exerciseManager: ExerciseManager

    init(templateManager: TemplateManager? = nil, exerciseManager: ExerciseManager? = nil) {
        self.templateManager = templateManager ?? TemplateManager.shared
        self.exerciseManager = exerciseManager ?? ExerciseManager.shared
        refreshTemplates()
    }

    var filteredTemplates: [WorkoutTemplate] {
        let query = normalized(searchText)
        guard !query.isEmpty else { return templates }

        return templates.filter { template in
            if normalized(template.name).contains(query) { return true }
            if normalized(template.notes).contains(query) { return true }

            return template.exercises.contains { templateExercise in
                if normalized(templateExercise.exerciseName).contains(query) { return true }

                guard let exercise = exerciseManager.fetchExercise(withName: templateExercise.exerciseName) else {
                    return false
                }

                let muscles = exercise.primaryMuscleGroups + exercise.secondaryMuscleGroups
                return muscles.contains { normalized($0.displayName).contains(query) }
            }
        }
    }

    func refreshTemplates() {
        templates = templateManager.fetchAllTemplates()
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Template Actions

    func canStart(_ template: WorkoutTemplate) -> Bool {
        templateManager.canStartWorkout(for: template)
    }

    func missingExerciseNames(in template: WorkoutTemplate) -> [String] {
        templateManager.unavailableExerciseNames(in: template)
    }

    func createWorkout(from template: WorkoutTemplate) -> Workout? {
        templateManager.createWorkoutFromTemplate(template)
    }

    func deleteTemplate(_ template: WorkoutTemplate) -> Bool {
        let result = templateManager.deleteTemplate(template)
        refreshTemplates()
        return result == .success
    }

    func duplicateTemplate(_ template: WorkoutTemplate) -> Bool {
        let copyName = preferredDuplicateName(for: template.name)
        let result = templateManager.createTemplate(
            name: copyName,
            exercises: template.exercises.map { exercise in
                TemplateExercise(
                    exerciseName: exercise.exerciseName,
                    suggestedSets: exercise.suggestedSets,
                    repRanges: exercise.repRanges,
                    notes: exercise.notes
                )
            },
            notes: template.notes
        )
        refreshTemplates()
        return result == .success
    }

    /// "Upper A" → "Upper A Copy" → "Upper A Copy 2" → ...
    func preferredDuplicateName(for name: String) -> String {
        let displayName = WorkoutTemplate.normalizedDisplayName(name)

        // Strip an existing "Copy"/"Copy N" suffix so copies don't nest.
        let baseName: String
        if let range = displayName.range(of: #"\s+Copy(\s+\d+)?$"#, options: .regularExpression) {
            baseName = String(displayName[..<range.lowerBound])
        } else {
            baseName = displayName
        }

        let existingNames = Set(templates.map { TemplateManager.normalizedNameLookupKey($0.name) })

        let firstCandidate = "\(baseName) Copy"
        if !existingNames.contains(TemplateManager.normalizedNameLookupKey(firstCandidate)) {
            return firstCandidate
        }

        for index in 2...999 {
            let candidate = "\(baseName) Copy \(index)"
            if !existingNames.contains(TemplateManager.normalizedNameLookupKey(candidate)) {
                return candidate
            }
        }

        return "\(baseName) Copy"
    }

    // MARK: - Helpers

    private func normalized(_ text: String) -> String {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
