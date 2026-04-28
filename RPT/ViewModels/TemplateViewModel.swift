//
//  TemplateViewModel.swift
//  RPT
//
//  Created by Michael Moore on 4/28/25.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class TemplateViewModel: ObservableObject {
    private let templateManager: TemplateManager
    
    @Published var templates: [WorkoutTemplate] = []
    @Published var searchText = ""

    static func normalizedSearchQuery(_ rawQuery: String) -> String {
        rawQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    static func normalizedSearchLookupKey(_ rawValue: String) -> String {
        TemplateManager.normalizedNameLookupKey(normalizedSearchQuery(rawValue))
    }

    static func normalizedSearchTokens(_ rawValue: String) -> [String] {
        normalizedSearchLookupKey(rawValue)
            .split(separator: " ")
            .map(String.init)
    }

    var normalizedSearchText: String {
        Self.normalizedSearchQuery(searchText)
    }

    var hasActiveSearch: Bool {
        !normalizedSearchText.isEmpty
    }

    init(templateManager: TemplateManager? = nil) {
        self.templateManager = templateManager ?? TemplateManager.shared
        refreshTemplates()
    }
    
    func refreshTemplates() {
        templates = templateManager.fetchAllTemplates()
    }
    
    func clearSearch() {
        searchText = ""
    }

    func filteredResultsSummary(filteredCount: Int) -> String? {
        guard hasActiveSearch, !templates.isEmpty else {
            return nil
        }

        return "Showing \(filteredCount) of \(templates.count) templates for “\(normalizedSearchText)”"
    }

    static func searchMatchPriority(template: WorkoutTemplate, normalizedQuery: String) -> Int? {
        guard !normalizedQuery.isEmpty else {
            return 0
        }

        let normalizedName = normalizedSearchLookupKey(template.name)
        let queryTokens = normalizedSearchTokens(normalizedQuery)
        let nameWords = normalizedName.split(separator: " ")

        if normalizedName == normalizedQuery {
            return 0
        }

        if normalizedName.hasPrefix(normalizedQuery) {
            return 1
        }

        if !queryTokens.isEmpty,
           queryTokens.allSatisfy({ token in
               nameWords.contains(where: { $0.hasPrefix(token) })
           }) {
            return 2
        }

        if normalizedName.contains(normalizedQuery) {
            return 3
        }

        let normalizedExerciseNames = template.exercises
            .map(\.exerciseName)
            .map { normalizedSearchLookupKey($0) }

        if normalizedExerciseNames.contains(where: { $0 == normalizedQuery }) {
            return 4
        }

        if normalizedExerciseNames.contains(where: { $0.hasPrefix(normalizedQuery) }) {
            return 5
        }

        if normalizedExerciseNames.contains(where: { $0.contains(normalizedQuery) }) {
            return 6
        }

        let normalizedNotes = normalizedSearchLookupKey(template.notes)
        if !normalizedNotes.isEmpty, normalizedNotes.contains(normalizedQuery) {
            return 7
        }

        return nil
    }

    func fetchTemplates() -> [WorkoutTemplate] {
        let normalizedSearchLookup = Self.normalizedSearchLookupKey(normalizedSearchText)

        return templates
            .enumerated()
            .compactMap { index, template in
                let searchPriority = Self.searchMatchPriority(
                    template: template,
                    normalizedQuery: normalizedSearchLookup
                )

                guard normalizedSearchLookup.isEmpty || searchPriority != nil else {
                    return nil
                }

                return (
                    index: index,
                    template: template,
                    searchPriority: searchPriority ?? 0
                )
            }
            .sorted { lhs, rhs in
                if lhs.searchPriority != rhs.searchPriority {
                    return lhs.searchPriority < rhs.searchPriority
                }

                return lhs.index < rhs.index
            }
            .map(\.template)
    }
    
    @discardableResult
    func createTemplate(name: String, exercises: [TemplateExercise], notes: String = "") -> Bool {
        let didCreate = templateManager.createTemplate(name: name, exercises: exercises, notes: notes)
        if didCreate {
            refreshTemplates()
        }
        return didCreate
    }
    
    @discardableResult
    func updateTemplate(_ template: WorkoutTemplate, name: String, exercises: [TemplateExercise], notes: String) -> Bool {
        let didUpdate = templateManager.updateTemplate(template, name: name, exercises: exercises, notes: notes)
        if didUpdate {
            refreshTemplates()
        }
        return didUpdate
    }
    
    func deleteTemplate(_ template: WorkoutTemplate) {
        templateManager.deleteTemplate(template)
        refreshTemplates()
    }
    
    func createWorkoutFromTemplate(_ template: WorkoutTemplate) -> Workout {
        return templateManager.createWorkoutFromTemplate(template)
    }
    
    func addExerciseToTemplate(_ template: WorkoutTemplate, exerciseName: String) {
        templateManager.addExerciseToTemplate(template, exerciseName: exerciseName)
        refreshTemplates()
    }
    
    func updateTemplateExercise(_ template: WorkoutTemplate, exerciseId: UUID, updatedExercise: TemplateExercise) {
        templateManager.updateTemplateExercise(template, exerciseId: exerciseId, updatedExercise: updatedExercise)
        refreshTemplates()
    }
    
    func removeExerciseFromTemplate(_ template: WorkoutTemplate, exerciseId: UUID) {
        templateManager.removeExerciseFromTemplate(template, exerciseId: exerciseId)
        refreshTemplates()
    }
}
