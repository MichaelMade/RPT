//
//  ExerciseLibraryViewModel.swift
//  RPT
//
//  Exercise library state: search across names, muscles, categories, and
//  instructions, with category/muscle filters.
//

import Foundation
import SwiftUI

@MainActor
class ExerciseLibraryViewModel: ObservableObject {
    @Published var exercises: [Exercise] = []
    @Published var searchText: String = ""
    @Published var selectedCategory: ExerciseCategory? = nil
    @Published var selectedMuscleGroup: MuscleGroup? = nil

    static let searchPrompt = "Search exercises, custom moves, muscles, push/pull splits, instruction cues, body regions, or movement types"

    private let exerciseManager: ExerciseManager

    init(exerciseManager: ExerciseManager? = nil) {
        self.exerciseManager = exerciseManager ?? ExerciseManager.shared
    }

    var filteredExercises: [Exercise] {
        var result = exercises

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if let muscle = selectedMuscleGroup {
            result = result.filter {
                $0.primaryMuscleGroups.contains(muscle) || $0.secondaryMuscleGroups.contains(muscle)
            }
        }

        let query = normalized(searchText)
        guard !query.isEmpty else { return result }

        let queryTerms = queryTerms(from: query)

        return result
            .compactMap { exercise -> (exercise: Exercise, score: Int)? in
                let index = searchIndex(for: exercise)
                guard index.searchableText.contains(query) || queryTerms.allSatisfy({ index.searchableText.contains($0) }) else {
                    return nil
                }

                return (exercise, matchScore(for: exercise, index: index, query: query, queryTerms: queryTerms))
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }

                return lhs.exercise.displayName.localizedCaseInsensitiveCompare(rhs.exercise.displayName) == .orderedAscending
            }
            .map(\.exercise)
    }

    var hasActiveFilters: Bool {
        selectedCategory != nil || selectedMuscleGroup != nil || !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func noMatchesDescription() -> String {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearch.isEmpty {
            return "No exercise matches your current search or filters. Search by name, custom exercise, muscle group, push/pull split, instruction cue, body region, or movement type."
        }

        return "No exercise matches “\(trimmedSearch)”. Search by name, custom exercise, muscle group, push/pull split, instruction cue, body region, or movement type."
    }

    func refreshExercises() {
        exercises = exerciseManager.fetchAllExercises()
    }

    func clearFilters() {
        searchText = ""
        selectedCategory = nil
        selectedMuscleGroup = nil
    }

    func deleteExercise(_ exercise: Exercise) -> Bool {
        let result = exerciseManager.deleteExercise(exercise)
        refreshExercises()
        return result == .success
    }

    func deletionImpact(for exercise: Exercise) -> ExerciseManager.DeletionImpact {
        exerciseManager.deletionImpact(for: exercise)
    }

    // MARK: - Matching

    private struct SearchIndex {
        let searchableText: String
        let normalizedName: String
        let normalizedInstructions: String
        let normalizedCategory: String
        let normalizedMuscles: String
        let normalizedAliases: String
        let compactNameTerms: [String]
        let compactInstructionTerms: [String]
    }

    private func searchIndex(for exercise: Exercise) -> SearchIndex {
        let muscles = exercise.primaryMuscleGroups + exercise.secondaryMuscleGroups
        let compactNameTerms = ExerciseSearchAliases.compactSearchTerms(for: exercise.name).map(normalized)
        let compactInstructionTerms = ExerciseSearchAliases.compactSearchTerms(for: exercise.instructions).map(normalized)
        let normalizedName = normalized(exercise.name)
        let normalizedInstructions = normalized(exercise.instructions)
        let normalizedCategory = normalized(exercise.category.rawValue)
        let normalizedMuscles = normalized(muscles.map(\.displayName).joined(separator: " "))
        let normalizedAliases = normalized([
            ExerciseSearchAliases.bodyRegionTerms(for: muscles).joined(separator: " "),
            ExerciseSearchAliases.customTerms(isCustom: exercise.isCustom).joined(separator: " ")
        ].joined(separator: " "))

        let searchableText = [
            normalizedName,
            normalizedCategory,
            normalizedInstructions,
            normalizedMuscles,
            normalizedAliases,
            compactNameTerms.joined(separator: " "),
            compactInstructionTerms.joined(separator: " ")
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " ")

        return SearchIndex(
            searchableText: searchableText,
            normalizedName: normalizedName,
            normalizedInstructions: normalizedInstructions,
            normalizedCategory: normalizedCategory,
            normalizedMuscles: normalizedMuscles,
            normalizedAliases: normalizedAliases,
            compactNameTerms: compactNameTerms,
            compactInstructionTerms: compactInstructionTerms
        )
    }

    private func matchScore(for exercise: Exercise, index: SearchIndex, query: String, queryTerms: [String]) -> Int {
        var score = 0

        if index.normalizedName == query {
            score += 500
        } else if index.normalizedName.contains(query) {
            score += 300
        }

        if index.compactNameTerms.contains(where: { $0 == query || $0.contains(query) }) {
            score += 220
        }

        if index.normalizedInstructions.contains(query) {
            score += 140
        }

        if index.normalizedMuscles.contains(query) {
            score += 120
        }

        if index.normalizedAliases.contains(query) {
            score += 100
        }

        if index.normalizedCategory.contains(query) {
            score += 90
        }

        if index.compactInstructionTerms.contains(where: { $0 == query || $0.contains(query) }) {
            score += 80
        }

        score += queryTerms.reduce(into: 0) { partialResult, term in
            if index.normalizedName.contains(term) {
                partialResult += 35
            } else if index.normalizedMuscles.contains(term) {
                partialResult += 20
            } else if index.normalizedInstructions.contains(term) {
                partialResult += 18
            } else if index.normalizedAliases.contains(term) || index.normalizedCategory.contains(term) {
                partialResult += 15
            }
        }

        if exercise.isCustom {
            score += 5
        }

        return score
    }

    private func queryTerms(from query: String) -> [String] {
        query
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func normalized(_ text: String) -> String {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
