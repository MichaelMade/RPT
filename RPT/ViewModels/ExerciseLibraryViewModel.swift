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

    private static let conversationalSearchLeadInPrefixes = [
        "please ",
        "can you ",
        "could you ",
        "would you ",
        "will you ",
        "help me ",
        "show me ",
        "take me to ",
        "bring me to "
    ]

    private static let conversationalSearchTrailingPhrases = [
        " thank you",
        " thanks",
        " please",
        " for me"
    ]

    private static let genericTrailingSearchSuffixes = [
        " exercise",
        " exercises",
        " movement",
        " movements",
        " lift",
        " lifts"
    ]

    private static let genericSearchEntityPrefixes = [
        "exercise ",
        "exercises ",
        "movement ",
        "movements ",
        "lift ",
        "lifts "
    ]

    private static let searchObjectLeadInPrefixes = [
        "the ",
        "my ",
        "this ",
        "that ",
        "these ",
        "those ",
        "a ",
        "an ",
        "called ",
        "named "
    ]

    private static let searchBridgeLeadInPrefixes = [
        "for "
    ]

    private static let genericExercisePrefillLookupKeys: Set<String> = [
        "exercise",
        "exercises",
        "movement",
        "movements",
        "lift",
        "lifts",
        "custom exercise",
        "custom movement",
        "custom lift"
    ]

    private static let searchIntentPrefillPrefixes = [
        "search for exercise ",
        "search for exercises ",
        "search for movement ",
        "search for movements ",
        "search for lift ",
        "search for lifts ",
        "find exercise ",
        "find exercises ",
        "find movement ",
        "find movements ",
        "find lift ",
        "find lifts ",
        "find me exercise ",
        "find me exercises ",
        "find me movement ",
        "find me movements ",
        "find me lift ",
        "find me lifts ",
        "looking for exercise ",
        "looking for exercises ",
        "looking for movement ",
        "looking for movements ",
        "looking for lift ",
        "looking for lifts ",
        "look up exercise ",
        "look up exercises ",
        "look up movement ",
        "look up movements ",
        "look up lift ",
        "look up lifts ",
        "lookup exercise ",
        "lookup exercises ",
        "lookup movement ",
        "lookup movements ",
        "lookup lift ",
        "lookup lifts ",
        "open exercise ",
        "open exercises ",
        "open movement ",
        "open movements ",
        "open lift ",
        "open lifts ",
        "review exercise ",
        "review exercises ",
        "review movement ",
        "review movements ",
        "review lift ",
        "review lifts ",
        "show exercise ",
        "show exercises ",
        "show movement ",
        "show movements ",
        "show lift ",
        "show lifts ",
        "browse exercise ",
        "browse exercises ",
        "browse movement ",
        "browse movements ",
        "browse lift ",
        "browse lifts ",
        "check out exercise ",
        "check out exercises ",
        "check out movement ",
        "check out movements ",
        "check out lift ",
        "check out lifts ",
        "check exercise ",
        "check exercises ",
        "check movement ",
        "check movements ",
        "check lift ",
        "check lifts ",
        "edit exercise ",
        "edit movement ",
        "edit lift ",
        "delete exercise ",
        "delete movement ",
        "delete lift ",
        "add exercise ",
        "add exercises ",
        "add movement ",
        "add movements ",
        "add lift ",
        "add lifts ",
        "select exercise ",
        "select movement ",
        "select lift ",
        "choose exercise ",
        "choose movement ",
        "choose lift ",
        "pick exercise ",
        "pick movement ",
        "pick lift ",
        "use exercise ",
        "use movement ",
        "use lift ",
        "search for ",
        "find me ",
        "find ",
        "looking for ",
        "look up ",
        "lookup ",
        "open ",
        "review ",
        "show ",
        "browse ",
        "check out ",
        "check ",
        "edit ",
        "delete ",
        "add ",
        "select ",
        "choose ",
        "pick ",
        "use "
    ]

    private static func strippedPrefix(_ normalizedQuery: String, prefixes: [String]) -> String? {
        let lowercasedQuery = normalizedQuery.lowercased()

        for prefix in prefixes {
            guard lowercasedQuery.hasPrefix(prefix) else {
                continue
            }

            let strippedQuery = String(normalizedQuery.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !strippedQuery.isEmpty {
                return strippedQuery
            }
        }

        return nil
    }

    private static func strippedSuffix(_ normalizedQuery: String, suffixes: [String]) -> String? {
        let lowercasedQuery = normalizedQuery.lowercased()

        for suffix in suffixes {
            guard lowercasedQuery.hasSuffix(suffix) else {
                continue
            }

            let strippedQuery = String(normalizedQuery.dropLast(suffix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !strippedQuery.isEmpty {
                return strippedQuery
            }
        }

        return nil
    }

    private static func strippedGenericTrailingSearchSuffix(_ normalizedQuery: String) -> String? {
        strippedSuffix(normalizedQuery, suffixes: genericTrailingSearchSuffixes)
    }

    private static func strippedGenericSearchEntityPrefix(_ normalizedQuery: String) -> String? {
        strippedPrefix(normalizedQuery, prefixes: genericSearchEntityPrefixes)
    }

    private static func strippedSearchObjectLeadIn(_ normalizedQuery: String) -> String? {
        strippedPrefix(normalizedQuery, prefixes: searchObjectLeadInPrefixes)
    }

    private static func strippedSearchBridgeLeadIn(_ normalizedQuery: String) -> String? {
        strippedPrefix(normalizedQuery, prefixes: searchBridgeLeadInPrefixes)
    }

    private static func sanitizedSearchVariants(for normalizedQuery: String) -> [String] {
        guard !normalizedQuery.isEmpty else {
            return []
        }

        var variants: [String] = []
        var seen = Set<String>()
        var queue = [normalizedQuery]

        while !queue.isEmpty {
            let candidate = queue.removeFirst()
            guard seen.insert(candidate).inserted else {
                continue
            }

            variants.append(candidate)

            let strippedCandidates = [
                strippedPrefix(candidate, prefixes: conversationalSearchLeadInPrefixes),
                strippedPrefix(candidate, prefixes: searchIntentPrefillPrefixes),
                strippedSuffix(candidate, suffixes: conversationalSearchTrailingPhrases),
                strippedGenericTrailingSearchSuffix(candidate),
                strippedGenericSearchEntityPrefix(candidate),
                strippedSearchObjectLeadIn(candidate),
                strippedSearchBridgeLeadIn(candidate)
            ]

            for strippedCandidate in strippedCandidates.compactMap({ $0 }) where !seen.contains(strippedCandidate) {
                queue.append(strippedCandidate)
            }
        }

        return variants
    }

    private static func sanitizedSuggestedExerciseName(_ normalizedName: String) -> String {
        sanitizedSearchVariants(for: normalizedName)
            .min(by: {
                if $0.count != $1.count {
                    return $0.count < $1.count
                }

                return $0 < $1
            }) ?? normalizedName
    }

    private static func searchQueryVariants(for normalizedQuery: String) -> [String] {
        sanitizedSearchVariants(for: normalizedQuery)
    }

    private static func initialismLookupKey(_ rawValue: String) -> String {
        normalizedSearchWords(rawValue)
            .compactMap(\.first)
            .map(String.init)
            .joined()
    }

    private static func bodyRegionSearchTerms(
        primaryMuscleGroups: [MuscleGroup],
        secondaryMuscleGroups: [MuscleGroup]
    ) -> [String] {
        let muscleGroups = Set(primaryMuscleGroups + secondaryMuscleGroups)
        var terms = Set<String>()

        let lowerBodyGroups: Set<MuscleGroup> = [.quadriceps, .hamstrings, .glutes, .calves]
        if !muscleGroups.isDisjoint(with: lowerBodyGroups) {
            terms.formUnion(["lower body", "leg", "legs"])
        }

        let upperBodyGroups: Set<MuscleGroup> = [.chest, .back, .shoulders, .biceps, .triceps, .forearms, .traps]
        if !muscleGroups.isDisjoint(with: upperBodyGroups) {
            terms.insert("upper body")
        }

        let armGroups: Set<MuscleGroup> = [.biceps, .triceps, .forearms]
        if !muscleGroups.isDisjoint(with: armGroups) {
            terms.formUnion(["arm", "arms"])
        }

        let coreGroups: Set<MuscleGroup> = [.abs, .obliques, .lowerBack]
        if !muscleGroups.isDisjoint(with: coreGroups) {
            terms.insert("core")
        }

        return terms.sorted()
    }

    private static func actionSearchAliases(
        for exercise: Exercise,
        includeSelectionAliases: Bool
    ) -> [String] {
        var aliases = ["Review \(exercise.displayName)"]

        if includeSelectionAliases {
            aliases.append(contentsOf: [
                "Add \(exercise.displayName)",
                "Select \(exercise.displayName)",
                "Choose \(exercise.displayName)",
                "Pick \(exercise.displayName)",
                "Use \(exercise.displayName)"
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

        let preferredName = Self.sanitizedSuggestedExerciseName(normalizedSearchText)
        let preferredLookup = Self.normalizedSearchLookupKey(preferredName)
        guard !preferredLookup.isEmpty,
              !Self.genericExercisePrefillLookupKeys.contains(preferredLookup) else {
            return nil
        }

        let nameAlreadyExists = exercises.contains {
            ExerciseManager.normalizedNameLookupKey($0.name) == preferredLookup
        }

        return nameAlreadyExists ? nil : preferredName
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
        let aliasValues = [
            exercise.category.rawValue,
            exercise.category.rawValue.capitalized
        ]
        + exercise.primaryMuscleGroups.map(\.displayName)
        + exercise.secondaryMuscleGroups.map(\.displayName)
        + bodyRegionSearchTerms(
            primaryMuscleGroups: exercise.primaryMuscleGroups,
            secondaryMuscleGroups: exercise.secondaryMuscleGroups
        )
        + actionSearchAliases(
            for: exercise,
            includeSelectionAliases: includeSelectionActionAliases
        )
        let aliasLookups = aliasValues.map(normalizedSearchLookupKey)
        let aliasWords = aliasLookups.flatMap { $0.split(separator: " ") }
        let normalizedInstructions = normalizedSearchLookupKey(exercise.instructions)
        let instructionWords = normalizedInstructions.split(separator: " ")

        func priority(for query: String) -> Int? {
            let compactedQuery = compactedSearchLookupKey(query)
            let initialismQuery = compactedQuery
            let queryTokens = normalizedSearchTokens(query)
            let words = normalizedName.split(separator: " ")

            if normalizedName == query {
                return 0
            }

            if normalizedName.hasPrefix(query) {
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

            if normalizedName.contains(query) {
                return 6
            }

            if aliasLookups.contains(query) {
                return 7
            }

            if aliasLookups.contains(where: { $0.hasPrefix(query) }) {
                return 8
            }

            if !queryTokens.isEmpty,
               queryTokens.allSatisfy({ token in
                   aliasWords.contains(where: { $0.hasPrefix(token) })
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

            if aliasLookups.contains(where: { $0.contains(query) }) {
                return 12
            }

            if !normalizedInstructions.isEmpty, normalizedInstructions == query {
                return 13
            }

            if !normalizedInstructions.isEmpty, normalizedInstructions.hasPrefix(query) {
                return 14
            }

            if !queryTokens.isEmpty,
               queryTokens.allSatisfy({ token in
                   instructionWords.contains(where: { $0.hasPrefix(token) })
               }) {
                return 15
            }

            let instructionInitialism = initialismLookupKey(exercise.instructions)
            if !initialismQuery.isEmpty,
               !instructionInitialism.isEmpty,
               instructionInitialism.hasPrefix(initialismQuery) {
                return 16
            }

            let compactedInstructions = compactedSearchLookupKey(exercise.instructions)
            if !compactedQuery.isEmpty,
               !compactedInstructions.isEmpty {
                if compactedInstructions == compactedQuery {
                    return 17
                }

                if compactedInstructions.hasPrefix(compactedQuery) {
                    return 18
                }

                if compactedInstructions.contains(compactedQuery) {
                    return 19
                }
            }

            if !normalizedInstructions.isEmpty, normalizedInstructions.contains(query) {
                return 20
            }

            return nil
        }

        return searchQueryVariants(for: normalizedQuery)
            .enumerated()
            .compactMap { index, query in
                priority(for: query).map { ($0 + (index * 100), index) }
            }
            .min(by: { lhs, rhs in
                if lhs.0 != rhs.0 {
                    return lhs.0 < rhs.0
                }

                return lhs.1 < rhs.1
            })?
            .0
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
            let workoutLabel = impact.loggedWorkoutCount == 1 ? "workout" : "workouts"
            let breakdown = loggedDeletionBreakdown(for: impact)
            let breakdownSuffix = breakdown.map { ", including \($0)" } ?? ""
            sentences.append("\(targetDescription) will remove \(impact.loggedSetCount) \(setLabel) from \(impact.loggedWorkoutCount) \(workoutLabel)\(breakdownSuffix)")
        }

        if impact.draftSetCount > 0 {
            let setLabel = impact.draftSetCount == 1 ? "draft set" : "draft sets"
            let workoutLabel = impact.draftWorkoutCount == 1 ? "in-progress workout" : "in-progress workouts"
            let prefix = impact.loggedSetCount > 0 ? "It will also remove" : "\(targetDescription) will remove"
            sentences.append("\(prefix) \(impact.draftSetCount) unlogged \(setLabel) from \(impact.draftWorkoutCount) \(workoutLabel)")
        }

        if impact.templateCount > 0 {
            let templateLabel = impact.templateCount == 1 ? "template" : "templates"
            let referenceVerb = impact.templateCount == 1 ? "references" : "reference"
            let templatePrefix = templateReferenceSummary(for: impact)
                .map { "\(impact.templateCount) \(templateLabel) (\($0))" }
                ?? "\(impact.templateCount) \(templateLabel)"
            let sentencePrefix = (impact.loggedSetCount > 0 || impact.draftSetCount > 0)
                ? "It will also leave"
                : "\(targetDescription) will leave"
            sentences.append("\(sentencePrefix) \(templatePrefix) that still \(referenceVerb) it and will skip it when started until you replace or remove it")
        }

        return sentences.joined(separator: ". ") + "."
    }

    private static func templateReferenceSummary(for impact: ExerciseManager.DeletionImpact) -> String? {
        let displayNames = impact.templateNames.filter { !$0.isEmpty }

        guard !displayNames.isEmpty else {
            return nil
        }

        if displayNames.count == 1 {
            return "“\(displayNames[0])”"
        }

        if displayNames.count == 2 {
            return "“\(displayNames[0])” and “\(displayNames[1])”"
        }

        let additionalCount = displayNames.count - 2
        let additionalSummary = additionalCount == 1
            ? "1 more"
            : "\(additionalCount) more"

        return "including “\(displayNames[0])”, “\(displayNames[1])”, and \(additionalSummary)"
    }


    private static func loggedDeletionBreakdown(for impact: ExerciseManager.DeletionImpact) -> String? {
        let workingCount = impact.loggedWorkingSetCount
        let warmupCount = impact.loggedWarmupSetCount

        guard workingCount > 0 || warmupCount > 0 else {
            return nil
        }

        if workingCount == 0 {
            return warmupCount == 1
                ? "1 logged warm-up set"
                : "\(warmupCount) logged warm-up sets"
        }

        if warmupCount == 0 {
            return workingCount == 1
                ? "1 logged working set"
                : "\(workingCount) logged working sets"
        }

        let workingSummary = workingCount == 1
            ? "1 logged working set"
            : "\(workingCount) logged working sets"
        let warmupSummary = warmupCount == 1
            ? "1 logged warm-up set"
            : "\(warmupCount) logged warm-up sets"

        return "\(workingSummary) and \(warmupSummary)"
    }
}
