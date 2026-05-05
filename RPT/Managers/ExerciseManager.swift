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
        let workoutCount: Int
        let templateCount: Int

        var hasImpactDetails: Bool {
            loggedSetCount > 0 || workoutCount > 0 || templateCount > 0
        }
    }

    enum MutationResult: Equatable {
        case success
        case duplicateName
        case persistenceFailure

        var alertTitle: String {
            switch self {
            case .duplicateName:
                return "Exercise Already Exists"
            case .persistenceFailure, .success:
                return "Unable to Save Exercise"
            }
        }

        var alertMessage: String {
            switch self {
            case .duplicateName:
                return "An exercise with this name already exists. Please choose a different name."
            case .persistenceFailure:
                return "Your changes could not be saved right now. Please try again."
            case .success:
                return ""
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

    private let modelContext: ModelContext
    static let shared = ExerciseManager()
    private static let stableComparisonLocale = Locale(identifier: "en_US_POSIX")

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

    private init() {
        let dataManager = DataManager.shared
        self.modelContext = dataManager.getModelContext()
        // Default exercises are seeded by DataManager at container init time.
    }
    
    // MARK: - Fetch Operations
    
    func fetchAllExercises() -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func fetchExercise(withName name: String) -> Exercise? {
        let sanitizedName = Self.sanitizeExerciseName(name)
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate<Exercise> { $0.name == sanitizedName }
        )

        if let exactMatch = try? modelContext.fetch(descriptor).first {
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
        return (try? modelContext.fetch(descriptor)) ?? []
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
        guard validateDraft(name: name, primaryMuscleGroups: primaryMuscleGroups) == .valid else {
            return .duplicateName
        }

        let sanitizedName = Self.sanitizeExerciseName(name)

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
            try modelContext.save()
            return .success
        } catch {
            modelContext.delete(exercise)
            return .persistenceFailure
        }
    }
    
    @discardableResult
    func updateExercise(_ exercise: Exercise, name: String, category: ExerciseCategory, primaryMuscleGroups: [MuscleGroup], secondaryMuscleGroups: [MuscleGroup], instructions: String) -> MutationResult {
        guard validateDraft(name: name, primaryMuscleGroups: primaryMuscleGroups, excludingExerciseId: exercise.id) == .valid else {
            return .duplicateName
        }

        let sanitizedName = Self.sanitizeExerciseName(name)
        let originalName = exercise.name
        let originalCategory = exercise.category
        let originalPrimaryMuscles = exercise.primaryMuscleGroups
        let originalSecondaryMuscles = exercise.secondaryMuscleGroups
        let originalInstructions = exercise.instructions

        exercise.name = sanitizedName
        exercise.category = category
        exercise.primaryMuscleGroups = primaryMuscleGroups
        exercise.secondaryMuscleGroups = secondaryMuscleGroups
        exercise.instructions = instructions

        do {
            try modelContext.save()
            return .success
        } catch {
            exercise.name = originalName
            exercise.category = originalCategory
            exercise.primaryMuscleGroups = originalPrimaryMuscles
            exercise.secondaryMuscleGroups = originalSecondaryMuscles
            exercise.instructions = originalInstructions
            return .persistenceFailure
        }
    }
    
    func deleteExercise(_ exercise: Exercise) {
        // Only allow deletion of custom exercises
        if exercise.isCustom {
            modelContext.delete(exercise)
            try? modelContext.save()
        }
    }

    func deletionImpact(for exercise: Exercise) -> DeletionImpact {
        let loggedSets = exercise.sets.filter { $0.workout != nil }
        let workoutCount = Set(loggedSets.compactMap { $0.workout?.persistentModelID }).count
        let templateCount = fetchAllTemplatesReferencingExercise(named: exercise.name).count

        return DeletionImpact(
            loggedSetCount: loggedSets.count,
            workoutCount: workoutCount,
            templateCount: templateCount
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
    
}
