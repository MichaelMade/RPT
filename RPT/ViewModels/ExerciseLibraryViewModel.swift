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

        if !qualifiers.isEmpty {
            summary += " " + qualifiers.joined(separator: " • ")
        }

        return summary
    }

    static func searchMatchPriority(exerciseName: String, normalizedQuery: String) -> Int? {
        guard !normalizedQuery.isEmpty else {
            return 0
        }

        let normalizedName = normalizedSearchLookupKey(exerciseName)
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

        if normalizedName.contains(normalizedQuery) {
            return 3
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
                    exerciseName: exercise.name,
                    normalizedQuery: normalizedSearchLookup
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
    
    func addExercise(name: String, category: ExerciseCategory, primaryMuscles: [MuscleGroup], secondaryMuscles: [MuscleGroup], instructions: String) {
        exerciseManager.addExercise(
            name: name,
            category: category,
            primaryMuscleGroups: primaryMuscles,
            secondaryMuscleGroups: secondaryMuscles,
            instructions: instructions
        )
        refreshExercises()
    }
    
    func updateExercise(_ exercise: Exercise, name: String, category: ExerciseCategory, primaryMuscles: [MuscleGroup], secondaryMuscles: [MuscleGroup], instructions: String) {
        exerciseManager.updateExercise(
            exercise,
            name: name,
            category: category,
            primaryMuscleGroups: primaryMuscles,
            secondaryMuscleGroups: secondaryMuscles,
            instructions: instructions
        )
        refreshExercises()
    }
    
    func deleteExercise(_ exercise: Exercise) {
        exerciseManager.deleteExercise(exercise)
        refreshExercises()
    }
}
