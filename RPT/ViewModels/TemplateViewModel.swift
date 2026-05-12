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
    private struct ExerciseSearchMetadata {
        let searchTerms: [String]
    }

    enum ActiveWorkoutPersistenceAction {
        case saveForLater
        case discard
    }

    private let templateManager: TemplateManager
    private let exerciseManager: ExerciseManager
    
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

    private static func exercisePrescriptionSearchTerms(for exercise: TemplateExercise) -> [String] {
        var terms: [String] = []

        let setLabel = exercise.suggestedSets == 1 ? "set" : "sets"
        terms.append("\(exercise.suggestedSets) \(setLabel)")

        for repRange in exercise.repRanges.sorted(by: { $0.setNumber < $1.setNumber }) {
            terms.append("Set \(repRange.setNumber)")
            terms.append("\(repRange.minReps)-\(repRange.maxReps) reps")
            terms.append("Set \(repRange.setNumber): \(repRange.minReps)-\(repRange.maxReps) reps")

            if let percentageOfFirstSet = repRange.percentageOfFirstSet, repRange.setNumber > 1 {
                let percentage = Int(percentageOfFirstSet * 100)
                terms.append("\(percentage)% of first set")
                terms.append("\(percentage) percent of first set")
                terms.append("Set \(repRange.setNumber): \(repRange.minReps)-\(repRange.maxReps) reps (\(percentage)% of first set)")
            }
        }

        return terms
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
        initialismQuery: String,
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

        if !initialismQuery.isEmpty, normalizedTerms.contains(where: {
            let initialism = initialismLookupKey($0)
            return !initialism.isEmpty && initialism.hasPrefix(initialismQuery)
        }) {
            return 3
        }

        if searchTerms.contains(where: { compactedMatchPriority(query: compactedQuery, in: $0) != nil }) {
            return 4
        }

        if normalizedTerms.contains(where: { $0.contains(query) }) {
            return 5
        }

        return nil
    }

    var normalizedSearchText: String {
        Self.normalizedSearchQuery(searchText)
    }

    var hasActiveSearch: Bool {
        !normalizedSearchText.isEmpty
    }

    init(templateManager: TemplateManager? = nil, exerciseManager: ExerciseManager = ExerciseManager.shared) {
        self.templateManager = templateManager ?? TemplateManager.shared
        self.exerciseManager = exerciseManager
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

    func emptyStateDescription(filteredCount: Int) -> String {
        guard hasActiveSearch else {
            return "Create your first workout template to quickly start repeatable RPT sessions."
        }

        let normalizedQuery = normalizedSearchText
        let createSuggestion = suggestedTemplateNameForEmptySearch(filteredCount: filteredCount) != nil
            ? " You can also create a new template from this search."
            : ""

        return "No templates matched “\(normalizedQuery)”. Try a different search, clear it to browse every workout template, or search names, exercises, notes, and issue labels like missing or repeated.\(createSuggestion)"
    }

    func shouldShowResultsRecoveryActions(filteredCount: Int) -> Bool {
        hasActiveSearch && filteredCount > 0 && !templates.isEmpty
    }

    func suggestedTemplateNameFromSearch() -> String? {
        guard hasActiveSearch else {
            return nil
        }

        let normalizedName = normalizedSearchText
        guard !normalizedName.isEmpty else {
            return nil
        }

        let normalizedLookup = TemplateManager.normalizedNameLookupKey(normalizedName)
        let nameAlreadyExists = templates.contains {
            TemplateManager.normalizedNameLookupKey($0.name) == normalizedLookup
        }

        return nameAlreadyExists ? nil : normalizedName
    }

    func preferredNewTemplatePrefillName() -> String {
        suggestedTemplateNameFromSearch() ?? ""
    }

    func preferredDuplicateTemplateName(for template: WorkoutTemplate) -> String {
        let baseName = WorkoutTemplate.normalizedDisplayName(template.name)
        let existingLookupKeys = Set(templates.map {
            TemplateManager.normalizedNameLookupKey($0.name)
        })

        var candidateName = "\(baseName) Copy"
        var suffix = 2

        while existingLookupKeys.contains(TemplateManager.normalizedNameLookupKey(candidateName)) {
            candidateName = "\(baseName) Copy \(suffix)"
            suffix += 1
        }

        return candidateName
    }

    func suggestedTemplateNameForEmptySearch(filteredCount: Int) -> String? {
        guard filteredCount == 0 else {
            return nil
        }

        return suggestedTemplateNameFromSearch()
    }

    func shouldShowCreateTemplateFromSearchAction(filteredCount: Int) -> Bool {
        hasActiveSearch && filteredCount > 0 && suggestedTemplateNameFromSearch() != nil
    }

    func createTemplateRecoveryTitle(filteredCount: Int) -> String? {
        let suggestedName: String?
        if filteredCount == 0 {
            suggestedName = suggestedTemplateNameForEmptySearch(filteredCount: filteredCount)
        } else {
            suggestedName = shouldShowCreateTemplateFromSearchAction(filteredCount: filteredCount)
                ? suggestedTemplateNameFromSearch()
                : nil
        }

        guard let suggestedName else {
            return nil
        }

        return "Create “\(suggestedName)”"
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

    func activeWorkoutBlocksTemplateStartMessage(for workout: Workout, opening template: WorkoutTemplate) -> String {
        let templateName = WorkoutTemplate.normalizedDisplayName(template.name)
        let templateSuffix = templateName == "Template"
            ? "before starting this template."
            : "before starting \(templateName)."

        return "\(activeWorkoutPromptPrefix(for: workout)) Continue it, save it for later, or discard it \(templateSuffix)"
    }

    func activeWorkoutPersistenceFailureMessage(for action: ActiveWorkoutPersistenceAction) -> String {
        switch action {
        case .saveForLater:
            return "Couldn’t save the current workout. Keep it open, then try starting from the template again."
        case .discard:
            return "Couldn’t discard the current workout. Keep it open, then try starting from the template again."
        }
    }

    func startTemplateAfterPersistingActiveWorkout(
        _ activeWorkout: Workout,
        action: ActiveWorkoutPersistenceAction,
        opening template: WorkoutTemplate,
        persist: (Workout) -> Bool
    ) -> Result<Workout, String> {
        guard persistActiveWorkoutBeforeTemplateStart(activeWorkout, action: action, persist: persist) else {
            return .failure(activeWorkoutPersistenceFailureMessage(for: action))
        }

        guard let startedWorkout = createWorkoutFromTemplate(template) else {
            return .failure("Your template workout could not be started right now. Please try again.")
        }

        return .success(startedWorkout)
    }

    static func searchMatchPriority(template: WorkoutTemplate, normalizedQuery: String) -> Int? {
        guard !normalizedQuery.isEmpty else {
            return 0
        }

        let normalizedName = normalizedSearchLookupKey(template.name)
        let compactedQuery = compactedSearchLookupKey(normalizedQuery)
        let initialismQuery = compactedQuery
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

        let nameInitialism = initialismLookupKey(template.name)
        if !initialismQuery.isEmpty,
           !nameInitialism.isEmpty,
           nameInitialism.hasPrefix(initialismQuery) {
            return 3
        }

        if let compactedNamePriority = compactedMatchPriority(query: compactedQuery, in: template.name) {
            return 4 + compactedNamePriority
        }

        if normalizedName.contains(normalizedQuery) {
            return 7
        }

        let exerciseNames = template.exercises.map(\.exerciseName)
        let normalizedExerciseNames = exerciseNames.map { normalizedSearchLookupKey($0) }

        if normalizedExerciseNames.contains(where: { $0 == normalizedQuery }) {
            return 8
        }

        if normalizedExerciseNames.contains(where: { $0.hasPrefix(normalizedQuery) }) {
            return 9
        }

        if exerciseNames.contains(where: { matchesQueryTokens(queryTokens, in: $0) }) {
            return 10
        }

        if !initialismQuery.isEmpty,
           exerciseNames.contains(where: {
               let initialism = initialismLookupKey($0)
               return !initialism.isEmpty && initialism.hasPrefix(initialismQuery)
           }) {
            return 11
        }

        if exerciseNames.contains(where: { compactedMatchPriority(query: compactedQuery, in: $0) != nil }) {
            return 12
        }

        if normalizedExerciseNames.contains(where: { $0.contains(normalizedQuery) }) {
            return 13
        }

        let exerciseNotes = template.exercises.map(\.notes)
        let normalizedExerciseNotes = exerciseNotes.map { normalizedSearchLookupKey($0) }

        if normalizedExerciseNotes.contains(where: { !$0.isEmpty && $0 == normalizedQuery }) {
            return 14
        }

        if normalizedExerciseNotes.contains(where: { !$0.isEmpty && $0.hasPrefix(normalizedQuery) }) {
            return 15
        }

        if exerciseNotes.contains(where: { matchesQueryTokens(queryTokens, in: $0) }) {
            return 16
        }

        if !initialismQuery.isEmpty,
           exerciseNotes.contains(where: {
               let initialism = initialismLookupKey($0)
               return !initialism.isEmpty && initialism.hasPrefix(initialismQuery)
           }) {
            return 17
        }

        if exerciseNotes.contains(where: { compactedMatchPriority(query: compactedQuery, in: $0) != nil }) {
            return 18
        }

        if normalizedExerciseNotes.contains(where: { !$0.isEmpty && $0.contains(normalizedQuery) }) {
            return 19
        }

        let exercisePrescriptionTerms = template.exercises.flatMap { exercisePrescriptionSearchTerms(for: $0) }
        if let prescriptionPriority = searchTermMatchPriority(
            query: normalizedQuery,
            queryTokens: queryTokens,
            compactedQuery: compactedQuery,
            initialismQuery: initialismQuery,
            in: exercisePrescriptionTerms
        ) {
            return 20 + prescriptionPriority
        }

        let normalizedNotes = normalizedSearchLookupKey(template.notes)
        if !normalizedNotes.isEmpty, normalizedNotes == normalizedQuery {
            return 26
        }

        if !normalizedNotes.isEmpty, normalizedNotes.hasPrefix(normalizedQuery) {
            return 27
        }

        if matchesQueryTokens(queryTokens, in: template.notes) {
            return 28
        }

        let notesInitialism = initialismLookupKey(template.notes)
        if !initialismQuery.isEmpty,
           !notesInitialism.isEmpty,
           notesInitialism.hasPrefix(initialismQuery) {
            return 29
        }

        if compactedMatchPriority(query: compactedQuery, in: template.notes) != nil {
            return 30
        }

        if !normalizedNotes.isEmpty, normalizedNotes.contains(normalizedQuery) {
            return 31
        }

        return nil
    }

    private func exerciseSearchMetadataLookup() -> [String: ExerciseSearchMetadata] {
        var lookup: [String: ExerciseSearchMetadata] = [:]

        for exercise in exerciseManager.fetchAllExercises() {
            let key = ExerciseManager.normalizedNameLookupKey(exercise.name)
            let terms = [
                exercise.category.rawValue,
                exercise.category.rawValue.capitalized
            ]
            + exercise.primaryMuscleGroups.map(\.displayName)
            + exercise.secondaryMuscleGroups.map(\.displayName)

            lookup[key] = ExerciseSearchMetadata(searchTerms: terms)
        }

        return lookup
    }

    private func exerciseMetadataSearchTerms(
        for template: WorkoutTemplate,
        lookup: [String: ExerciseSearchMetadata]
    ) -> [String] {
        var seen = Set<String>()
        var terms: [String] = []

        for exercise in template.exercises {
            let key = ExerciseManager.normalizedNameLookupKey(exercise.exerciseName)
            guard let metadata = lookup[key] else {
                continue
            }

            for term in metadata.searchTerms where seen.insert(term).inserted {
                terms.append(term)
            }
        }

        return terms
    }

    private func issueSearchTerms(
        for template: WorkoutTemplate,
        activeWorkoutAvailable: Bool,
        blockedByActiveWorkout: Bool
    ) -> [String] {
        let templateName = WorkoutTemplate.normalizedDisplayName(template.name)
        let totalCount = template.exercises.count
        let unavailableExerciseNames = templateManager.unavailableExerciseNames(in: template)
        let duplicateExerciseNames = templateManager.duplicateExerciseNames(in: template)
        let startableExerciseNames = templateManager.startableExerciseNames(in: template)
        let unavailableCount = unavailableExerciseNames.count
        let duplicateCount = duplicateExerciseNames.count
        let availableCount = startableExerciseNames.count
        let canStartWorkout = availableCount > 0
        let isOnlyBlockedByActiveWorkout = blockedByActiveWorkout
        let shouldSuggestEditingTemplate = totalCount == 0 || unavailableCount > 0 || duplicateCount > 0 || !canStartWorkout

        var terms: [String] = [
            "review template",
            "review \(templateName)",
            "edit template",
            "edit \(templateName)",
            "delete template",
            "delete \(templateName)",
            "duplicate template",
            "duplicate \(templateName)",
            "copy template",
            "copy \(templateName)",
            "\(templateName) copy"
        ]

        if canStartWorkout {
            terms.append(contentsOf: [
                "start workout",
                "start \(templateName)",
                "ready",
                "ready to start",
                "available",
                "available exercises"
            ])
        }

        if activeWorkoutAvailable {
            let openTemplateSuffix = templateName == "Template"
                ? "before opening this template."
                : "before opening \(templateName)."
            let startTemplateSuffix = templateName == "Template"
                ? "before starting this template."
                : "before starting \(templateName)."

            terms.append(contentsOf: [
                "current workout",
                "current workout in progress",
                "workout in progress",
                "in progress",
                "resume current workout",
                "continue current workout",
                "save for later",
                "save it for later",
                "discard workout",
                "discard current workout",
                "discard it",
                "keep going",
                "keep going \(openTemplateSuffix)",
                "continue it",
                "continue it \(startTemplateSuffix)",
                "save it for later, discard it, or keep going \(openTemplateSuffix)",
                "continue it, save it for later, or discard it \(startTemplateSuffix)",
                "save open template",
                "save & open template",
                "save and open template",
                "discard open template",
                "discard & open template",
                "discard and open template"
            ])
        }

        if isOnlyBlockedByActiveWorkout {
            terms.append("blocked")
        }

        if totalCount == 0 {
            terms.append(contentsOf: [
                "empty",
                "no exercises",
                "no exercises added yet",
                "empty template",
                "add exercises",
                "add at least 1 exercise",
                "needs exercises"
            ])
        }

        if unavailableCount > 0 {
            terms.append(contentsOf: [
                "missing",
                "unavailable",
                "missing exercises",
                "unavailable exercises",
                "unavailable right now",
                "missing from library",
                TemplateManager.TemplateExerciseIssue.missingFromLibrary.summary,
                "skipped until restored",
                "restore",
                "restore exercise",
                "restore missing exercise",
                "replace",
                "replace exercise",
                "replace missing exercise",
                "skipped",
                "skip"
            ])
            terms.append(contentsOf: unavailableExerciseNames)
            terms.append(contentsOf: unavailableExerciseNames.flatMap {
                [
                    "restore \($0)",
                    "replace \($0)",
                    "missing \($0)",
                    "unavailable \($0)",
                    "missing from library \($0)",
                    "skipped until restored \($0)"
                ]
            })

            if canStartWorkout {
                terms.append(contentsOf: [
                    "partial",
                    "partial workout",
                    "skipped exercises"
                ])
            }
        }

        if duplicateCount > 0 {
            terms.append(contentsOf: [
                "repeated",
                "duplicate",
                "repeated entries",
                "duplicate exercises",
                "repeated entry",
                TemplateManager.TemplateExerciseIssue.repeatedEntry.summary,
                "only the first copy will be added",
                "remove extra copy",
                "remove repeated entry"
            ])
            terms.append(contentsOf: duplicateExerciseNames)
            terms.append(contentsOf: duplicateExerciseNames.flatMap {
                [
                    "remove extra copy \($0)",
                    "remove repeated entry \($0)",
                    "repeated entry \($0)"
                ]
            })
        }

        if !startableExerciseNames.isEmpty && (unavailableCount > 0 || duplicateCount > 0) {
            terms.append(contentsOf: [
                "ready right now",
                "included when this workout starts",
                "included"
            ])
            terms.append(contentsOf: startableExerciseNames)
        }

        if shouldSuggestEditingTemplate {
            terms.append("fix template")
        }

        if !canStartWorkout {
            terms.append(contentsOf: [
                "blocked",
                "cannot start",
                "can't start",
                "cant start",
                "not ready"
            ])
        }

        terms.append(templateManager.templateListExerciseSummary(for: template, blockedByActiveWorkout: isOnlyBlockedByActiveWorkout))
        terms.append(templateManager.templateDetailStatusSummary(for: template, blockedByActiveWorkout: isOnlyBlockedByActiveWorkout))
        terms.append(templateManager.startWorkoutActionTitle(for: template, blockedByActiveWorkout: isOnlyBlockedByActiveWorkout))

        if let startWorkoutDisabledMessage = templateManager.startWorkoutDisabledMessage(for: template) {
            terms.append(startWorkoutDisabledMessage)
        }

        if let startWorkoutConfirmationMessage = templateManager.startWorkoutConfirmationMessage(for: template) {
            terms.append(startWorkoutConfirmationMessage)
        }

        return terms
    }

    private func searchMatchPriority(
        template: WorkoutTemplate,
        normalizedQuery: String,
        activeWorkoutAvailable: Bool,
        blockedByActiveWorkout: Bool,
        exerciseMetadataLookup: [String: ExerciseSearchMetadata]
    ) -> Int? {
        if let basePriority = Self.searchMatchPriority(template: template, normalizedQuery: normalizedQuery) {
            return basePriority
        }

        let queryTokens = Self.normalizedSearchTokens(normalizedQuery)
        let compactedQuery = Self.compactedSearchLookupKey(normalizedQuery)
        let initialismQuery = compactedQuery

        if let exerciseMetadataPriority = Self.searchTermMatchPriority(
            query: normalizedQuery,
            queryTokens: queryTokens,
            compactedQuery: compactedQuery,
            initialismQuery: initialismQuery,
            in: exerciseMetadataSearchTerms(for: template, lookup: exerciseMetadataLookup)
        ) {
            return 20 + exerciseMetadataPriority
        }

        let issueSearchTerms = issueSearchTerms(
            for: template,
            activeWorkoutAvailable: activeWorkoutAvailable,
            blockedByActiveWorkout: blockedByActiveWorkout
        )

        if let issuePriority = Self.searchTermMatchPriority(
            query: normalizedQuery,
            queryTokens: queryTokens,
            compactedQuery: compactedQuery,
            initialismQuery: initialismQuery,
            in: issueSearchTerms
        ) {
            return 26 + issuePriority
        }

        return nil
    }

    func fetchTemplates(blockedByActiveWorkout: Bool = false) -> [WorkoutTemplate] {
        let normalizedSearchLookup = Self.normalizedSearchLookupKey(normalizedSearchText)
        let exerciseMetadataLookup = exerciseSearchMetadataLookup()

        return templates
            .enumerated()
            .compactMap { index, template in
                let templateCannotStartOnItsOwn = templateManager.startWorkoutDisabledMessage(for: template) != nil
                let isBlockedByActiveWorkout = blockedByActiveWorkout && !templateCannotStartOnItsOwn
                let searchPriority = searchMatchPriority(
                    template: template,
                    normalizedQuery: normalizedSearchLookup,
                    activeWorkoutAvailable: blockedByActiveWorkout,
                    blockedByActiveWorkout: isBlockedByActiveWorkout,
                    exerciseMetadataLookup: exerciseMetadataLookup
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
