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
    enum TemplateExerciseIssue: Equatable {
        case missingFromLibrary
        case repeatedEntry

        var summary: String {
            switch self {
            case .missingFromLibrary:
                return "Missing from library • skipped until restored"
            case .repeatedEntry:
                return "Repeated entry • only the first copy will be added"
            }
        }
    }

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

    enum TemplateStatusTone: Equatable {
        case ready
        case warning
        case blockedByActiveWorkout
        case blocked
    }

    enum DuplicateExerciseMessageStyle {
        case helper
        case alert
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

    private static func normalizedStoredTemplateReference(_ raw: String?) -> String? {
        guard let raw else {
            return nil
        }

        let collapsed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsed.isEmpty else {
            return nil
        }

        return String(collapsed.prefix(80))
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
        let sanitizedName = Self.sanitizeTemplateName(name)
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate<WorkoutTemplate> { $0.name == sanitizedName }
        )

        if let exactMatch = try? modelContext.fetch(descriptor).first {
            return exactMatch
        }

        let normalizedLookup = Self.normalizedNameLookupKey(sanitizedName)
        return fetchAllTemplates().first {
            Self.normalizedNameLookupKey($0.name) == normalizedLookup
        }
    }

    func fetchTemplate(byId id: String) -> WorkoutTemplate? {
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate<WorkoutTemplate> { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func sourceTemplate(for workout: Workout) -> WorkoutTemplate? {
        if let sourceTemplateID = workout.startedFromTemplateID,
           let template = fetchTemplate(byId: sourceTemplateID) {
            return template
        }

        guard let sourceTemplateName = Self.normalizedStoredTemplateReference(workout.startedFromTemplate) else {
            return nil
        }

        return fetchTemplateByName(sourceTemplateName)
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

    func duplicateExerciseNames(in exercises: [TemplateExercise]) -> [String] {
        var firstDisplayNameByKey: [String: String] = [:]
        var duplicateExerciseNames: [String] = []
        var recordedDuplicateNames = Set<String>()

        for templateExercise in exercises {
            let normalizedExerciseName = ExerciseManager.normalizedNameLookupKey(templateExercise.exerciseName)
            let displayName = TemplateExercise.normalizedDisplayName(templateExercise.exerciseName)

            if let firstDisplayName = firstDisplayNameByKey[normalizedExerciseName] {
                guard recordedDuplicateNames.insert(normalizedExerciseName).inserted else {
                    continue
                }

                duplicateExerciseNames.append(firstDisplayName)
                continue
            }

            firstDisplayNameByKey[normalizedExerciseName] = displayName
        }

        return duplicateExerciseNames
    }

    func duplicateExerciseNames(in template: WorkoutTemplate) -> [String] {
        duplicateExerciseNames(in: template.exercises)
    }

    func duplicateExerciseMessage(
        for exercises: [TemplateExercise],
        style: DuplicateExerciseMessageStyle
    ) -> String {
        let duplicateNames = duplicateExerciseNames(in: exercises)
        guard !duplicateNames.isEmpty else {
            return DraftValidationResult.duplicateExercise.helperText ?? MutationResult.duplicateExercise.alertMessage
        }

        let subject: String
        if duplicateNames.count == 1 {
            subject = "\(duplicateNames[0]) appears more than once"
        } else if duplicateNames.count == 2 {
            subject = "\(duplicateNames[0]) and \(duplicateNames[1]) appear more than once"
        } else {
            let remainingCount = duplicateNames.count - 2
            let exerciseLabel = remainingCount == 1 ? "exercise" : "exercises"
            subject = "\(duplicateNames[0]), \(duplicateNames[1]), and \(remainingCount) more \(exerciseLabel) appear more than once"
        }

        switch style {
        case .helper:
            let object = duplicateNames.count == 1 ? "the extra copy" : "the extra copies"
            return "\(subject) in this template. Remove or replace \(object) to save."
        case .alert:
            let object = duplicateNames.count == 1 ? "the duplicate entry" : "the duplicate entries"
            return "\(subject) in this template. Remove or replace \(object) before saving."
        }
    }

    func startableExerciseNames(in template: WorkoutTemplate) -> [String] {
        uniqueResolvableTemplateExercises(in: template)
            .map { TemplateExercise.normalizedDisplayName($0.templateExercise.exerciseName) }
    }

    func availableExerciseCount(in template: WorkoutTemplate) -> Int {
        startableExerciseNames(in: template).count
    }

    func issues(for template: WorkoutTemplate, exerciseId: UUID) -> [TemplateExerciseIssue] {
        guard let exercise = template.exercises.first(where: { $0.id == exerciseId }) else {
            return []
        }

        let normalizedExerciseName = ExerciseManager.normalizedNameLookupKey(exercise.exerciseName)
        let firstOccurrenceId = template.exercises.first(where: {
            ExerciseManager.normalizedNameLookupKey($0.exerciseName) == normalizedExerciseName
        })?.id

        var issues: [TemplateExerciseIssue] = []

        if exerciseManager.fetchExercise(withName: exercise.exerciseName) == nil {
            issues.append(.missingFromLibrary)
        }

        if firstOccurrenceId != exercise.id {
            issues.append(.repeatedEntry)
        }

        return issues
    }

    func isExerciseIncludedWhenStartingWorkout(for template: WorkoutTemplate, exerciseId: UUID) -> Bool {
        guard let exercise = template.exercises.first(where: { $0.id == exerciseId }) else {
            return false
        }

        guard exerciseManager.fetchExercise(withName: exercise.exerciseName) != nil else {
            return false
        }

        let normalizedExerciseName = ExerciseManager.normalizedNameLookupKey(exercise.exerciseName)
        let firstOccurrenceId = template.exercises.first(where: {
            ExerciseManager.normalizedNameLookupKey($0.exerciseName) == normalizedExerciseName
        })?.id

        return firstOccurrenceId == exercise.id
    }

    func templateListExerciseSummary(
        for template: WorkoutTemplate,
        blockedByActiveWorkout: Bool = false,
        blockingWorkout: Workout? = nil
    ) -> String {
        let totalCount = template.exercises.count
        let uniqueCount = uniqueTemplateExerciseCount(in: template)
        let availableCount = availableExerciseCount(in: template)
        let unavailableCount = unavailableExerciseNames(in: template).count
        let duplicateCount = duplicateExerciseNames(in: template).count

        let baseSummary: String
        if totalCount == 0 {
            baseSummary = "No exercises yet • add at least 1 to start"
        } else if unavailableCount == 0 && duplicateCount == 0 {
            baseSummary = totalCount == 1 ? "1 exercise" : "\(totalCount) exercises"
        } else {
            let readySummary: String
            if duplicateCount > 0 {
                let uniqueLabel = uniqueCount == 1 ? "exercise" : "exercises"
                readySummary = availableCount == uniqueCount
                    ? "\(availableCount) unique \(uniqueLabel) ready"
                    : "\(availableCount) of \(uniqueCount) unique \(uniqueLabel) ready"
            } else {
                readySummary = totalCount == 1
                    ? "\(availableCount) of 1 exercise ready"
                    : "\(availableCount) of \(totalCount) exercises ready"
            }

            var issueParts: [String] = []
            if unavailableCount > 0 {
                issueParts.append(unavailableCount == 1 ? "1 missing" : "\(unavailableCount) missing")
            }
            if duplicateCount > 0 {
                issueParts.append(duplicateCount == 1 ? "1 repeated" : "\(duplicateCount) repeated")
            }

            baseSummary = ([readySummary] + issueParts).joined(separator: " • ")
        }

        guard blockedByActiveWorkout, canStartWorkout(for: template) else {
            return baseSummary
        }

        return baseSummary + " • " + activeWorkoutSummarySuffix(for: blockingWorkout)
    }

    func templateListPreviewExerciseNames(for template: WorkoutTemplate, maxCount: Int = 2) -> [String] {
        guard maxCount > 0 else {
            return []
        }

        let startableLookup = Set(
            uniqueResolvableTemplateExercises(in: template)
                .map { ExerciseManager.normalizedNameLookupKey($0.templateExercise.exerciseName) }
        )

        var firstDisplayNameByKey: [String: String] = [:]
        var orderedKeys: [String] = []
        var orderIndexByKey: [String: Int] = [:]

        for exercise in template.exercises {
            let normalizedName = ExerciseManager.normalizedNameLookupKey(exercise.exerciseName)
            guard firstDisplayNameByKey[normalizedName] == nil else {
                continue
            }

            firstDisplayNameByKey[normalizedName] = TemplateExercise.normalizedDisplayName(exercise.exerciseName)
            orderIndexByKey[normalizedName] = orderedKeys.count
            orderedKeys.append(normalizedName)
        }

        let prioritizedKeys = orderedKeys.sorted { lhs, rhs in
            let lhsIsStartable = startableLookup.contains(lhs)
            let rhsIsStartable = startableLookup.contains(rhs)

            if lhsIsStartable != rhsIsStartable {
                return lhsIsStartable && !rhsIsStartable
            }

            return (orderIndexByKey[lhs] ?? 0) < (orderIndexByKey[rhs] ?? 0)
        }

        return prioritizedKeys.prefix(maxCount).compactMap { firstDisplayNameByKey[$0] }
    }

    func templateListHasMoreUniqueExercisesToPreview(for template: WorkoutTemplate, maxCount: Int = 2) -> Bool {
        guard maxCount >= 0 else {
            return !template.exercises.isEmpty
        }

        var seenNames = Set<String>()

        for exercise in template.exercises {
            let normalizedName = ExerciseManager.normalizedNameLookupKey(exercise.exerciseName)
            guard seenNames.insert(normalizedName).inserted else {
                continue
            }

            if seenNames.count > maxCount {
                return true
            }
        }

        return false
    }

    func canStartWorkout(for template: WorkoutTemplate) -> Bool {
        availableExerciseCount(in: template) > 0
    }

    func templateStatusTone(for template: WorkoutTemplate, blockedByActiveWorkout: Bool = false) -> TemplateStatusTone {
        let unavailableCount = unavailableExerciseNames(in: template).count
        let duplicateCount = duplicateExerciseNames(in: template).count
        let canStartWorkout = canStartWorkout(for: template)

        if !canStartWorkout {
            return .blocked
        }

        if unavailableCount > 0 || duplicateCount > 0 {
            return .warning
        }

        if blockedByActiveWorkout {
            return .blockedByActiveWorkout
        }

        return .ready
    }

    func templateDetailStatusSummary(
        for template: WorkoutTemplate,
        blockedByActiveWorkout: Bool = false,
        blockingWorkout: Workout? = nil
    ) -> String {
        let availableCount = availableExerciseCount(in: template)
        let uniqueCount = uniqueTemplateExerciseCount(in: template)
        let unavailableCount = unavailableExerciseNames(in: template).count
        let duplicateCount = duplicateExerciseNames(in: template).count

        if availableCount == 0 {
            return startWorkoutDisabledMessage(for: template)
                ?? "This template can’t start right now. Edit it and try again."
        }

        let readySummary: String
        if unavailableCount == 0 && duplicateCount == 0 {
            readySummary = availableCount == 1
                ? "Ready to start with 1 exercise."
                : "Ready to start with \(availableCount) exercises."
        } else {
            let uniqueExerciseLabel = uniqueCount == 1 ? "exercise" : "exercises"
            readySummary = availableCount == uniqueCount
                ? (uniqueCount == 1
                    ? "Starts with its 1 unique exercise right now."
                    : "Starts with all \(uniqueCount) unique \(uniqueExerciseLabel) right now.")
                : "Starts with \(availableCount) of \(uniqueCount) unique \(uniqueExerciseLabel) right now."
        }

        var issueParts: [String] = []
        if unavailableCount > 0 {
            issueParts.append(unavailableCount == 1 ? "1 missing from your library" : "\(unavailableCount) missing from your library")
        }
        if duplicateCount > 0 {
            issueParts.append(duplicateCount == 1 ? "1 repeated entry" : "\(duplicateCount) repeated entries")
        }

        if blockedByActiveWorkout {
            issueParts.append(activeWorkoutStatusPrompt(for: blockingWorkout, starting: template))
        }

        guard !issueParts.isEmpty else {
            return readySummary
        }

        return readySummary + " " + issueParts.joined(separator: " • ") + "."
    }

    func startWorkoutActionTitle(
        for template: WorkoutTemplate,
        blockedByActiveWorkout: Bool = false,
        blockingWorkout: Workout? = nil
    ) -> String {
        let unavailableCount = unavailableExerciseNames(in: template).count
        let duplicateCount = duplicateExerciseNames(in: template).count

        guard canStartWorkout(for: template) else {
            return "Can't Start Template"
        }

        if blockedByActiveWorkout {
            return HomeViewModel.resumableWorkoutStatusTitle(for: blockingWorkout)
        }

        guard unavailableCount > 0 || duplicateCount > 0 else {
            return "Start Template"
        }

        return "Start Partial Template"
    }

    func genericTemplateStartBlockMessage(for template: WorkoutTemplate?) -> String {
        let saveForLaterText = HomeViewModel.saveForLaterRecoveryInstruction(for: nil)

        guard let template else {
            return "You already have a workout in progress. Continue, \(saveForLaterText), or discard this workout before starting this template"
        }

        return "You already have a workout in progress. Continue, \(saveForLaterText), or discard this workout before starting \(templateStartTargetText(for: template))"
    }

    private func templateStartTargetText(for template: WorkoutTemplate) -> String {
        let templateName = WorkoutTemplate.normalizedDisplayName(template.name)
        let templateReference = templateName == "Template"
            ? "this template"
            : "Template “\(templateName)”"

        return isPartialTemplateStart(template)
            ? "the available part of \(templateReference)"
            : templateReference
    }

    private func activeWorkoutSummarySuffix(for workout: Workout?) -> String {
        guard let workout else {
            return "workout in progress"
        }

        return HomeViewModel.resumableWorkoutStatusReference(for: workout)
    }

    private func activeWorkoutStatusPrompt(for workout: Workout?, starting template: WorkoutTemplate) -> String {
        guard let workout else {
            return genericTemplateStartBlockMessage(for: template)
        }

        let workoutSummary = HomeViewModel().resumableWorkoutSummary(for: workout)
        let statusLead = "You already have \(HomeViewModel.resumableWorkoutStatusReference(for: workout)): \(workoutSummary)."

        let startTarget = templateStartTargetText(for: template)
        let saveForLaterText = HomeViewModel.saveForLaterRecoveryInstruction(for: workout)
        let actionInstruction: String
        if workout.sets.isEmpty {
            if let displayName = WorkoutRow.specificDisplayName(for: workout) {
                actionInstruction = "Add an exercise to “\(displayName)” to keep going, \(saveForLaterText), or discard it before starting \(startTarget)"
            } else {
                actionInstruction = "Add an exercise to keep going, \(saveForLaterText), or discard it before starting \(startTarget)"
            }
        } else {
            let actionPrefix = HomeViewModel.resumableWorkoutActionPrefix(for: workout)

            if let displayName = WorkoutRow.specificDisplayName(for: workout) {
                actionInstruction = "\(actionPrefix) “\(displayName)”, \(saveForLaterText), or discard it before starting \(startTarget)"
            } else {
                actionInstruction = "\(actionPrefix) this workout, \(saveForLaterText), or discard it before starting \(startTarget)"
            }
        }

        return "\(statusLead) \(actionInstruction)"
    }

    func startWorkoutDisabledMessage(for template: WorkoutTemplate) -> String? {
        let availableCount = availableExerciseCount(in: template)
        guard availableCount == 0 else {
            return nil
        }

        if template.exercises.isEmpty {
            return "This template doesn’t have any exercises yet. Edit it to add at least one exercise before starting."
        }

        let unavailableCount = unavailableExerciseNames(in: template).count
        let duplicateCount = duplicateExerciseNames(in: template).count

        if unavailableCount > 0 {
            if duplicateCount > 0 {
                return "None of this template’s unique exercises are currently available in your library. Restore or replace the missing exercises before starting."
            }

            return unavailableCount == 1
                ? "This template can’t start right now because its only exercise is missing from your library. Restore or replace it before starting."
                : "This template can’t start right now because none of its exercises are currently available in your library. Restore or replace them before starting."
        }

        if duplicateCount > 0 {
            return "This template only contains repeated exercise entries right now. Edit it to keep at least one unique exercise before starting."
        }

        return "This template can’t start right now. Edit it and try again."
    }

    func partialStartConfirmationMessage(for template: WorkoutTemplate) -> String? {
        startWorkoutConfirmationMessage(for: template)
    }

    func startWorkoutConfirmationMessage(for template: WorkoutTemplate) -> String? {
        let unavailableExerciseNames = unavailableExerciseNames(in: template)
        let duplicateExerciseNames = duplicateExerciseNames(in: template)
        let availableCount = availableExerciseCount(in: template)

        guard availableCount > 0, !unavailableExerciseNames.isEmpty || !duplicateExerciseNames.isEmpty else {
            return nil
        }

        var summaryParts: [String] = []

        if !unavailableExerciseNames.isEmpty {
            if unavailableExerciseNames.count == 1 {
                summaryParts.append("1 template exercise will be skipped for now: \(unavailableExerciseNames[0]).")
            } else {
                let previewNames = unavailableExerciseNames.prefix(3).joined(separator: ", ")
                let remainingCount = unavailableExerciseNames.count - min(unavailableExerciseNames.count, 3)
                let suffix = remainingCount > 0 ? ", and \(remainingCount) more" : ""
                summaryParts.append("\(unavailableExerciseNames.count) template exercises will be skipped for now: \(previewNames)\(suffix).")
            }
        }

        if !duplicateExerciseNames.isEmpty {
            if duplicateExerciseNames.count == 1 {
                summaryParts.append("Repeated entries for \(duplicateExerciseNames[0]) will only be added once.")
            } else {
                let previewNames = duplicateExerciseNames.prefix(3).joined(separator: ", ")
                let remainingCount = duplicateExerciseNames.count - min(duplicateExerciseNames.count, 3)
                let suffix = remainingCount > 0 ? ", and \(remainingCount) more" : ""
                summaryParts.append("Repeated entries for \(previewNames)\(suffix) will only be added once each.")
            }
        }

        let availableSummary = availableCount == 1
            ? "Start this workout with the remaining 1 unique available exercise?"
            : "Start this workout with the remaining \(availableCount) unique available exercises?"

        summaryParts.append(availableSummary)
        return summaryParts.joined(separator: " ")
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
            try dataManager.saveChanges()
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
            try dataManager.saveChanges()
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
        let workout = Workout(
            name: template.name,
            startedFromTemplate: template.name,
            startedFromTemplateID: template.id
        )
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
            try dataManager.saveChanges()
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

        let normalizedUpdatedExerciseName = ExerciseManager.normalizedNameLookupKey(updatedExercise.exerciseName)
        guard !template.exercises.contains(where: {
            $0.id != exerciseId &&
            ExerciseManager.normalizedNameLookupKey($0.exerciseName) == normalizedUpdatedExerciseName
        }) else {
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

    private func uniqueTemplateExerciseCount(in template: WorkoutTemplate) -> Int {
        var seenExerciseNames = Set<String>()

        for templateExercise in template.exercises {
            let normalizedExerciseName = ExerciseManager.normalizedNameLookupKey(templateExercise.exerciseName)
            seenExerciseNames.insert(normalizedExerciseName)
        }

        return seenExerciseNames.count
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
