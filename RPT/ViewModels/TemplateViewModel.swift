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

    static let searchPrompt = "Search templates, notes, exercises, body regions, or movement types"

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
                if normalized(templateExercise.notes).contains(query) { return true }

                guard let exercise = exerciseManager.fetchExercise(withName: templateExercise.exerciseName) else {
                    return false
                }

                let muscles = exercise.primaryMuscleGroups + exercise.secondaryMuscleGroups
                if muscles.contains(where: { normalized($0.displayName).contains(query) }) {
                    return true
                }

                if normalized(exercise.category.rawValue).contains(query) {
                    return true
                }

                return Self.bodyRegionSearchTerms(for: muscles).contains(where: { normalized($0).contains(query) })
            }
        }
    }

    func noMatchesDescription() -> String {
        "No template matches “\(searchText)”. Search by name, notes, exercise, muscle group, body region, or movement type."
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

    private static func bodyRegionSearchTerms(for muscleGroups: [MuscleGroup]) -> [String] {
        let uniqueGroups = Set(muscleGroups)
        var terms = Set<String>()

        let lowerBodyGroups: Set<MuscleGroup> = [.quadriceps, .hamstrings, .glutes, .calves]
        let upperBodyGroups: Set<MuscleGroup> = [.chest, .back, .shoulders, .biceps, .triceps, .forearms, .traps]
        let coreGroups: Set<MuscleGroup> = [.abs, .obliques, .lowerBack]
        let armGroups: Set<MuscleGroup> = [.biceps, .triceps, .forearms]

        let matchesLowerBody = !uniqueGroups.isDisjoint(with: lowerBodyGroups)
        let matchesUpperBody = !uniqueGroups.isDisjoint(with: upperBodyGroups)
        let matchesCore = !uniqueGroups.isDisjoint(with: coreGroups)

        if matchesLowerBody {
            terms.formUnion(["lower body", "leg", "legs"])
        }

        if matchesUpperBody {
            terms.insert("upper body")
        }

        if !uniqueGroups.isDisjoint(with: armGroups) {
            terms.formUnion(["arm", "arms"])
        }

        if matchesCore {
            terms.insert("core")
        }

        if (matchesUpperBody && matchesLowerBody) || (matchesCore && (matchesUpperBody || matchesLowerBody)) {
            terms.formUnion(["full body", "total body"])
        }

        return terms.sorted()
    }

    private func normalized(_ text: String) -> String {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
