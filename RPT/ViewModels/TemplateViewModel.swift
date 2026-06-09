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

    private static let conversationalSearchLeadInPrefixes = [
        "please ",
        "can you ",
        "could you ",
        "would you ",
        "will you ",
        "help me ",
        "let me ",
        "show me ",
        "take me to ",
        "bring me to ",
        "go to ",
        "jump to ",
        "head to "
    ]

    private static let conversationalSearchTrailingPhrases = [
        " thank you",
        " thanks",
        " please",
        " for me"
    ]

    private static let searchIntentPrefillPrefixes = [
        "save and start partial template ",
        "save & start partial template ",
        "discard and start partial template ",
        "discard & start partial template ",
        "save and start template ",
        "save & start template ",
        "discard and start template ",
        "discard & start template ",
        "start partial template ",
        "start template ",
        "start workout ",
        "search for template ",
        "search for routine ",
        "search for workout plan ",
        "search for training program ",
        "search for program ",
        "search for workout ",
        "find me template ",
        "find me routine ",
        "find me workout plan ",
        "find me training program ",
        "find me program ",
        "find me workout ",
        "find template ",
        "find routine ",
        "find workout plan ",
        "find training program ",
        "find program ",
        "find workout ",
        "looking for template ",
        "looking for routine ",
        "looking for workout plan ",
        "looking for training program ",
        "looking for program ",
        "looking for workout ",
        "looking for ",
        "look up template ",
        "look up routine ",
        "look up workout plan ",
        "look up training program ",
        "look up program ",
        "look up workout ",
        "lookup template ",
        "lookup routine ",
        "lookup workout plan ",
        "lookup training program ",
        "lookup program ",
        "lookup workout ",
        "review template ",
        "review routine ",
        "review workout plan ",
        "review training program ",
        "review program ",
        "view template ",
        "view routine ",
        "view workout plan ",
        "view training program ",
        "view program ",
        "show template ",
        "show routine ",
        "show workout plan ",
        "show training program ",
        "show program ",
        "preview template ",
        "preview routine ",
        "preview workout plan ",
        "preview training program ",
        "preview program ",
        "inspect template ",
        "inspect routine ",
        "inspect workout plan ",
        "inspect training program ",
        "inspect program ",
        "restart template ",
        "restart routine ",
        "restart workout plan ",
        "restart training program ",
        "restart program ",
        "rerun template ",
        "rerun routine ",
        "rerun workout plan ",
        "rerun training program ",
        "rerun program ",
        "repeat template ",
        "repeat routine ",
        "repeat workout plan ",
        "repeat training program ",
        "repeat program ",
        "edit template ",
        "edit routine ",
        "edit workout plan ",
        "edit training program ",
        "edit program ",
        "rename template ",
        "rename routine ",
        "rename workout plan ",
        "rename training program ",
        "rename program ",
        "delete template ",
        "delete routine ",
        "delete workout plan ",
        "delete training program ",
        "delete program ",
        "duplicate template ",
        "duplicate routine ",
        "duplicate workout plan ",
        "duplicate training program ",
        "duplicate program ",
        "copy template ",
        "copy routine ",
        "copy workout plan ",
        "copy training program ",
        "copy program ",
        "clone template ",
        "clone routine ",
        "clone workout plan ",
        "clone training program ",
        "clone program ",
        "remove template ",
        "remove routine ",
        "remove workout plan ",
        "remove training program ",
        "remove program ",
        "use template ",
        "use routine ",
        "use workout plan ",
        "use training program ",
        "use program ",
        "use workout ",
        "choose template ",
        "choose routine ",
        "choose workout plan ",
        "choose training program ",
        "choose program ",
        "choose workout ",
        "pick template ",
        "pick routine ",
        "pick workout plan ",
        "pick training program ",
        "pick program ",
        "pick workout ",
        "select template ",
        "select routine ",
        "select workout plan ",
        "select training program ",
        "select program ",
        "select workout ",
        "launch template ",
        "launch routine ",
        "launch workout plan ",
        "launch training program ",
        "launch program ",
        "launch workout ",
        "open template ",
        "open routine ",
        "open workout plan ",
        "open training program ",
        "open program ",
        "template details ",
        "routine details ",
        "workout plan details ",
        "training program details ",
        "program details ",
        "details ",
        "open workout ",
        "continue workout ",
        "resume workout ",
        "finish workout ",
        "search for ",
        "find me ",
        "find ",
        "look up ",
        "lookup ",
        "go to ",
        "jump to ",
        "head to ",
        "start ",
        "review ",
        "view ",
        "show ",
        "preview ",
        "inspect ",
        "browse ",
        "check out ",
        "check ",
        "restart ",
        "rerun ",
        "repeat ",
        "edit ",
        "rename ",
        "delete ",
        "duplicate ",
        "copy ",
        "clone ",
        "remove ",
        "use ",
        "choose ",
        "pick ",
        "select ",
        "launch ",
        "open ",
        "continue ",
        "resume ",
        "finish ",
        "save ",
        "discard "
    ]

    private static let genericTemplateEntityPrefixes = [
        "template ",
        "templates ",
        "routine ",
        "routines ",
        "workout plan ",
        "workout plans ",
        "workout ",
        "workouts ",
        "training program ",
        "training programs ",
        "program ",
        "programs "
    ]

    private static func bodyRegionSearchTerms(
        primaryMuscleGroups: [MuscleGroup],
        secondaryMuscleGroups: [MuscleGroup]
    ) -> [String] {
        let muscleGroups = Set(primaryMuscleGroups + secondaryMuscleGroups)
        var terms = Set<String>()

        let lowerBodyGroups: Set<MuscleGroup> = [.quadriceps, .hamstrings, .glutes, .calves]
        let upperBodyGroups: Set<MuscleGroup> = [.chest, .back, .shoulders, .biceps, .triceps, .forearms, .traps]
        let coreGroups: Set<MuscleGroup> = [.abs, .obliques, .lowerBack]

        let matchesLowerBody = !muscleGroups.isDisjoint(with: lowerBodyGroups)
        let matchesUpperBody = !muscleGroups.isDisjoint(with: upperBodyGroups)
        let matchesCore = !muscleGroups.isDisjoint(with: coreGroups)

        if matchesLowerBody {
            terms.formUnion(["lower body", "leg", "legs"])
        }

        if matchesUpperBody {
            terms.insert("upper body")
        }

        let armGroups: Set<MuscleGroup> = [.biceps, .triceps, .forearms]
        if !muscleGroups.isDisjoint(with: armGroups) {
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

    private static let genericTemplatePrefillLookupKeys: Set<String> = [
        "template",
        "templates",
        "this template",
        "partial template",
        "routine",
        "routines",
        "workout plan",
        "workout plans",
        "workout",
        "workouts",
        "this workout",
        "open workout",
        "continue workout",
        "resume workout",
        "finish workout",
        "current workout",
        "workout in progress",
        "training program",
        "training programs",
        "program",
        "programs"
    ]

    private static let suggestedTemplateNameTrimCharacterSet: CharacterSet = {
        var characterSet = CharacterSet.whitespacesAndNewlines
        characterSet.formUnion(.punctuationCharacters)
        characterSet.formUnion(.symbols)
        return characterSet
    }()

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

            let repRangeLabel: String
            let spokenRepRangeLabel: String
            if repRange.minReps == repRange.maxReps {
                repRangeLabel = "\(repRange.minReps)"
                spokenRepRangeLabel = repRangeLabel
                terms.append("\(repRange.minReps) reps")
                terms.append("Set \(repRange.setNumber): \(repRange.minReps) reps")
            } else {
                repRangeLabel = "\(repRange.minReps)-\(repRange.maxReps)"
                spokenRepRangeLabel = "\(repRange.minReps) to \(repRange.maxReps)"
                terms.append("\(repRange.minReps)-\(repRange.maxReps) reps")
                terms.append("\(repRange.minReps) to \(repRange.maxReps) reps")
                terms.append("Set \(repRange.setNumber): \(repRange.minReps)-\(repRange.maxReps) reps")
            }

            terms.append("\(exercise.suggestedSets)x\(repRangeLabel)")
            terms.append("\(exercise.suggestedSets) x \(repRangeLabel)")
            terms.append("\(exercise.suggestedSets)×\(repRangeLabel)")
            terms.append("\(exercise.suggestedSets) \(setLabel) of \(repRangeLabel)")
            terms.append("\(exercise.suggestedSets) \(setLabel) of \(spokenRepRangeLabel)")
            terms.append("\(exercise.suggestedSets) \(setLabel) of \(spokenRepRangeLabel) reps")
            terms.append("\(exercise.suggestedSets) by \(repRangeLabel)")
            terms.append("\(exercise.suggestedSets) by \(spokenRepRangeLabel)")

            if let percentageOfFirstSet = repRange.percentageOfFirstSet, repRange.setNumber > 1 {
                let percentage = Int(percentageOfFirstSet * 100)
                terms.append("\(percentage)% of first set")
                terms.append("\(percentage) percent of first set")

                if repRange.minReps == repRange.maxReps {
                    terms.append("Set \(repRange.setNumber): \(repRange.minReps) reps (\(percentage)% of first set)")
                } else {
                    terms.append("Set \(repRange.setNumber): \(repRange.minReps)-\(repRange.maxReps) reps (\(percentage)% of first set)")
                }
            }
        }

        return terms
    }

    private static func humanReadableList(_ parts: [String]) -> String {
        switch parts.count {
        case 0:
            return ""
        case 1:
            return parts[0]
        case 2:
            return parts.joined(separator: " and ")
        default:
            return parts.dropLast().joined(separator: ", ") + ", and " + (parts.last ?? "")
        }
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

        return "No templates matched “\(normalizedQuery)”. Try a different search, clear it to browse every workout template, or search names, exercises, notes, body regions like upper body or full body, action wording like start, use Save for Later, launch, review, view, edit, open, continue, save, or discard, and issue labels like missing or repeated.\(createSuggestion)"
    }

    func shouldShowResultsRecoveryActions(filteredCount: Int) -> Bool {
        hasActiveSearch && filteredCount > 0 && !templates.isEmpty
    }

    func shouldShowEmptyStateContinueWorkoutAction(workout: Workout?) -> Bool {
        workout != nil
    }

    func emptyStateContinueWorkoutButtonTitle(for workout: Workout?) -> String {
        guard let workout else {
            return "Open Workout"
        }

        return continueCurrentWorkoutButtonTitle(for: workout)
    }

    func shouldShowSingleTemplateQuickActions(filteredCount: Int) -> Bool {
        filteredCount == 1 && (!templates.isEmpty && (hasActiveSearch || templates.count == 1))
    }

    private static func lastQuotedSearchName(in rawQuery: String) -> String? {
        let patterns = [#"“([^“”]+)”"#, #"\"([^\"]+)\""#]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }

            let range = NSRange(rawQuery.startIndex..., in: rawQuery)
            let matches = regex.matches(in: rawQuery, range: range)

            for match in matches.reversed() {
                guard match.numberOfRanges > 1,
                      let matchRange = Range(match.range(at: 1), in: rawQuery) else {
                    continue
                }

                let candidate = normalizedSearchQuery(String(rawQuery[matchRange]))
                if !candidate.isEmpty {
                    return candidate
                }
            }
        }

        return nil
    }

    private static func strippedConversationalSearchLeadIn(from rawQuery: String) -> String {
        var candidate = normalizedSearchQuery(rawQuery)
        var didStrip = true

        while didStrip {
            didStrip = false
            let lowercasedCandidate = candidate.lowercased()

            for prefix in conversationalSearchLeadInPrefixes where lowercasedCandidate.hasPrefix(prefix) {
                candidate = normalizedSearchQuery(String(candidate.dropFirst(prefix.count)))
                didStrip = true
                break
            }
        }

        return candidate
    }

    private static func strippedGenericTemplateEntityPrefix(from rawQuery: String) -> String {
        var candidate = normalizedSearchQuery(rawQuery)
        var didStrip = true

        while didStrip {
            didStrip = false
            let lowercasedCandidate = candidate.lowercased()

            for prefix in genericTemplateEntityPrefixes where lowercasedCandidate.hasPrefix(prefix) {
                candidate = normalizedSearchQuery(String(candidate.dropFirst(prefix.count)))
                didStrip = true
                break
            }
        }

        return candidate
    }

    private static func strippedGenericTemplateEntitySuffix(from rawQuery: String) -> String {
        var candidate = normalizedSearchQuery(rawQuery)
        var didStrip = true

        while didStrip {
            didStrip = false
            let lowercasedCandidate = candidate.lowercased()

            for suffix in genericTemplateEntityPrefixes {
                let trimmedSuffix = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedSuffix.isEmpty,
                      lowercasedCandidate.hasSuffix(trimmedSuffix) else {
                    continue
                }

                let prefixEndIndex = candidate.index(candidate.endIndex, offsetBy: -trimmedSuffix.count)
                let prefix = normalizedSearchQuery(String(candidate[..<prefixEndIndex]))
                guard !prefix.isEmpty else {
                    continue
                }

                candidate = prefix
                didStrip = true
                break
            }
        }

        return candidate
    }

    private static func strippedGenericTemplateEntityAffixes(from rawQuery: String) -> String {
        var candidate = normalizedSearchQuery(rawQuery)
        var previousCandidate: String

        repeat {
            previousCandidate = candidate
            candidate = strippedGenericTemplateEntityPrefix(from: candidate)
            candidate = strippedGenericTemplateEntitySuffix(from: candidate)
        } while candidate != previousCandidate

        return candidate
    }

    private static func strippedConversationalSearchTail(from rawQuery: String) -> String {
        var candidate = normalizedSearchQuery(
            rawQuery.trimmingCharacters(in: suggestedTemplateNameTrimCharacterSet)
        )
        var didStrip = true

        while didStrip {
            didStrip = false
            let lowercasedCandidate = candidate.lowercased()

            for suffix in conversationalSearchTrailingPhrases where lowercasedCandidate.hasSuffix(suffix) {
                let suffixStartIndex = candidate.index(candidate.endIndex, offsetBy: -suffix.count)
                candidate = normalizedSearchQuery(
                    String(candidate[..<suffixStartIndex])
                        .trimmingCharacters(in: suggestedTemplateNameTrimCharacterSet)
                )
                didStrip = true
                break
            }
        }

        return candidate
    }

    private static func strippedSearchObjectLeadIns(from rawQuery: String) -> String {
        var candidate = normalizedSearchQuery(rawQuery)
        var didStrip = true

        while didStrip {
            didStrip = false
            let lowercasedCandidate = candidate.lowercased()

            for prefix in searchObjectLeadInPrefixes where lowercasedCandidate.hasPrefix(prefix) {
                candidate = normalizedSearchQuery(String(candidate.dropFirst(prefix.count)))
                didStrip = true
                break
            }
        }

        return candidate
    }

    private static func strippedSearchBridgeLeadIns(from rawQuery: String) -> String {
        var candidate = normalizedSearchQuery(rawQuery)
        var didStrip = true

        while didStrip {
            didStrip = false
            let lowercasedCandidate = candidate.lowercased()

            for prefix in searchBridgeLeadInPrefixes where lowercasedCandidate.hasPrefix(prefix) {
                candidate = normalizedSearchQuery(String(candidate.dropFirst(prefix.count)))
                didStrip = true
                break
            }
        }

        return candidate
    }

    private static func strippedSearchIntentPrefix(from rawQuery: String) -> String {
        let normalizedQuery = normalizedSearchQuery(rawQuery)
        var candidate = strippedConversationalSearchLeadIn(from: normalizedQuery)
        var strippedIntentfulPrefix = candidate != normalizedQuery
        var didStrip = true

        while didStrip {
            didStrip = false
            let lowercasedCandidate = candidate.lowercased()

            for prefix in searchIntentPrefillPrefixes where lowercasedCandidate.hasPrefix(prefix) {
                candidate = normalizedSearchQuery(String(candidate.dropFirst(prefix.count)))
                candidate = strippedSearchObjectLeadIns(from: candidate)
                candidate = strippedSearchBridgeLeadIns(from: candidate)
                strippedIntentfulPrefix = true
                didStrip = true
                break
            }
        }

        candidate = strippedSearchObjectLeadIns(from: candidate)
        let candidateBeforeGenericEntityStrip = candidate
        candidate = strippedGenericTemplateEntityPrefix(from: candidate)
        if candidate != candidateBeforeGenericEntityStrip {
            strippedIntentfulPrefix = true
        }

        if strippedIntentfulPrefix {
            candidate = strippedSearchBridgeLeadIns(from: candidate)
        }

        candidate = strippedSearchObjectLeadIns(from: candidate)
        candidate = strippedConversationalSearchTail(from: candidate)
        return strippedGenericTemplateEntityPrefix(from: candidate)
    }

    private static func sanitizedSuggestedTemplateName(_ rawCandidate: String) -> String {
        normalizedSearchQuery(rawCandidate.trimmingCharacters(in: suggestedTemplateNameTrimCharacterSet))
    }

    private static func suggestedTemplateNameCandidate(from rawQuery: String) -> String? {
        let normalizedQuery = normalizedSearchQuery(rawQuery)
        guard !normalizedQuery.isEmpty else {
            return nil
        }

        let queryWithoutLeadIn = strippedConversationalSearchLeadIn(from: normalizedQuery)
        let candidate = lastQuotedSearchName(in: normalizedQuery)
            ?? strippedGenericTemplateEntitySuffix(from: strippedSearchIntentPrefix(from: queryWithoutLeadIn))
        let normalizedCandidate = sanitizedSuggestedTemplateName(candidate)
        guard !normalizedCandidate.isEmpty else {
            return nil
        }

        let normalizedLookup = normalizedSearchLookupKey(normalizedCandidate)
        guard !genericTemplatePrefillLookupKeys.contains(normalizedLookup) else {
            return nil
        }

        return normalizedCandidate
    }

    private static func normalizedSearchLookupVariants(for rawQuery: String) -> [String] {
        let normalizedQuery = normalizedSearchQuery(rawQuery)
        guard !normalizedQuery.isEmpty else {
            return []
        }

        let strippedConversationalLeadIn = strippedConversationalSearchLeadIn(from: normalizedQuery)
        let strippedConversationalTail = strippedConversationalSearchTail(from: normalizedQuery)
        let strippedObjectLeadIns = strippedSearchObjectLeadIns(from: strippedConversationalLeadIn)
        let strippedIntent = strippedSearchIntentPrefix(from: normalizedQuery)

        return Array(
            Set([
                normalizedQuery,
                strippedConversationalLeadIn,
                strippedConversationalTail,
                strippedGenericTemplateEntityPrefix(from: normalizedQuery),
                strippedGenericTemplateEntityAffixes(from: normalizedQuery),
                strippedGenericTemplateEntityAffixes(from: strippedConversationalTail),
                strippedObjectLeadIns,
                strippedGenericTemplateEntityAffixes(from: strippedObjectLeadIns),
                strippedIntent,
                strippedGenericTemplateEntityAffixes(from: strippedIntent)
            ]
            .map(normalizedSearchLookupKey)
            .filter { !$0.isEmpty })
        )
    }

    func suggestedTemplateNameFromSearch() -> String? {
        guard hasActiveSearch,
              let normalizedName = Self.suggestedTemplateNameCandidate(from: normalizedSearchText) else {
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

    private func duplicateTemplateNameSeed(for templateName: String) -> (baseName: String, nextCopyNumber: Int?) {
        let displayName = WorkoutTemplate.normalizedDisplayName(templateName)
        let pattern = #"^(.*?)(?: Copy(?: ([0-9]+))?)?$"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(
                in: displayName,
                options: [],
                range: NSRange(displayName.startIndex..., in: displayName)
              ),
              let baseRange = Range(match.range(at: 1), in: displayName) else {
            return (displayName, nil)
        }

        let baseName = String(displayName[baseRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseName.isEmpty else {
            return (displayName, nil)
        }

        let hasCopySuffix = match.range(at: 0).length != match.range(at: 1).length
        guard hasCopySuffix else {
            return (baseName, nil)
        }

        if let numberRange = Range(match.range(at: 2), in: displayName),
           let copyNumber = Int(displayName[numberRange]) {
            return (baseName, max(copyNumber + 1, 2))
        }

        return (baseName, 2)
    }

    func preferredDuplicateTemplateName(for template: WorkoutTemplate) -> String {
        let existingLookupKeys = Set(templates.map {
            TemplateManager.normalizedNameLookupKey($0.name)
        })
        let seed = duplicateTemplateNameSeed(for: template.name)

        var nextCopyNumber = seed.nextCopyNumber
        var candidateName = nextCopyNumber.map {
            "\(seed.baseName) Copy \($0)"
        } ?? "\(seed.baseName) Copy"

        while existingLookupKeys.contains(TemplateManager.normalizedNameLookupKey(candidateName)) {
            nextCopyNumber = max((nextCopyNumber ?? 1) + 1, 2)
            candidateName = "\(seed.baseName) Copy \(nextCopyNumber!)"
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
        let workoutSummary = HomeViewModel().resumableWorkoutSummary(for: workout)
        let statusReference = HomeViewModel.resumableWorkoutStatusReference(for: workout)

        return "You already have \(statusReference): \(workoutSummary)."
    }

    func activeWorkoutPromptMessage(for workout: Workout, opening template: WorkoutTemplate) -> String {
        let templateSuffix = "before opening \(templateReferenceText(for: template, fallback: "this template"))."
        return "\(activeWorkoutPromptPrefix(for: workout)) \(openingTemplateRecoveryInstruction(for: workout)) \(templateSuffix)"
    }

    func activeWorkoutBlocksTemplateStartMessage(for workout: Workout, opening template: WorkoutTemplate) -> String {
        let templateSuffix = startTemplateBlockSuffix(for: template)
        return "\(activeWorkoutPromptPrefix(for: workout)) \(startingTemplateRecoveryInstruction(for: workout)) \(templateSuffix)"
    }

    private func openingTemplateRecoveryInstruction(for workout: Workout) -> String {
        HomeViewModel.resumableWorkoutRecoveryInstruction(for: workout)
    }

    private func startingTemplateRecoveryInstruction(for workout: Workout) -> String {
        HomeViewModel.resumableWorkoutRecoveryInstruction(for: workout)
    }

    private func startTemplateBlockSuffix(for template: WorkoutTemplate) -> String {
        let isPartialStart = isPartialTemplateStart(template)

        return isPartialStart
            ? "before starting the available part of \(templateReferenceText(for: template, fallback: "this template"))."
            : "before starting \(templateReferenceText(for: template, fallback: "this template"))."
    }

    private func templateReferenceText(for template: WorkoutTemplate, fallback: String) -> String {
        let templateName = WorkoutTemplate.normalizedDisplayName(template.name)
        return templateName == "Template"
            ? fallback
            : "Template “\(templateName)”"
    }

    enum TemplateQuickActionMode: Equatable {
        case none
        case startTemplate
        case activeWorkoutHandoff
        case continueOnly
    }

    func quickActionMode(
        for template: WorkoutTemplate,
        activeWorkoutBlocksStart: Bool,
        resumableWorkout: Workout?
    ) -> TemplateQuickActionMode {
        let canStartTemplate = templateManager.canStartWorkout(for: template)

        if activeWorkoutBlocksStart {
            guard resumableWorkout != nil else {
                return .none
            }

            return canStartTemplate ? .activeWorkoutHandoff : .continueOnly
        }

        return canStartTemplate ? .startTemplate : .none
    }

    func continueCurrentWorkoutButtonTitle(for workout: Workout) -> String {
        let actionPrefix = HomeViewModel.resumableWorkoutActionPrefix(for: workout)

        guard let displayName = WorkoutRow.specificDisplayName(for: workout) else {
            return "\(actionPrefix) Workout"
        }

        return "\(actionPrefix) “\(displayName)”"
    }

    private func resumeCurrentWorkoutSearchTitle(for workout: Workout) -> String {
        guard let displayName = WorkoutRow.specificDisplayName(for: workout) else {
            return "Resume Workout"
        }

        return "Resume “\(displayName)”"
    }

    private func statsRecoverySearchTerms(for workout: Workout) -> [String] {
        let statsViewModel = StatsViewModel()
        statsViewModel.resumableWorkout = workout
        let statsView = StatsView()

        return [
            statsViewModel.emptyStateMessage(),
            statsViewModel.emptyStateHint(),
            statsView.thisWeekSummaryMessage(totalWorkouts: 1, weeklyWorkoutCount: 0, resumableWorkout: workout),
            statsView.weeklyVolumeEmptyStateMessage(totalWorkouts: 1, resumableWorkout: workout),
            statsView.muscleGroupEmptyStateMessage(totalWorkouts: 1, resumableWorkout: workout),
            statsView.personalRecordsEmptyStateMessage(totalWorkouts: 1, resumableWorkout: workout)
        ]
    }

    func activeWorkoutInProgressTitle(for workout: Workout?) -> String {
        HomeViewModel.resumableWorkoutStatusTitle(for: workout)
    }

    func startTemplateButtonTitle(for template: WorkoutTemplate) -> String {
        "Start \(startTemplateActionTarget(for: template, partial: isPartialTemplateStart(template)))"
    }

    func quickStartTemplateButtonTitle(for template: WorkoutTemplate) -> String {
        "Start \(startTemplateActionTarget(for: template, partial: isPartialTemplateStart(template)))"
    }

    func saveAndStartTemplateButtonTitle(for template: WorkoutTemplate, currentWorkout: Workout? = nil) -> String {
        "\(saveCurrentWorkoutTitlePrefix(for: currentWorkout)) & Start \(startTemplateActionTarget(for: template, partial: isPartialTemplateStart(template)))"
    }

    func discardAndStartTemplateButtonTitle(for template: WorkoutTemplate, currentWorkout: Workout? = nil) -> String {
        "\(discardCurrentWorkoutTitlePrefix(for: currentWorkout)) & Start \(startTemplateActionTarget(for: template, partial: isPartialTemplateStart(template)))"
    }

    func discardCurrentWorkoutAndStartTemplateAlertTitle(for template: WorkoutTemplate, currentWorkout: Workout? = nil) -> String {
        "\(discardCurrentWorkoutTitlePrefix(for: currentWorkout)) & Start \(startTemplateActionTarget(for: template, partial: isPartialTemplateStart(template)))?"
    }

    func discardCurrentWorkoutAndStartTemplateAlertMessage(for template: WorkoutTemplate, currentWorkout: Workout? = nil) -> String {
        let templateTarget = startTemplateSentenceTarget(for: template, partial: isPartialTemplateStart(template))
        let sourceSummary = startTemplateSourceSummary(for: template)
        let currentWorkoutLead = discardCurrentWorkoutMessageSubject(for: currentWorkout)

        return "\(currentWorkoutLead) will be lost and RPT will immediately start \(templateTarget). Source template: \(sourceSummary). This action cannot be undone."
    }

    private func isPartialTemplateStart(_ template: WorkoutTemplate) -> Bool {
        templateManager.startWorkoutConfirmationMessage(for: template) != nil
    }

    private func discardCurrentWorkoutTitlePrefix(for workout: Workout?) -> String {
        guard let workout, let displayName = WorkoutRow.specificDisplayName(for: workout) else {
            return "Discard This Workout"
        }

        return "Discard “\(displayName)”"
    }

    private func saveCurrentWorkoutTitlePrefix(for workout: Workout?) -> String {
        guard let workout, let displayName = WorkoutRow.specificDisplayName(for: workout) else {
            return "Save This Workout"
        }

        return "Save “\(displayName)”"
    }

    private func discardCurrentWorkoutMessageSubject(for workout: Workout?) -> String {
        guard let workout, let displayName = WorkoutRow.specificDisplayName(for: workout) else {
            return "Your in-progress workout"
        }

        return "“\(displayName)”"
    }

    private func startTemplateActionTarget(for template: WorkoutTemplate, partial: Bool) -> String {
        let displayName = WorkoutTemplate.normalizedDisplayName(template.name)

        if displayName == "Template" {
            return partial ? "Partial Template" : "This Template"
        }

        return partial
            ? "Partial Template “\(displayName)”"
            : "Template “\(displayName)”"
    }

    private func startTemplateSentenceTarget(for template: WorkoutTemplate, partial: Bool) -> String {
        let displayName = WorkoutTemplate.normalizedDisplayName(template.name)

        if displayName == "Template" {
            return partial ? "the available part of this template" : "this template"
        }

        return partial
            ? "the available part of Template “\(displayName)”"
            : "Template “\(displayName)”"
    }

    private func startTemplateSourceSummary(for template: WorkoutTemplate) -> String {
        let exerciseCount = template.exercises.count
        let exerciseSummary = exerciseCount == 1 ? "1 exercise" : "\(exerciseCount) exercises"
        let plannedSetCount = template.exercises.reduce(0) { $0 + max($1.suggestedSets, 0) }
        let setSummary = plannedSetCount == 1 ? "1 planned set" : "\(plannedSetCount) planned sets"
        let hasExerciseNotes = template.exercises.contains { !($0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        let hasTemplateNotes = !template.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        var parts = [exerciseSummary, setSummary]

        if hasExerciseNotes {
            parts.append(hasTemplateNotes ? "exercise notes and template notes" : "exercise notes")
        } else if hasTemplateNotes {
            parts.append("template notes")
        }

        return Self.humanReadableList(parts)
    }

    func reviewTemplateButtonTitle(for template: WorkoutTemplate) -> String {
        let displayName = WorkoutTemplate.normalizedDisplayName(template.name)
        return displayName == "Template"
            ? "Review Template"
            : "Review “\(displayName)”"
    }

    func editTemplateButtonTitle(for template: WorkoutTemplate) -> String {
        let displayName = WorkoutTemplate.normalizedDisplayName(template.name)
        return displayName == "Template"
            ? "Edit Template"
            : "Edit “\(displayName)”"
    }

    static func templateEditorNavigationTitle(isNewTemplate: Bool, templateName: String) -> String {
        guard !isNewTemplate else {
            return "New Template"
        }

        let displayName = WorkoutTemplate.normalizedDisplayName(templateName)
        return displayName == "Template"
            ? "Edit Template"
            : "Edit “\(displayName)”"
    }

    static func templateDetailNavigationTitle(for templateName: String) -> String {
        let displayName = WorkoutTemplate.normalizedDisplayName(templateName)
        return displayName == "Template" ? "Template Details" : displayName
    }

    static func templateExerciseEditorNavigationTitle(for exerciseName: String) -> String {
        let displayName = TemplateExercise.normalizedDisplayName(exerciseName)
        return displayName == "Exercise" ? "Configure Exercise" : "Configure “\(displayName)”"
    }

    func duplicateTemplateButtonTitle(for template: WorkoutTemplate) -> String {
        let displayName = WorkoutTemplate.normalizedDisplayName(template.name)
        return displayName == "Template"
            ? "Duplicate Template"
            : "Duplicate “\(displayName)”"
    }

    func deleteTemplateButtonTitle(for template: WorkoutTemplate) -> String {
        let displayName = WorkoutTemplate.normalizedDisplayName(template.name)
        return displayName == "Template"
            ? "Delete Template"
            : "Delete “\(displayName)”"
    }

    func deleteTemplateAlertTitle(for template: WorkoutTemplate?) -> String {
        guard let template else {
            return "Delete Template?"
        }

        let displayName = WorkoutTemplate.normalizedDisplayName(template.name)
        return displayName == "Template"
            ? "Delete Template?"
            : "Delete “\(displayName)”?"
    }

    func deleteTemplateMessage(for template: WorkoutTemplate?) -> String {
        guard let template else {
            return "Delete this template? This action cannot be undone."
        }

        let displayName = WorkoutTemplate.normalizedDisplayName(template.name)
        let templateTarget = displayName == "Template"
            ? "Delete this template?"
            : "Delete “\(displayName)”?"
        let exerciseCount = template.exercises.count
        let exerciseSummary = exerciseCount == 1 ? "1 exercise" : "\(exerciseCount) exercises"
        let plannedSetCount = template.exercises.reduce(0) { $0 + max($1.suggestedSets, 0) }
        let setSummary = plannedSetCount == 1 ? "1 planned set" : "\(plannedSetCount) planned sets"
        let hasExerciseNotes = template.exercises.contains { !($0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        let hasTemplateNotes = !template.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        var impactParts = [exerciseSummary, setSummary]

        if hasExerciseNotes {
            impactParts.append(hasTemplateNotes ? "exercise notes and template notes" : "exercise notes")
        } else if hasTemplateNotes {
            impactParts.append("template notes")
        }

        return "\(templateTarget) This will remove \(Self.humanReadableList(impactParts)). This action cannot be undone."
    }

    func deleteTemplateFailureAlertTitle(for template: WorkoutTemplate?) -> String {
        guard let template else {
            return TemplateManager.DeletionResult.persistenceFailure.alertTitle
        }

        let displayName = WorkoutTemplate.normalizedDisplayName(template.name)
        return displayName == "Template"
            ? TemplateManager.DeletionResult.persistenceFailure.alertTitle
            : "Couldn’t Delete “\(displayName)”"
    }

    func deleteTemplateFailureMessage(for template: WorkoutTemplate?) -> String {
        guard let template else {
            return TemplateManager.DeletionResult.persistenceFailure.alertMessage
        }

        let displayName = WorkoutTemplate.normalizedDisplayName(template.name)
        return displayName == "Template"
            ? TemplateManager.DeletionResult.persistenceFailure.alertMessage
            : "“\(displayName)” is still in your templates. Please try again."
    }

    func startTemplateFailureAlertTitle(for template: WorkoutTemplate) -> String {
        "Couldn’t Start \(startTemplateActionTarget(for: template, partial: isPartialTemplateStart(template)))"
    }

    func startTemplateFailureMessage(for template: WorkoutTemplate) -> String {
        if let disabledMessage = templateManager.startWorkoutDisabledMessage(for: template) {
            return disabledMessage
        }

        return "RPT couldn’t start \(startTemplateSentenceTarget(for: template, partial: isPartialTemplateStart(template))) right now. Refresh the template and try again."
    }

    func activeWorkoutPersistenceFailureAlertTitle(
        for action: ActiveWorkoutPersistenceAction,
        opening template: WorkoutTemplate
    ) -> String {
        let templateTarget = startTemplateActionTarget(for: template, partial: isPartialTemplateStart(template))

        switch action {
        case .saveForLater:
            return "Couldn’t Save & Start \(templateTarget)"
        case .discard:
            return "Couldn’t Discard & Start \(templateTarget)"
        }
    }

    func activeWorkoutPersistenceFailureMessage(
        for action: ActiveWorkoutPersistenceAction,
        currentWorkout: Workout? = nil,
        opening template: WorkoutTemplate? = nil
    ) -> String {
        let templateRetryTarget: String

        if let template {
            templateRetryTarget = startTemplateSentenceTarget(for: template, partial: isPartialTemplateStart(template))
        } else {
            templateRetryTarget = "the template"
        }

        if let currentWorkout,
           let displayName = WorkoutRow.specificDisplayName(for: currentWorkout) {
            switch action {
            case .saveForLater:
                return "Couldn’t save “\(displayName)”. Keep it open, then try starting \(templateRetryTarget) again."
            case .discard:
                return "Couldn’t discard “\(displayName)”. Keep it open, then try starting \(templateRetryTarget) again."
            }
        }

        switch action {
        case .saveForLater:
            return "Couldn’t save this workout. Keep it open, then try starting \(templateRetryTarget) again."
        case .discard:
            return "Couldn’t discard this workout. Keep it open, then try starting \(templateRetryTarget) again."
        }
    }

    func startTemplateAfterPersistingActiveWorkout(
        _ activeWorkout: Workout,
        action: ActiveWorkoutPersistenceAction,
        opening template: WorkoutTemplate,
        persist: (Workout) -> Bool
    ) -> Result<Workout, String> {
        guard persistActiveWorkoutBeforeTemplateStart(activeWorkout, action: action, persist: persist) else {
            return .failure(activeWorkoutPersistenceFailureMessage(for: action, currentWorkout: activeWorkout, opening: template))
        }

        guard let startedWorkout = createWorkoutFromTemplate(template) else {
            return .failure(startTemplateFailureMessage(for: template))
        }

        return .success(startedWorkout)
    }

    static func templateSaveFailureAlertTitle(for templateName: String) -> String {
        let displayName = WorkoutTemplate.normalizedDisplayName(templateName)
        return displayName == "Template"
            ? "Couldn’t Save This Template"
            : "Couldn’t Save Template “\(displayName)”"
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
            let instructionTerms = Exercise.normalizedDisplayInstructions(exercise.instructions).map { [$0] } ?? []
            let terms = [
                exercise.category.rawValue,
                exercise.category.rawValue.capitalized
            ]
            + exercise.primaryMuscleGroups.map(\.displayName)
            + exercise.secondaryMuscleGroups.map(\.displayName)
            + Self.bodyRegionSearchTerms(
                primaryMuscleGroups: exercise.primaryMuscleGroups,
                secondaryMuscleGroups: exercise.secondaryMuscleGroups
            )
            + instructionTerms

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

    private func templateStructureSearchTerms(for template: WorkoutTemplate) -> [String] {
        let exerciseCount = template.exercises.count
        let exerciseSummary = exerciseCount == 1 ? "1 exercise" : "\(exerciseCount) exercises"
        let plannedSetCount = template.exercises.reduce(0) { $0 + max($1.suggestedSets, 0) }
        let plannedSetSummary = plannedSetCount == 1 ? "1 planned set" : "\(plannedSetCount) planned sets"
        let hasExerciseNotes = template.exercises.contains { !($0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        let hasTemplateNotes = !template.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        var terms = [
            exerciseSummary,
            plannedSetSummary,
            Self.humanReadableList([exerciseSummary, plannedSetSummary]),
            startTemplateSourceSummary(for: template)
        ]

        if hasExerciseNotes {
            terms.append("exercise notes")
        }

        if hasTemplateNotes {
            terms.append("template notes")
        }

        if hasExerciseNotes || hasTemplateNotes {
            terms.append("notes")
        }

        if hasExerciseNotes && hasTemplateNotes {
            terms.append("exercise notes and template notes")
        }

        return terms
    }

    private func crossFieldSearchCorpus(
        for template: WorkoutTemplate,
        activeWorkoutAvailable: Bool,
        blockedByActiveWorkout: Bool,
        activeWorkout: Workout?,
        exerciseMetadataLookup: [String: ExerciseSearchMetadata]
    ) -> String {
        let exerciseNames = template.exercises.map(\.exerciseName)
        let exerciseNotes = template.exercises.map(\.notes).filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let exercisePrescriptionTerms = template.exercises.flatMap { exercisePrescriptionSearchTerms(for: $0) }
        let exerciseMetadataTerms = exerciseMetadataSearchTerms(for: template, lookup: exerciseMetadataLookup)
        let issueTerms = issueSearchTerms(
            for: template,
            activeWorkoutAvailable: activeWorkoutAvailable,
            blockedByActiveWorkout: blockedByActiveWorkout,
            activeWorkout: activeWorkout
        )
        let structureTerms = templateStructureSearchTerms(for: template)

        return ([template.name, template.notes]
            + exerciseNames
            + exerciseNotes
            + exercisePrescriptionTerms
            + exerciseMetadataTerms
            + issueTerms
            + structureTerms)
            .joined(separator: " ")
    }

    private func sourceTemplateSearchTerms(for template: WorkoutTemplate) -> [String] {
        [
            "source template",
            WorkoutDetailView.sourceTemplateDescription(for: template)
        ] + visibleTemplateActionSearchTerms(for: template)
    }

    private func visibleTemplateActionSearchTerms(for template: WorkoutTemplate) -> [String] {
        [
            startTemplateButtonTitle(for: template),
            quickStartTemplateButtonTitle(for: template),
            reviewTemplateButtonTitle(for: template),
            editTemplateButtonTitle(for: template),
            duplicateTemplateButtonTitle(for: template),
            deleteTemplateButtonTitle(for: template),
            deleteTemplateAlertTitle(for: template)
        ]
    }

    private func issueSearchTerms(
        for template: WorkoutTemplate,
        activeWorkoutAvailable: Bool,
        blockedByActiveWorkout: Bool,
        activeWorkout: Workout? = nil
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
        let detailStatusSummary = templateManager.templateDetailStatusSummary(
            for: template,
            blockedByActiveWorkout: blockedByActiveWorkout,
            blockingWorkout: activeWorkout
        )
        let disabledStartMessage = templateManager.startWorkoutDisabledMessage(for: template)
        let partialStartConfirmation = templateManager.startWorkoutConfirmationMessage(for: template)

        var terms: [String] = [
            "review template",
            "review routine",
            "review workout plan",
            "review \(templateName)",
            "view template",
            "view routine",
            "view workout plan",
            "view \(templateName)",
            "view this template",
            "show template",
            "show routine",
            "show workout plan",
            "show \(templateName)",
            "show this template",
            "preview template",
            "preview routine",
            "preview workout plan",
            "preview \(templateName)",
            "preview this template",
            "inspect template",
            "inspect routine",
            "inspect workout plan",
            "inspect \(templateName)",
            "inspect this template",
            "browse template",
            "browse routine",
            "browse workout plan",
            "browse \(templateName)",
            "browse this template",
            "check out template",
            "check out routine",
            "check out workout plan",
            "check out \(templateName)",
            "check out this template",
            "check template",
            "check routine",
            "check workout plan",
            "check \(templateName)",
            "check this template",
            "find template",
            "find routine",
            "find workout plan",
            "find \(templateName)",
            "find this template",
            "find me \(templateName)",
            "search for template",
            "search for routine",
            "search for workout plan",
            "search for \(templateName)",
            "search for this template",
            "look up template",
            "look up routine",
            "look up workout plan",
            "look up \(templateName)",
            "look up this template",
            "lookup template",
            "lookup routine",
            "lookup workout plan",
            "lookup \(templateName)",
            "lookup this template",
            "open template",
            "open routine",
            "open workout plan",
            "open \(templateName)",
            "open this template",
            "template details",
            "routine details",
            "workout plan details",
            "template details \(templateName)",
            "routine details \(templateName)",
            "workout plan details \(templateName)",
            "details \(templateName)",
            "restart template",
            "restart routine",
            "restart workout plan",
            "restart \(templateName)",
            "restart this template",
            "rerun template",
            "rerun routine",
            "rerun workout plan",
            "rerun \(templateName)",
            "rerun this template",
            "repeat template",
            "repeat routine",
            "repeat workout plan",
            "repeat \(templateName)",
            "repeat this template",
            "edit template",
            "edit routine",
            "edit workout plan",
            "edit \(templateName)",
            "rename template",
            "rename routine",
            "rename workout plan",
            "rename \(templateName)",
            "rename this template",
            "delete template",
            "delete routine",
            "delete workout plan",
            "delete \(templateName)",
            "duplicate template",
            "duplicate routine",
            "duplicate workout plan",
            "duplicate \(templateName)",
            "copy template",
            "copy routine",
            "copy workout plan",
            "copy \(templateName)",
            "clone template",
            "clone routine",
            "clone workout plan",
            "clone \(templateName)",
            "clone this template",
            "\(templateName) copy",
            detailStatusSummary,
            startTemplateFailureAlertTitle(for: template),
            startTemplateFailureMessage(for: template)
        ] + sourceTemplateSearchTerms(for: template)

        if let disabledStartMessage {
            terms.append(disabledStartMessage)
        }

        if let partialStartConfirmation {
            terms.append(partialStartConfirmation)
        }

        if canStartWorkout {
            let isPartialStart = templateManager.startWorkoutConfirmationMessage(for: template) != nil

            terms.append(contentsOf: [
                "start workout",
                "start template",
                "start template \(templateName)",
                "start \(templateName)",
                "start this template",
                "ready",
                "ready to start",
                "available",
                "available exercises"
            ])

            if isPartialStart {
                terms.append(contentsOf: [
                    "start partial template",
                    "start partial template \(templateName)"
                ])
            }
        }

        if activeWorkoutAvailable {
            let openTemplateSuffix = templateName == "Template"
                ? "before opening this template."
                : "before opening \(templateName)."
            let startTemplateSuffix = startTemplateBlockSuffix(for: template)
            let isPartialStart = templateManager.startWorkoutConfirmationMessage(for: template) != nil
            let genericSaveAndStartTitle = saveAndStartTemplateButtonTitle(for: template)
            let genericDiscardAndStartTitle = discardAndStartTemplateButtonTitle(for: template, currentWorkout: nil)
            let genericDiscardAndStartAlertTitle = discardCurrentWorkoutAndStartTemplateAlertTitle(for: template, currentWorkout: nil)
            let genericSaveAndStartFailureTitle = activeWorkoutPersistenceFailureAlertTitle(for: .saveForLater, opening: template)
            let genericDiscardAndStartFailureTitle = activeWorkoutPersistenceFailureAlertTitle(for: .discard, opening: template)
            let genericSaveAndStartFailureMessage = activeWorkoutPersistenceFailureMessage(for: .saveForLater, opening: template)
            let genericDiscardAndStartFailureMessage = activeWorkoutPersistenceFailureMessage(for: .discard, opening: template)
            let genericBlockedStartMessage = templateManager.genericTemplateStartBlockMessage(for: template)
            let genericSaveForLaterActionLabel = HomeViewModel.saveForLaterActionLabel(for: nil)
            let genericSaveForLaterActionHint = HomeViewModel.saveForLaterActionHint(for: nil)
            let genericSaveForLaterRecoveryInstruction = HomeViewModel.saveForLaterRecoveryInstruction(for: nil)

            if let activeWorkout {
                terms.append(contentsOf: [
                    activeWorkoutPromptMessage(for: activeWorkout, opening: template),
                    continueCurrentWorkoutButtonTitle(for: activeWorkout),
                    "\(HomeViewModel.resumableWorkoutActionLabel(for: activeWorkout)) from Home",
                    resumeCurrentWorkoutSearchTitle(for: activeWorkout),
                    HomeViewModel.saveForLaterActionLabel(for: activeWorkout),
                    HomeViewModel.saveForLaterActionHint(for: activeWorkout),
                    HomeViewModel.saveForLaterRecoveryInstruction(for: activeWorkout),
                    activeWorkoutPersistenceFailureMessage(
                        for: .saveForLater,
                        currentWorkout: activeWorkout,
                        opening: template
                    ),
                    activeWorkoutPersistenceFailureMessage(
                        for: .discard,
                        currentWorkout: activeWorkout,
                        opening: template
                    )
                ])
                terms.append(contentsOf: statsRecoverySearchTerms(for: activeWorkout))
            }

            terms.append(contentsOf: [
                "current workout",
                "current workout in progress",
                "this workout",
                "this workout in progress",
                "workout in progress",
                "in progress",
                "resume current workout",
                "resume workout",
                "resume this workout",
                "resume it",
                "continue current workout",
                "continue workout",
                "finish current workout",
                "finish the current workout",
                "finish this workout",
                "finish workout",
                "open current workout",
                "open this workout",
                "open workout",
                "open it",
                "continue, save, or discard this workout before starting this template",
                "continue, use Save for Later, or discard this workout before starting this template",
                genericBlockedStartMessage,
                "add an exercise",
                "add an exercise to keep going",
                genericSaveForLaterActionLabel,
                genericSaveForLaterActionHint,
                genericSaveForLaterRecoveryInstruction,
                "save for later",
                "use save for later",
                "tap save for later",
                "save it for later",
                "save this workout for later",
                "discard workout",
                "discard current workout",
                "discard this workout",
                "discard it",
                "keep going",
                "keep going \(openTemplateSuffix)",
                "continue it",
                "continue it \(startTemplateSuffix)",
                "continue workout",
                "continue workout \(openTemplateSuffix)",
                "continue workout \(startTemplateSuffix)",
                "open it",
                "open it \(openTemplateSuffix)",
                "open it \(startTemplateSuffix)",
                "open workout",
                "open workout \(openTemplateSuffix)",
                "open workout \(startTemplateSuffix)",
                "add an exercise to keep going, use Save for Later, or discard it \(openTemplateSuffix)",
                "add an exercise to keep going, use Save for Later, or discard it \(startTemplateSuffix)",
                "add an exercise to keep going, \(genericSaveForLaterActionHint), or discard it \(openTemplateSuffix)",
                "add an exercise to keep going, \(genericSaveForLaterActionHint), or discard it \(startTemplateSuffix)",
                "add an exercise to keep going, save it for later, or discard it \(openTemplateSuffix)",
                "add an exercise to keep going, save it for later, or discard it \(startTemplateSuffix)",
                "continue workout, use Save for Later, or discard it \(openTemplateSuffix)",
                "continue workout, \(genericSaveForLaterRecoveryInstruction), or discard it \(openTemplateSuffix)",
                "continue it, use Save for Later, or discard it \(openTemplateSuffix)",
                "continue it, \(genericSaveForLaterRecoveryInstruction), or discard it \(openTemplateSuffix)",
                "continue it, save it for later, or discard it \(openTemplateSuffix)",
                "open workout, use Save for Later, or discard it \(openTemplateSuffix)",
                "open workout, \(genericSaveForLaterRecoveryInstruction), or discard it \(openTemplateSuffix)",
                "open it, use Save for Later, or discard it \(openTemplateSuffix)",
                "open it, \(genericSaveForLaterRecoveryInstruction), or discard it \(openTemplateSuffix)",
                "open it, save it for later, or discard it \(openTemplateSuffix)",
                "use Save for Later, discard it, or keep going \(openTemplateSuffix)",
                "\(genericSaveForLaterRecoveryInstruction), discard it, or keep going \(openTemplateSuffix)",
                "save it for later, discard it, or keep going \(openTemplateSuffix)",
                "continue workout, use Save for Later, or discard it \(startTemplateSuffix)",
                "continue workout, \(genericSaveForLaterRecoveryInstruction), or discard it \(startTemplateSuffix)",
                "continue it, use Save for Later, or discard it \(startTemplateSuffix)",
                "continue it, \(genericSaveForLaterRecoveryInstruction), or discard it \(startTemplateSuffix)",
                "continue it, save it for later, or discard it \(startTemplateSuffix)",
                "open workout, use Save for Later, or discard it \(startTemplateSuffix)",
                "open workout, \(genericSaveForLaterRecoveryInstruction), or discard it \(startTemplateSuffix)",
                "open it, use Save for Later, or discard it \(startTemplateSuffix)",
                "open it, \(genericSaveForLaterRecoveryInstruction), or discard it \(startTemplateSuffix)",
                "open it, save it for later, or discard it \(startTemplateSuffix)",
                "save open template",
                "save & open template",
                "save and open template",
                "save start template",
                "save & start template",
                "save and start template",
                genericSaveAndStartTitle,
                genericSaveAndStartFailureTitle,
                genericSaveAndStartFailureMessage,
                "discard open template",
                "discard & open template",
                "discard and open template",
                "discard start template",
                "discard & start template",
                "discard and start template",
                genericDiscardAndStartTitle,
                genericDiscardAndStartAlertTitle,
                genericDiscardAndStartFailureTitle,
                genericDiscardAndStartFailureMessage
            ])

            if isPartialStart {
                terms.append(contentsOf: [
                    "available part",
                    templateName == "Template"
                        ? "available part of this template"
                        : "available part of template \(templateName)",
                    "save partial template",
                    "save start partial template",
                    "save & start partial template",
                    "save and start partial template",
                    "save & start partial template \(templateName)",
                    "discard partial template",
                    "discard start partial template",
                    "discard & start partial template",
                    "discard and start partial template",
                    "discard & start partial template \(templateName)",
                    "continue it, use Save for Later, or discard it \(startTemplateSuffix)",
                    "continue it, save it for later, or discard it \(startTemplateSuffix)"
                ])
            }
        }

        if isOnlyBlockedByActiveWorkout {
            terms.append("blocked")

            if let activeWorkout {
                terms.append(contentsOf: [
                    continueCurrentWorkoutButtonTitle(for: activeWorkout),
                    activeWorkoutInProgressTitle(for: activeWorkout),
                    activeWorkoutBlocksTemplateStartMessage(for: activeWorkout, opening: template),
                    saveAndStartTemplateButtonTitle(for: template, currentWorkout: activeWorkout),
                    discardAndStartTemplateButtonTitle(for: template, currentWorkout: activeWorkout),
                    discardCurrentWorkoutAndStartTemplateAlertTitle(for: template, currentWorkout: activeWorkout),
                    discardCurrentWorkoutAndStartTemplateAlertMessage(for: template, currentWorkout: activeWorkout)
                ])
            }
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

        terms.append(
            templateManager.templateListExerciseSummary(
                for: template,
                blockedByActiveWorkout: isOnlyBlockedByActiveWorkout,
                blockingWorkout: activeWorkout
            )
        )
        terms.append(
            templateManager.templateDetailStatusSummary(
                for: template,
                blockedByActiveWorkout: isOnlyBlockedByActiveWorkout,
                blockingWorkout: activeWorkout
            )
        )
        terms.append(
            templateManager.startWorkoutActionTitle(
                for: template,
                blockedByActiveWorkout: isOnlyBlockedByActiveWorkout,
                blockingWorkout: activeWorkout
            )
        )

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
        activeWorkout: Workout?,
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
            blockedByActiveWorkout: blockedByActiveWorkout,
            activeWorkout: activeWorkout
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

        if let structurePriority = Self.searchTermMatchPriority(
            query: normalizedQuery,
            queryTokens: queryTokens,
            compactedQuery: compactedQuery,
            initialismQuery: initialismQuery,
            in: templateStructureSearchTerms(for: template)
        ) {
            return 32 + structurePriority
        }

        let crossFieldCorpus = crossFieldSearchCorpus(
            for: template,
            activeWorkoutAvailable: activeWorkoutAvailable,
            blockedByActiveWorkout: blockedByActiveWorkout,
            activeWorkout: activeWorkout,
            exerciseMetadataLookup: exerciseMetadataLookup
        )
        if Self.matchesQueryTokens(queryTokens, in: crossFieldCorpus) {
            return 38
        }

        return nil
    }

    func fetchTemplates(blockedByActiveWorkout: Bool = false, activeWorkout: Workout? = nil) -> [WorkoutTemplate] {
        let normalizedSearchLookups = Self.normalizedSearchLookupVariants(for: normalizedSearchText)
        let exerciseMetadataLookup = exerciseSearchMetadataLookup()

        return templates
            .enumerated()
            .compactMap { index, template in
                let templateCannotStartOnItsOwn = templateManager.startWorkoutDisabledMessage(for: template) != nil
                let isBlockedByActiveWorkout = blockedByActiveWorkout && !templateCannotStartOnItsOwn
                let searchPriority = normalizedSearchLookups.isEmpty
                    ? 0
                    : normalizedSearchLookups.compactMap { normalizedQuery in
                        searchMatchPriority(
                            template: template,
                            normalizedQuery: normalizedQuery,
                            activeWorkoutAvailable: blockedByActiveWorkout,
                            blockedByActiveWorkout: isBlockedByActiveWorkout,
                            activeWorkout: activeWorkout,
                            exerciseMetadataLookup: exerciseMetadataLookup
                        )
                    }.min()

                guard normalizedSearchLookups.isEmpty || searchPriority != nil else {
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
