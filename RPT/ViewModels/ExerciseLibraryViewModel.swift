//
//  ExerciseLibraryViewModel.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class ExerciseLibraryViewModel: ObservableObject {
    enum EmptyStateKind {
        case emptyLibrary
        case noMatchingResults
    }

    enum SelectionContext {
        case workout
        case template

        var emptyLibraryDescription: String {
            switch self {
            case .workout:
                return "Add an exercise in the library first, then come back here to use it in a workout."
            case .template:
                return "Add an exercise in the library first, then come back here to use it in a template."
            }
        }

        var allSelectedDescription: String {
            switch self {
            case .workout:
                return "This workout already includes every exercise in your library. Add sets to an existing exercise or create a new custom movement to keep building it out."
            case .template:
                return "This template already includes every exercise in your library. Remove one from the template or add a new custom exercise to keep building it out."
            }
        }

        var allMatchingSelectedDescription: String {
            switch self {
            case .workout:
                return "This workout already includes every exercise in your current search or filter results. Clear your filters or add sets to an existing exercise instead."
            case .template:
                return "This template already includes every exercise in your current search or filter results. Clear your filters or remove one from the template to add it again."
            }
        }
    }

    private let exerciseManager: ExerciseManager
    
    @Published var searchText = ""
    @Published var selectedCategory: ExerciseCategory?
    @Published var selectedMuscleGroup: MuscleGroup?
    @Published var exercises: [Exercise] = []

    static func normalizedSearchQuery(_ rawQuery: String) -> String {
        rawQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    static func normalizedSearchLookupKey(_ rawValue: String) -> String {
        ExerciseManager.normalizedNameLookupKey(normalizedSearchQuery(rawValue))
    }

    static func normalizedSearchTokens(_ rawValue: String) -> [String] {
        normalizedSearchLookupKey(rawValue)
            .split(separator: " ")
            .map(String.init)
    }

    private static func normalizedSearchWords(_ rawValue: String) -> [String] {
        normalizedSearchLookupKey(rawValue)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static func compactedSearchLookupKey(_ rawValue: String) -> String {
        normalizedSearchWords(rawValue).joined()
    }

    private static func initialismLookupKey(_ rawValue: String) -> String {
        normalizedSearchWords(rawValue)
            .compactMap(\.first)
            .map(String.init)
            .joined()
    }

    private static func actionSearchAliases(
        for exercise: Exercise,
        includeSelectionAliases: Bool
    ) -> [String] {
        var aliases = ["Review \(exercise.displayName)"]

        if includeSelectionAliases {
            aliases.append(contentsOf: [
                "Add \(exercise.displayName)",
                "Select \(exercise.displayName)"
            ])
        }

        if exercise.isCustom {
            aliases.append(contentsOf: [
                "Edit \(exercise.displayName)",
                "Delete \(exercise.displayName)"
            ])
        }

        return aliases
    }

    var includeSelectionActionSearchAliases = false

    var normalizedSearchText: String {
        Self.normalizedSearchQuery(searchText)
    }

    var hasActiveSearch: Bool {
        !normalizedSearchText.isEmpty
    }

    var hasActiveFilters: Bool {
        selectedCategory != nil || selectedMuscleGroup != nil
    }

    var hasActiveQuery: Bool {
        hasActiveSearch || hasActiveFilters
    }
    
    init(exerciseManager: ExerciseManager? = nil) {
        self.exerciseManager = exerciseManager ?? ExerciseManager.shared
        refreshExercises()
    }
    
    func refreshExercises() {
        exercises = exerciseManager.fetchAllExercises()
    }

    func clearSearch() {
        searchText = ""
    }

    func clearFilters() {
        selectedCategory = nil
        selectedMuscleGroup = nil
    }

    func filteredResultsSummary(filteredCount: Int) -> String? {
        guard hasActiveQuery, !exercises.isEmpty else {
            return nil
        }

        var summary = "Showing \(filteredCount) of \(exercises.count) exercises"
        let qualifiers = resultsSummaryQualifiers()

        if !qualifiers.isEmpty {
            summary += " " + qualifiers.joined(separator: " • ")
        }

        return summary
    }

    func shouldShowResultsRecoveryActions(filteredCount: Int) -> Bool {
        hasActiveQuery && filteredCount > 0 && !exercises.isEmpty
    }

    func shouldShowSingleResultQuickActions(filteredCount: Int) -> Bool {
        filteredCount == 1 && !exercises.isEmpty
    }

    func singleSelectableExerciseActionTitle(for exercise: Exercise?) -> String? {
        guard !exercises.isEmpty,
              let exercise else {
            return nil
        }

        guard let displayName = exercise.specificDisplayName else {
            return "Add Exercise"
        }

        return "Add “\(displayName)”"
    }

    func reviewActionTitle(for exercise: Exercise?) -> String? {
        guard let exercise else {
            return nil
        }

        guard let displayName = exercise.specificDisplayName else {
            return "Review Exercise"
        }

        return "Review “\(displayName)”"
    }

    static func editScreenTitle(for exercise: Exercise?) -> String {
        guard let displayName = exercise?.specificDisplayName else {
            return "Edit Exercise"
        }

        return "Edit “\(displayName)”"
    }

    func editActionTitle(for exercise: Exercise?) -> String? {
        guard exercise != nil else {
            return nil
        }

        return Self.editScreenTitle(for: exercise)
    }

    func deleteActionTitle(for exercise: Exercise?) -> String? {
        guard let exercise else {
            return nil
        }

        guard let displayName = exercise.specificDisplayName else {
            return "Delete Exercise"
        }

        return "Delete “\(displayName)”"
    }

    func deleteAlertTitle(for exercise: Exercise?) -> String {
        guard let displayName = exercise?.specificDisplayName else {
            return "Delete Exercise?"
        }

        return "Delete “\(displayName)”?"
    }

    func deleteFailureAlertTitle(for exercise: Exercise?) -> String {
        guard let displayName = exercise?.specificDisplayName else {
            return ExerciseManager.DeletionResult.persistenceFailure.alertTitle
        }

        return "Couldn’t Delete “\(displayName)”"
    }

    func deleteFailureMessage(for exercise: Exercise?) -> String {
        guard let displayName = exercise?.specificDisplayName else {
            return ExerciseManager.DeletionResult.persistenceFailure.alertMessage
        }

        return "“\(displayName)” is still in your exercise library. Please try again."
    }

    func suggestedExerciseNameFromSearch() -> String? {
        guard hasActiveSearch else {
            return nil
        }

        let normalizedName = normalizedSearchText
        guard !normalizedName.isEmpty else {
            return nil
        }

        let normalizedLookup = ExerciseManager.normalizedNameLookupKey(normalizedName)
        let nameAlreadyExists = exercises.contains {
            ExerciseManager.normalizedNameLookupKey($0.name) == normalizedLookup
        }

        return nameAlreadyExists ? nil : normalizedName
    }

    func preferredNewExercisePrefillName() -> String {
        suggestedExerciseNameFromSearch() ?? ""
    }

    func preferredNewExerciseCategory() -> ExerciseCategory {
        selectedCategory ?? .compound
    }

    func preferredNewExercisePrimaryMuscles() -> [MuscleGroup] {
        guard let selectedMuscleGroup else {
            return []
        }

        return [selectedMuscleGroup]
    }

    func shouldShowCreateExerciseFromSearchAction(filteredCount: Int) -> Bool {
        hasActiveSearch && filteredCount > 0 && suggestedExerciseNameFromSearch() != nil
    }

    func createExerciseRecoveryTitle(filteredCount: Int) -> String? {
        let suggestedName: String?
        if filteredCount == 0 {
            suggestedName = suggestedExerciseNameFromSearch()
        } else {
            suggestedName = shouldShowCreateExerciseFromSearchAction(filteredCount: filteredCount)
                ? suggestedExerciseNameFromSearch()
                : nil
        }

        guard let suggestedName else {
            return nil
        }

        return "Add Custom Exercise “\(suggestedName)”"
    }

    func shouldShowGenericCreateExerciseAction(filteredCount: Int) -> Bool {
        guard filteredCount == 0 else {
            return false
        }

        switch emptyStateKind(filteredCount: filteredCount) {
        case .emptyLibrary:
            return true
        case .noMatchingResults:
            return hasActiveFilters && !hasActiveSearch
        case .none:
            return false
        }
    }

    func selectableResultsSummary(
        availableCount: Int,
        excludedCount: Int,
        exclusionContext: String = "template"
    ) -> String? {
        guard hasActiveQuery, !exercises.isEmpty else {
            return nil
        }

        var summary = "Showing \(availableCount) available of \(exercises.count) exercises"
        var qualifiers = resultsSummaryQualifiers()

        if excludedCount > 0 {
            qualifiers.append("\(excludedCount) already in \(exclusionContext)")
        }

        if !qualifiers.isEmpty {
            summary += " " + qualifiers.joined(separator: " • ")
        }

        return summary
    }

    private func resultsSummaryQualifiers() -> [String] {
        var qualifiers: [String] = []

        if hasActiveSearch {
            qualifiers.append("for “\(normalizedSearchText)”")
        }

        if let selectedCategory {
            qualifiers.append("in \(selectedCategory.rawValue.capitalized)")
        }

        if let selectedMuscleGroup {
            qualifiers.append("targeting \(selectedMuscleGroup.displayName)")
        }

        return qualifiers
    }

    func emptyStateKind(filteredCount: Int) -> EmptyStateKind? {
        guard filteredCount == 0 else {
            return nil
        }

        return exercises.isEmpty ? .emptyLibrary : .noMatchingResults
    }

    func emptyStateTitle(filteredCount: Int) -> String? {
        switch emptyStateKind(filteredCount: filteredCount) {
        case .emptyLibrary:
            return "No Exercises Yet"
        case .noMatchingResults:
            return "No Matching Exercises"
        case .none:
            return nil
        }
    }

    func emptyStateDescription(filteredCount: Int) -> String? {
        switch emptyStateKind(filteredCount: filteredCount) {
        case .emptyLibrary:
            return "Add your first custom exercise to start building your library."
        case .noMatchingResults:
            return "Try changing your search or filters, or clear them to see every exercise."
        case .none:
            return nil
        }
    }

    func selectionEmptyStateTitle(
        totalFetchedCount: Int,
        excludedCount: Int
    ) -> String {
        if totalFetchedCount > 0, excludedCount == totalFetchedCount {
            return hasActiveQuery
                ? "All Matching Exercises Already Added"
                : "All Exercises Already Added"
        }

        return exercises.isEmpty
            ? "No Exercises Available"
            : (hasActiveQuery ? "No Matching Exercises" : "No Exercises Available")
    }

    func selectionEmptyStateDescription(
        totalFetchedCount: Int,
        excludedCount: Int,
        context: SelectionContext
    ) -> String {
        if totalFetchedCount > 0, excludedCount == totalFetchedCount {
            return hasActiveQuery
                ? context.allMatchingSelectedDescription
                : context.allSelectedDescription
        }

        return exercises.isEmpty
            ? context.emptyLibraryDescription
            : "Try changing your search or filters, or clear them to browse every exercise."
    }

    static func searchMatchPriority(
        exercise: Exercise,
        normalizedQuery: String,
        includeSelectionActionAliases: Bool = false
    ) -> Int? {
        guard !normalizedQuery.isEmpty else {
            return 0
        }

        let normalizedName = normalizedSearchLookupKey(exercise.name)
        let compactedQuery = compactedSearchLookupKey(normalizedQuery)
        let initialismQuery = compactedQuery
        let queryTokens = normalizedSearchTokens(normalizedQuery)
        let words = normalizedName.split(separator: " ")

        if normalizedName == normalizedQuery {
            return 0
        }

        if normalizedName.hasPrefix(normalizedQuery) {
            return 1
        }

        if !queryTokens.isEmpty,
           queryTokens.allSatisfy({ token in
               words.contains(where: { $0.hasPrefix(token) })
           }) {
            return 2
        }

        let nameInitialism = initialismLookupKey(exercise.name)
        if !initialismQuery.isEmpty,
           !nameInitialism.isEmpty,
           nameInitialism.hasPrefix(initialismQuery) {
            return 3
        }

        let compactedName = compactedSearchLookupKey(exercise.name)
        if !compactedQuery.isEmpty,
           !compactedName.isEmpty {
            if compactedName == compactedQuery {
                return 4
            }

            if compactedName.hasPrefix(compactedQuery) {
                return 5
            }
        }

        if normalizedName.contains(normalizedQuery) {
            return 6
        }

        let aliasValues = [
            exercise.category.rawValue,
            exercise.category.rawValue.capitalized
        ]
        + exercise.primaryMuscleGroups.map(\.displayName)
        + exercise.secondaryMuscleGroups.map(\.displayName)
        + actionSearchAliases(
            for: exercise,
            includeSelectionAliases: includeSelectionActionAliases
        )

        let aliasLookups = aliasValues.map(normalizedSearchLookupKey)

        if aliasLookups.contains(normalizedQuery) {
            return 7
        }

        if aliasLookups.contains(where: { $0.hasPrefix(normalizedQuery) }) {
            return 8
        }

        if !queryTokens.isEmpty,
           aliasLookups.contains(where: { alias in
               let aliasWords = alias.split(separator: " ")
               return queryTokens.allSatisfy { token in
                   aliasWords.contains(where: { $0.hasPrefix(token) })
               }
           }) {
            return 9
        }

        if !initialismQuery.isEmpty,
           aliasValues.contains(where: {
               let aliasInitialism = initialismLookupKey($0)
               return !aliasInitialism.isEmpty && aliasInitialism.hasPrefix(initialismQuery)
           }) {
            return 10
        }

        if !compactedQuery.isEmpty,
           aliasValues.contains(where: {
               let compactedAlias = compactedSearchLookupKey($0)
               return !compactedAlias.isEmpty && compactedAlias.contains(compactedQuery)
           }) {
            return 11
        }

        if aliasLookups.contains(where: { $0.contains(normalizedQuery) }) {
            return 12
        }

        return nil
    }

    func fetchExercises() -> [Exercise] {
        let normalizedSearchText = normalizedSearchText
        let normalizedSearchLookup = Self.normalizedSearchLookupKey(normalizedSearchText)

        // Filter in memory based on search text and filters
        return exercises
            .enumerated()
            .compactMap { index, exercise in
                let searchPriority = Self.searchMatchPriority(
                    exercise: exercise,
                    normalizedQuery: normalizedSearchLookup,
                    includeSelectionActionAliases: includeSelectionActionSearchAliases
                )

                let matchesSearch = normalizedSearchLookup.isEmpty || searchPriority != nil

                // Apply category filter
                let matchesCategory = selectedCategory == nil ||
                                      exercise.category == selectedCategory

                // Apply muscle group filter
                let matchesMuscleGroup: Bool
                if let muscleGroup = selectedMuscleGroup {
                    matchesMuscleGroup = exercise.primaryMuscleGroups.contains(muscleGroup) ||
                                        exercise.secondaryMuscleGroups.contains(muscleGroup)
                } else {
                    matchesMuscleGroup = true
                }

                guard matchesSearch && matchesCategory && matchesMuscleGroup else {
                    return nil
                }

                return (
                    index: index,
                    exercise: exercise,
                    searchPriority: searchPriority ?? 0
                )
            }
            .sorted { lhs, rhs in
                if lhs.searchPriority != rhs.searchPriority {
                    return lhs.searchPriority < rhs.searchPriority
                }

                return lhs.index < rhs.index
            }
            .map(\.exercise)
    }
    
    @discardableResult
    func addExercise(name: String, category: ExerciseCategory, primaryMuscles: [MuscleGroup], secondaryMuscles: [MuscleGroup], instructions: String) -> ExerciseManager.MutationResult {
        let result = exerciseManager.addExercise(
            name: name,
            category: category,
            primaryMuscleGroups: primaryMuscles,
            secondaryMuscleGroups: secondaryMuscles,
            instructions: instructions
        )

        if result == .success {
            refreshExercises()
        }

        return result
    }
    
    @discardableResult
    func updateExercise(_ exercise: Exercise, name: String, category: ExerciseCategory, primaryMuscles: [MuscleGroup], secondaryMuscles: [MuscleGroup], instructions: String) -> ExerciseManager.MutationResult {
        let result = exerciseManager.updateExercise(
            exercise,
            name: name,
            category: category,
            primaryMuscleGroups: primaryMuscles,
            secondaryMuscleGroups: secondaryMuscles,
            instructions: instructions
        )

        if result == .success {
            refreshExercises()
        }

        return result
    }
    
    @discardableResult
    func deleteExercise(_ exercise: Exercise) -> ExerciseManager.DeletionResult {
        let result = exerciseManager.deleteExercise(exercise)

        if result == .success {
            refreshExercises()
        }

        return result
    }

    func deletionImpact(for exercise: Exercise) -> ExerciseManager.DeletionImpact {
        exerciseManager.deletionImpact(for: exercise)
    }

    static func deletionConfirmationMessage(
        for exercise: Exercise?,
        impact: ExerciseManager.DeletionImpact
    ) -> String {
        let targetDescription: String
        if let displayName = exercise?.specificDisplayName {
            targetDescription = "Deleting “\(displayName)”"
        } else {
            targetDescription = "Deleting this exercise"
        }

        guard impact.hasImpactDetails else {
            return "\(targetDescription) cannot be undone."
        }

        var sentences: [String] = []

        if impact.loggedSetCount > 0 {
            let setLabel = impact.loggedSetCount == 1 ? "logged set" : "logged sets"
            let workoutLabel = impact.workoutCount == 1 ? "workout" : "workouts"
            sentences.append("\(targetDescription) will remove \(impact.loggedSetCount) \(setLabel) from \(impact.workoutCount) \(workoutLabel)")
        }

        if impact.templateCount > 0 {
            let templateLabel = impact.templateCount == 1 ? "template" : "templates"
            let referenceVerb = impact.templateCount == 1 ? "references" : "reference"
            sentences.append("\(impact.templateCount) \(templateLabel) still \(referenceVerb) it and will skip it when started until you replace or remove it")
        }

        return sentences.joined(separator: ". ") + "."
    }
}
