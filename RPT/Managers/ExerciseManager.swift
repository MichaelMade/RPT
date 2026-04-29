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
    func addExercise(name: String, category: ExerciseCategory, primaryMuscleGroups: [MuscleGroup], secondaryMuscleGroups: [MuscleGroup], instructions: String) -> Bool {
        guard validateDraft(name: name, primaryMuscleGroups: primaryMuscleGroups) == .valid else {
            return false
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
        try? modelContext.save()
        return true
    }
    
    @discardableResult
    func updateExercise(_ exercise: Exercise, name: String, category: ExerciseCategory, primaryMuscleGroups: [MuscleGroup], secondaryMuscleGroups: [MuscleGroup], instructions: String) -> Bool {
        guard validateDraft(name: name, primaryMuscleGroups: primaryMuscleGroups, excludingExerciseId: exercise.id) == .valid else {
            return false
        }

        let sanitizedName = Self.sanitizeExerciseName(name)

        exercise.name = sanitizedName
        exercise.category = category
        exercise.primaryMuscleGroups = primaryMuscleGroups
        exercise.secondaryMuscleGroups = secondaryMuscleGroups
        exercise.instructions = instructions
        
        try? modelContext.save()
        return true
    }
    
    func deleteExercise(_ exercise: Exercise) {
        // Only allow deletion of custom exercises
        if exercise.isCustom {
            modelContext.delete(exercise)
            try? modelContext.save()
        }
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
    
}
