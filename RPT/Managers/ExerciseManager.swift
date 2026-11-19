//
//  ExerciseManager.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class ExerciseManager {
    struct DeletionImpact: Equatable {
        let loggedSetCount: Int
        let loggedWorkingSetCount: Int
        let loggedWarmupSetCount: Int
        let loggedWorkoutCount: Int
        let draftSetCount: Int
        let draftWorkoutCount: Int
        let templateCount: Int
        let templateNames: [String]

        var hasImpactDetails: Bool {
            loggedSetCount > 0 || draftSetCount > 0 || templateCount > 0
        }
    }

    enum MutationResult: Equatable {
        case success
        case missingName
        case noPrimaryMuscles
        case duplicateName
        case persistenceFailure

        var alertTitle: String {
            switch self {
            case .missingName:
                return "Exercise Name Required"
            case .noPrimaryMuscles:
                return "Primary Muscle Required"
            case .duplicateName:
                return "Exercise Already Exists"
            case .persistenceFailure, .success:
                return "Unable to Save Exercise"
            }
        }

        var alertMessage: String {
            switch self {
            case .missingName:
                return "Enter an exercise name before saving it to your library."
            case .noPrimaryMuscles:
                return "Select at least one primary muscle group before saving this exercise."
            case .duplicateName:
                return "An exercise with this name already exists. Please choose a different name."
            case .persistenceFailure:
                return "Your changes could not be saved right now. Please try again."
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
                return "Unable to Delete Exercise"
            }
        }

        var alertMessage: String {
            switch self {
            case .success:
                return ""
            case .persistenceFailure:
                return "This exercise could not be deleted right now. Please try again."
            }
        }
    }

    enum DraftValidationResult: Equatable {
        case valid
        case missingName
        case noPrimaryMuscles
        case duplicateName

        var helperText: String? {
            switch self {
            case .valid:
                return nil
            case .missingName:
                return "Enter an exercise name to save it to your library."
            case .noPrimaryMuscles:
                return "Select at least one primary muscle group before saving this exercise."
            case .duplicateName:
                return "An exercise with this name already exists. Choose a unique name to save."
            }
        }
    }

    private let dataManager: DataManaging
    private let modelContext: ModelContext
    static let shared = ExerciseManager()
    nonisolated private static let stableComparisonLocale = Locale(identifier: "en_US_POSIX")

    static func sanitizeExerciseName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsedWhitespace = trimmed.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )

        if collapsedWhitespace.isEmpty {
            return "Exercise"
        }

        return String(collapsedWhitespace.prefix(80))
    }

    static func normalizedNameLookupKey(_ name: String, locale: Locale = stableComparisonLocale) -> String {
        sanitizeExerciseName(name)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: locale)
    }

    static func namesCollide(_ lhs: String, _ rhs: String) -> Bool {
        normalizedNameLookupKey(lhs) == normalizedNameLookupKey(rhs)
    }

    init(dataManager: DataManaging? = nil) {
        let resolvedDataManager = dataManager ?? DataManager.shared
        self.dataManager = resolvedDataManager
        self.modelContext = resolvedDataManager.getModelContext()
        // Default exercises are seeded by DataManager at container init time.
    }
    
    // MARK: - Fetch Operations
    
    /// The exercise library: everything the lifter can pick, edit, or build
    /// a template from. Archived exercises are history only and are left out.
    func fetchAllExercises() -> [Exercise] {
        fetchEveryStoredExercise().filter { !$0.isArchived }
    }

    private func fetchEveryStoredExercise() -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// An archived custom exercise with this name, if the lifter removed one
    /// from their library earlier.
    private func fetchArchivedExercise(withName name: String) -> Exercise? {
        let lookupKey = Self.normalizedNameLookupKey(Self.sanitizeExerciseName(name))
        return fetchEveryStoredExercise().first {
            $0.isArchived && Self.normalizedNameLookupKey($0.name) == lookupKey
        }
    }
    
    func fetchExercise(withName name: String) -> Exercise? {
        let sanitizedName = Self.sanitizeExerciseName(name)
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate<Exercise> { $0.name == sanitizedName }
        )

        // An archived exercise can share its name with a live one, so take
        // the first match that is still in the library.
        if let exactMatch = (try? modelContext.fetch(descriptor))?.first(where: { !$0.isArchived }) {
            return exactMatch
        }

        let normalizedLookup = Self.normalizedNameLookupKey(sanitizedName)
        return fetchAllExercises().first {
            Self.normalizedNameLookupKey($0.name) == normalizedLookup
        }
    }
    
    func fetchExercise(byId id: PersistentIdentifier) -> Exercise? {
        return modelContext.model(for: id) as? Exercise
    }
    
    func fetchExercises(byCategory category: ExerciseCategory) -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate<Exercise> { $0.category == category },
            sortBy: [SortDescriptor(\.name)]
        )
        return ((try? modelContext.fetch(descriptor)) ?? []).filter { !$0.isArchived }
    }
    
    func fetchExercises(byMuscleGroup muscleGroup: MuscleGroup) -> [Exercise] {
        // This requires in-memory filtering since it's checking arrays
        let allExercises = fetchAllExercises()
        return allExercises.filter { exercise in
            exercise.primaryMuscleGroups.contains(muscleGroup) ||
            exercise.secondaryMuscleGroups.contains(muscleGroup)
        }
    }

    func validateDraft(
        name: String,
        primaryMuscleGroups: [MuscleGroup],
        excludingExerciseId excludedExerciseId: PersistentIdentifier? = nil
    ) -> DraftValidationResult {
        let sanitizedName = Self.sanitizeExerciseName(name)
        let hasMeaningfulName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard hasMeaningfulName else {
            return .missingName
        }

        guard !primaryMuscleGroups.isEmpty else {
            return .noPrimaryMuscles
        }

        let duplicateExists = fetchAllExercises().contains {
            $0.id != excludedExerciseId && Self.namesCollide($0.name, sanitizedName)
        }

        return duplicateExists ? .duplicateName : .valid
    }

    // MARK: - Mutation Operations

    @discardableResult
    func addExercise(name: String, category: ExerciseCategory, primaryMuscleGroups: [MuscleGroup], secondaryMuscleGroups: [MuscleGroup], instructions: String) -> MutationResult {
        let validationResult = validateDraft(name: name, primaryMuscleGroups: primaryMuscleGroups)
        guard validationResult == .valid else {
            return mutationResult(for: validationResult)
        }

        let sanitizedName = Self.sanitizeExerciseName(name)

        // Adding a name the lifter archived earlier brings that exercise
        // back, so its logged history picks up where it left off instead of
        // being split across two exercises with the same name.
        if let archived = fetchArchivedExercise(withName: sanitizedName) {
            return restoreArchivedExercise(
                archived,
                name: sanitizedName,
                category: category,
                primaryMuscleGroups: primaryMuscleGroups,
                secondaryMuscleGroups: secondaryMuscleGroups,
                instructions: instructions
            )
        }

        let exercise = Exercise(
            name: sanitizedName,
            category: category,
            primaryMuscleGroups: primaryMuscleGroups,
            secondaryMuscleGroups: secondaryMuscleGroups,
            instructions: instructions,
            isCustom: true
        )
        
        modelContext.insert(exercise)

        do {
            try dataManager.saveChanges()
            return .success
        } catch {
            modelContext.delete(exercise)
            return .persistenceFailure
        }
    }

    private func restoreArchivedExercise(
        _ exercise: Exercise,
        name: String,
        category: ExerciseCategory,
        primaryMuscleGroups: [MuscleGroup],
        secondaryMuscleGroups: [MuscleGroup],
        instructions: String
    ) -> MutationResult {
        let original = (
            name: exercise.name,
            category: exercise.category,
            primary: exercise.primaryMuscleGroups,
            secondary: exercise.secondaryMuscleGroups,
            instructions: exercise.instructions
        )

        exercise.name = name
        exercise.category = category
        exercise.primaryMuscleGroups = primaryMuscleGroups
        exercise.secondaryMuscleGroups = secondaryMuscleGroups
        exercise.instructions = instructions
        exercise.isArchived = false

        do {
            try dataManager.saveChanges()
            return .success
        } catch {
            exercise.name = original.name
            exercise.category = original.category
            exercise.primaryMuscleGroups = original.primary
            exercise.secondaryMuscleGroups = original.secondary
            exercise.instructions = original.instructions
            exercise.isArchived = true
            return .persistenceFailure
        }
    }
    
    @discardableResult
    func updateExercise(_ exercise: Exercise, name: String, category: ExerciseCategory, primaryMuscleGroups: [MuscleGroup], secondaryMuscleGroups: [MuscleGroup], instructions: String) -> MutationResult {
        let validationResult = validateDraft(
            name: name,
            primaryMuscleGroups: primaryMuscleGroups,
            excludingExerciseId: exercise.id
        )
        guard validationResult == .valid else {
            return mutationResult(for: validationResult)
        }

        let sanitizedName = Self.sanitizeExerciseName(name)
        let originalName = exercise.name
        let originalCategory = exercise.category
        let originalPrimaryMuscles = exercise.primaryMuscleGroups
        let originalSecondaryMuscles = exercise.secondaryMuscleGroups
        let originalInstructions = exercise.instructions
        let referencedTemplates = fetchAllTemplatesReferencingExercise(named: originalName)
        let originalTemplateExercisesById = Dictionary(
            uniqueKeysWithValues: referencedTemplates.map { ($0.id, $0.exercises) }
        )

        exercise.name = sanitizedName
        exercise.category = category
        exercise.primaryMuscleGroups = primaryMuscleGroups
        exercise.secondaryMuscleGroups = secondaryMuscleGroups
        exercise.instructions = instructions

        if !Self.namesCollide(originalName, sanitizedName) || originalName != sanitizedName {
            propagateExerciseRename(
                from: originalName,
                to: sanitizedName,
                across: referencedTemplates
            )
        }

        do {
            try dataManager.saveChanges()
            return .success
        } catch {
            exercise.name = originalName
            exercise.category = originalCategory
            exercise.primaryMuscleGroups = originalPrimaryMuscles
            exercise.secondaryMuscleGroups = originalSecondaryMuscles
            exercise.instructions = originalInstructions
            restoreTemplateExercises(
                from: originalTemplateExercisesById,
                across: referencedTemplates
            )
            return .persistenceFailure
        }
    }
    
    /// Removes a custom exercise from the library.
    ///
    /// Logged sets are the lifter's training history and are never deleted
    /// as a side effect of tidying the library. An exercise with logged sets
    /// is archived: it leaves the library, pickers, and template starts, its
    /// logged sets stay in history, and only its planned (unlogged) sets are
    /// removed. An exercise with nothing logged is deleted outright.
    @discardableResult
    func deleteExercise(_ exercise: Exercise) -> DeletionResult {
        // Only allow deletion of custom exercises
        guard exercise.isCustom else {
            return .persistenceFailure
        }

        // Same definition of history the confirmation dialog counts: a
        // logged set that belongs to a workout.
        let isHistory: (ExerciseSet) -> Bool = { $0.workout != nil && $0.isCompletedLoggedSet }
        let archives = exercise.sets.contains(where: isHistory)

        if archives {
            for otherSet in exercise.sets where !isHistory(otherSet) {
                modelContext.delete(otherSet)
            }
            exercise.isArchived = true
        } else {
            modelContext.delete(exercise)
        }

        do {
            try dataManager.saveChanges()
            return .success
        } catch {
            // Re-inserting a pending-delete object doesn't reliably resurrect
            // it; discarding the uncommitted changes does.
            modelContext.rollback()
            // Do not lean on rollback alone to put the exercise back in the
            // library: a hidden exercise the lifter was told is still there
            // is worse than a redundant assignment.
            if archives, exercise.isArchived {
                exercise.isArchived = false
            }
            return .persistenceFailure
        }
    }

    func deletionImpact(for exercise: Exercise) -> DeletionImpact {
        let workoutSets = exercise.sets.filter { $0.workout != nil }
        let loggedSets = workoutSets.filter(\.isCompletedLoggedSet)
        let loggedWorkingSetCount = loggedSets.filter { !$0.isWarmup }.count
        let loggedWarmupSetCount = loggedSets.filter(\.isWarmup).count
        let draftSets = workoutSets.filter { !$0.isCompletedLoggedSet }
        let loggedWorkoutCount = Set(loggedSets.compactMap { $0.workout?.persistentModelID }).count
        let draftWorkoutCount = Set(draftSets.compactMap { $0.workout?.persistentModelID }).count
        let referencingTemplates = fetchAllTemplatesReferencingExercise(named: exercise.name)
        let templateNames = referencingTemplates
            .map { WorkoutTemplate.normalizedDisplayName($0.name) }
            .sorted { lhs, rhs in
                Self.normalizedNameLookupKey(lhs) < Self.normalizedNameLookupKey(rhs)
            }

        return DeletionImpact(
            loggedSetCount: loggedSets.count,
            loggedWorkingSetCount: loggedWorkingSetCount,
            loggedWarmupSetCount: loggedWarmupSetCount,
            loggedWorkoutCount: loggedWorkoutCount,
            draftSetCount: draftSets.count,
            draftWorkoutCount: draftWorkoutCount,
            templateCount: referencingTemplates.count,
            templateNames: templateNames
        )
    }
    
    // MARK: - Analytics
    
    func getMostUsedExercises(limit: Int = 5) -> [Exercise] {
        let allExercises = fetchAllExercises()
        
        // Get exercise usage count by analyzing all sets
        var exerciseUsage: [PersistentIdentifier: Int] = [:]
        
        let setDescriptor = FetchDescriptor<ExerciseSet>()
        guard let allSets = try? modelContext.fetch(setDescriptor) else {
            return []
        }
        
        for set in allSets {
            if let exerciseId = set.exercise?.id {
                exerciseUsage[exerciseId, default: 0] += 1
            }
        }
        
        // Sort exercises by usage
        return allExercises
            .filter { exerciseUsage[$0.id, default: 0] > 0 }
            .sorted { exerciseUsage[$0.id, default: 0] > exerciseUsage[$1.id, default: 0] }
            .prefix(limit)
            .map { $0 }
    }

    private func fetchAllTemplatesReferencingExercise(named exerciseName: String) -> [WorkoutTemplate] {
        TemplateManager.shared.fetchAllTemplates().filter { template in
            template.exercises.contains { templateExercise in
                Self.namesCollide(templateExercise.exerciseName, exerciseName)
            }
        }
    }

    private func propagateExerciseRename(
        from originalName: String,
        to updatedName: String,
        across templates: [WorkoutTemplate]
    ) {
        for template in templates {
            template.exercises = template.exercises.map { templateExercise in
                guard Self.namesCollide(templateExercise.exerciseName, originalName) else {
                    return templateExercise
                }

                var updatedExercise = templateExercise
                updatedExercise.exerciseName = TemplateExercise.normalizedDisplayName(updatedName)
                return updatedExercise
            }
        }
    }

    private func restoreTemplateExercises(
        from originalExercisesByTemplateId: [String: [TemplateExercise]],
        across templates: [WorkoutTemplate]
    ) {
        for template in templates {
            guard let originalExercises = originalExercisesByTemplateId[template.id] else {
                continue
            }

            template.exercises = originalExercises
        }
    }

    private func mutationResult(for validationResult: DraftValidationResult) -> MutationResult {
        switch validationResult {
        case .valid:
            return .success
        case .missingName:
            return .missingName
        case .noPrimaryMuscles:
            return .noPrimaryMuscles
        case .duplicateName:
            return .duplicateName
        }
    }
    
}
