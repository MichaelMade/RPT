//
//  TemplateViewModel.swift
//  RPT
//
//  Template library state: list plus flexible search over names,
//  notes, exercises, muscles, instruction cues, and category aliases.
//

import Foundation
import SwiftUI

@MainActor
class TemplateViewModel: ObservableObject {
    @Published var templates: [WorkoutTemplate] = []
    @Published var searchText: String = ""

    static let searchPrompt = "Search templates, notes, exercises, custom moves, muscle groups, push/pull splits, set/rep plans, instruction cues, body regions, or movement types"

    private let templateManager: TemplateManager
    private let exerciseManager: ExerciseManager

    init(templateManager: TemplateManager? = nil, exerciseManager: ExerciseManager? = nil) {
        self.templateManager = templateManager ?? TemplateManager.shared
        self.exerciseManager = exerciseManager ?? ExerciseManager.shared
    }

    var filteredTemplates: [WorkoutTemplate] {
        let query = normalized(searchText)
        guard !query.isEmpty else { return templates }

        return templates.filter { template in
            let searchableText = templateSearchText(for: template)
            if searchableText.contains(query) {
                return true
            }

            return queryTerms(from: query).allSatisfy { searchableText.contains($0) }
        }
    }

    func noMatchesDescription() -> String {
        "No template matches “\(searchText)”. Search by name, notes, exercise, custom exercise, muscle group, push/pull split, set/rep plan, instruction cue, body region, or movement type."
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

    private func templateSearchText(for template: WorkoutTemplate) -> String {
        var terms = [template.name, template.notes]
        terms.append(contentsOf: ExerciseSearchAliases.compactSearchTerms(for: template.name))
        terms.append(contentsOf: ExerciseSearchAliases.compactSearchTerms(for: template.notes))

        for templateExercise in template.exercises {
            terms.append(templateExercise.exerciseName)
            terms.append(templateExercise.notes)
            terms.append(contentsOf: ExerciseSearchAliases.compactSearchTerms(for: templateExercise.exerciseName))
            terms.append(contentsOf: ExerciseSearchAliases.compactSearchTerms(for: templateExercise.notes))
            terms.append(contentsOf: Self.repPlanSearchTerms(for: templateExercise))

            guard let exercise = exerciseManager.fetchExercise(withName: templateExercise.exerciseName) else {
                continue
            }

            terms.append(exercise.instructions)
            terms.append(exercise.category.rawValue)
            terms.append(contentsOf: ExerciseSearchAliases.customTerms(isCustom: exercise.isCustom))
            terms.append(contentsOf: ExerciseSearchAliases.compactSearchTerms(for: exercise.instructions))

            let muscles = exercise.primaryMuscleGroups + exercise.secondaryMuscleGroups
            terms.append(contentsOf: muscles.map(\.displayName))
            terms.append(contentsOf: ExerciseSearchAliases.bodyRegionTerms(for: muscles))
        }

        return terms
            .map(normalized)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func repPlanSearchTerms(for templateExercise: TemplateExercise) -> [String] {
        let setCount = max(0, templateExercise.suggestedSets)
        guard setCount > 0 else {
            return []
        }

        var terms: Set<String> = [
            "\(setCount) set",
            "\(setCount) sets",
            "set count \(setCount)"
        ]

        let repRanges = templateExercise.repRanges.sorted(by: { $0.setNumber < $1.setNumber })
        if let firstRange = repRanges.first {
            terms.formUnion(repRangeSearchTerms(minReps: firstRange.minReps, maxReps: firstRange.maxReps).map { "top set \($0)" })

            for compactRange in compactRepRangeAliases(minReps: firstRange.minReps, maxReps: firstRange.maxReps) {
                terms.insert("\(setCount)x\(compactRange)")
                terms.insert("\(setCount) x \(compactRange)")
            }
        }

        for range in repRanges {
            // Plain range terms only ("8-10 reps"). Positional variants like
            // "set 3 8-10 reps" would leak bare set numbers into the search
            // text and make a "3 sets" query match any template with a third set.
            terms.formUnion(repRangeSearchTerms(minReps: range.minReps, maxReps: range.maxReps))
        }

        return terms.sorted()
    }

    private static func repRangeSearchTerms(minReps: Int, maxReps: Int) -> [String] {
        guard minReps > 0, maxReps >= minReps else {
            return []
        }

        if minReps == maxReps {
            return ["\(minReps) reps"]
        }

        return compactRepRangeAliases(minReps: minReps, maxReps: maxReps).map { "\($0) reps" }
    }

    private static func compactRepRangeAliases(minReps: Int, maxReps: Int) -> [String] {
        guard minReps > 0, maxReps >= minReps else {
            return []
        }

        if minReps == maxReps {
            return ["\(minReps)"]
        }

        return ["\(minReps)-\(maxReps)", "\(minReps)–\(maxReps)"]
    }

    private func queryTerms(from query: String) -> [String] {
        query
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func normalized(_ text: String) -> String {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
