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
    enum ActiveWorkoutPersistenceAction {
        case saveForLater
        case discard
    }

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

    private static func normalizedSearchWords(_ rawValue: String) -> [String] {
        normalizedSearchLookupKey(rawValue)
            .split(separator: " ")
            .map(String.init)
    }

    private static func compactedSearchLookupKey(_ rawValue: String) -> String {
        normalizedSearchLookupKey(rawValue)
            .replacingOccurrences(of: " ", with: "")
    }

    private static func matchesQueryTokens(_ queryTokens: [String], in rawValue: String) -> Bool {
        guard !queryTokens.isEmpty else {
            return false
        }

        let words = normalizedSearchWords(rawValue)
        guard !words.isEmpty else {
            return false
        }

        return queryTokens.allSatisfy { token in
            words.contains(where: { $0.hasPrefix(token) })
        }
    }

    private static func compactedMatchPriority(query: String, in rawValue: String) -> Int? {
        guard !query.isEmpty else {
            return nil
        }

        let compactedValue = compactedSearchLookupKey(rawValue)
        guard !compactedValue.isEmpty else {
            return nil
        }

        if compactedValue == query {
            return 0
        }

        if compactedValue.hasPrefix(query) {
            return 1
        }

        if compactedValue.contains(query) {
            return 2
        }

        return nil
    }

    private static func searchTermMatchPriority(
        query: String,
        queryTokens: [String],
        compactedQuery: String,
        in searchTerms: [String]
    ) -> Int? {
        let normalizedTerms = searchTerms
            .map(normalizedSearchLookupKey)
            .filter { !$0.isEmpty }

        guard !normalizedTerms.isEmpty else {
            return nil
        }

        if normalizedTerms.contains(query) {
            return 0
        }

        if normalizedTerms.contains(where: { $0.hasPrefix(query) }) {
            return 1
        }

        if normalizedTerms.contains(where: { matchesQueryTokens(queryTokens, in: $0) }) {
            return 2
        }

        if normalizedTerms.contains(where: { compactedMatchPriority(query: compactedQuery, in: $0) != nil }) {
            return 3
        }

        if normalizedTerms.contains(where: { $0.contains(query) }) {
            return 4
        }

        return nil
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

    func shouldShowResultsRecoveryActions(filteredCount: Int) -> Bool {
        hasActiveSearch && filteredCount > 0 && !templates.isEmpty
    }

    func persistActiveWorkoutBeforeTemplateStart(
        _ workout: Workout,
        action: ActiveWorkoutPersistenceAction,
        persist: (Workout) -> Bool
    ) -> Bool {
        guard persist(workout) else {
            return false
        }

        switch action {
        case .saveForLater:
            WorkoutStateManager.shared.markWorkoutAsSaved(workout.id)
        case .discard:
            WorkoutStateManager.shared.markWorkoutAsDiscarded(workout.id)
        }

        return true
    }

    func activeWorkoutPromptPrefix(for workout: Workout) -> String {
        let displayName = WorkoutRow.displayName(for: workout)
        return displayName == "Workout"
            ? "You already have a workout in progress."
            : "You already have \(displayName) in progress."
    }

    func activeWorkoutPromptMessage(for workout: Workout, opening template: WorkoutTemplate) -> String {
        let templateName = WorkoutTemplate.normalizedDisplayName(template.name)
        let templateSuffix = templateName == "Template"
            ? "before opening this template."
            : "before opening \(templateName)."

        return "\(activeWorkoutPromptPrefix(for: workout)) Save it for later, discard it, or keep going \(templateSuffix)"
    }

    func activeWorkoutPersistenceFailureMessage(for action: ActiveWorkoutPersistenceAction) -> String {
        switch action {
        case .saveForLater:
            return "Couldn’t save the current workout. Keep it open, then try starting from the template again."
        case .discard:
            return "Couldn’t discard the current workout. Keep it open, then try starting from the template again."
        }
    }

    static func searchMatchPriority(template: WorkoutTemplate, normalizedQuery: String) -> Int? {
        guard !normalizedQuery.isEmpty else {
            return 0
        }

        let normalizedName = normalizedSearchLookupKey(template.name)
        let compactedQuery = compactedSearchLookupKey(normalizedQuery)
        let queryTokens = normalizedSearchTokens(normalizedQuery)

        if normalizedName == normalizedQuery {
            return 0
        }

        if normalizedName.hasPrefix(normalizedQuery) {
            return 1
        }

        if matchesQueryTokens(queryTokens, in: template.name) {
            return 2
        }

        if let compactedNamePriority = compactedMatchPriority(query: compactedQuery, in: template.name) {
            return 3 + compactedNamePriority
        }

        if normalizedName.contains(normalizedQuery) {
            return 6
        }

        let exerciseNames = template.exercises.map(\.exerciseName)
        let normalizedExerciseNames = exerciseNames.map { normalizedSearchLookupKey($0) }

        if normalizedExerciseNames.contains(where: { $0 == normalizedQuery }) {
            return 7
        }

        if normalizedExerciseNames.contains(where: { $0.hasPrefix(normalizedQuery) }) {
            return 8
        }

        if exerciseNames.contains(where: { matchesQueryTokens(queryTokens, in: $0) }) {
            return 9
        }

        if exerciseNames.contains(where: { compactedMatchPriority(query: compactedQuery, in: $0) != nil }) {
            return 10
        }

        if normalizedExerciseNames.contains(where: { $0.contains(normalizedQuery) }) {
            return 11
        }

        let normalizedNotes = normalizedSearchLookupKey(template.notes)
        if !normalizedNotes.isEmpty, normalizedNotes == normalizedQuery {
            return 12
        }

        if !normalizedNotes.isEmpty, normalizedNotes.hasPrefix(normalizedQuery) {
            return 13
        }

        if matchesQueryTokens(queryTokens, in: template.notes) {
            return 14
        }

        if compactedMatchPriority(query: compactedQuery, in: template.notes) != nil {
            return 15
        }

        if !normalizedNotes.isEmpty, normalizedNotes.contains(normalizedQuery) {
            return 16
        }

        return nil
    }

    private func issueSearchTerms(for template: WorkoutTemplate) -> [String] {
        let unavailableCount = templateManager.unavailableExerciseNames(in: template).count
        let duplicateCount = templateManager.duplicateExerciseNames(in: template).count
        let availableCount = templateManager.availableExerciseCount(in: template)

        var terms: [String] = []

        if availableCount > 0 {
            terms.append(contentsOf: [
                "ready",
                "ready to start",
                "available",
                "available exercises"
            ])
        }

        if unavailableCount > 0 {
            terms.append(contentsOf: [
                "missing",
                "unavailable",
                "missing exercises",
                "unavailable exercises",
                "skipped",
                "skip"
            ])

            if availableCount > 0 {
                terms.append(contentsOf: [
                    "partial",
                    "partial workout",
                    "skipped exercises"
                ])
            } else {
                terms.append(contentsOf: [
                    "blocked",
                    "cannot start",
                    "can't start",
                    "cant start",
                    "not ready"
                ])
            }
        }

        if duplicateCount > 0 {
            terms.append(contentsOf: [
                "repeated",
                "duplicate",
                "repeated entries",
                "duplicate exercises"
            ])
        }

        return terms
    }

    private func searchMatchPriority(template: WorkoutTemplate, normalizedQuery: String) -> Int? {
        if let basePriority = Self.searchMatchPriority(template: template, normalizedQuery: normalizedQuery) {
            return basePriority
        }

        let queryTokens = Self.normalizedSearchTokens(normalizedQuery)
        let compactedQuery = Self.compactedSearchLookupKey(normalizedQuery)

        if let issuePriority = Self.searchTermMatchPriority(
            query: normalizedQuery,
            queryTokens: queryTokens,
            compactedQuery: compactedQuery,
            in: issueSearchTerms(for: template)
        ) {
            return 17 + issuePriority
        }

        return nil
    }

    func fetchTemplates() -> [WorkoutTemplate] {
        let normalizedSearchLookup = Self.normalizedSearchLookupKey(normalizedSearchText)

        return templates
            .enumerated()
            .compactMap { index, template in
                let searchPriority = searchMatchPriority(
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
        let result = templateManager.createTemplate(name: name, exercises: exercises, notes: notes)
        if result == .success {
            refreshTemplates()
            return true
        }
        return false
    }
    
    @discardableResult
    func updateTemplate(_ template: WorkoutTemplate, name: String, exercises: [TemplateExercise], notes: String) -> Bool {
        let result = templateManager.updateTemplate(template, name: name, exercises: exercises, notes: notes)
        if result == .success {
            refreshTemplates()
            return true
        }
        return false
    }
    
    @discardableResult
    func deleteTemplate(_ template: WorkoutTemplate) -> TemplateManager.DeletionResult {
        let result = templateManager.deleteTemplate(template)

        if result == .success {
            refreshTemplates()
        }

        return result
    }
    
    func createWorkoutFromTemplate(_ template: WorkoutTemplate) -> Workout? {
        templateManager.createWorkoutFromTemplate(template)
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
