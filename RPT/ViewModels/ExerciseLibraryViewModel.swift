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

    static let searchPrompt = "Search exercises, muscles, instruction cues, body regions, or movement types"

    private let exerciseManager: ExerciseManager

    init(exerciseManager: ExerciseManager? = nil) {
        self.exerciseManager = exerciseManager ?? ExerciseManager.shared
        refreshExercises()
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

        return result.filter { exercise in
            let searchableText = searchableText(for: exercise)
            if searchableText.contains(query) {
                return true
            }

            return queryTerms(from: query).allSatisfy { searchableText.contains($0) }
        }
    }

    var hasActiveFilters: Bool {
        selectedCategory != nil || selectedMuscleGroup != nil || !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func noMatchesDescription() -> String {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearch.isEmpty {
            return "No exercise matches your current search or filters. Search by name, muscle group, instruction cue, body region, or movement type."
        }

        return "No exercise matches “\(trimmedSearch)”. Search by name, muscle group, instruction cue, body region, or movement type."
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

    private func searchableText(for exercise: Exercise) -> String {
        let muscles = exercise.primaryMuscleGroups + exercise.secondaryMuscleGroups

        return [
            exercise.name,
            exercise.category.rawValue,
            exercise.instructions,
            muscles.map(\.displayName).joined(separator: " "),
            Self.bodyRegionSearchTerms(for: muscles).joined(separator: " ")
        ]
        .map(normalized)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    private func queryTerms(from query: String) -> [String] {
        query
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func bodyRegionSearchTerms(for muscleGroups: [MuscleGroup]) -> [String] {
        let uniqueGroups = Set(muscleGroups)
        var terms = Set<String>()

        let lowerBodyGroups: Set<MuscleGroup> = [.quadriceps, .hamstrings, .glutes, .calves]
        let upperBodyGroups: Set<MuscleGroup> = [.chest, .back, .shoulders, .biceps, .triceps, .forearms, .traps]
        let coreGroups: Set<MuscleGroup> = [.abs, .obliques, .lowerBack]
        let armGroups: Set<MuscleGroup> = [.biceps, .triceps, .forearms]

        let matchesLowerBody = !uniqueGroups.isDisjoint(with: lowerBodyGroups)
        let matchesUpperBody = !uniqueGroups.isDisjoint(with: upperBodyGroups)
        let matchesCore = !uniqueGroups.isDisjoint(with: coreGroups)

        if matchesLowerBody {
            terms.formUnion(["lower body", "leg", "legs"])
        }

        if matchesUpperBody {
            terms.insert("upper body")
        }

        if !uniqueGroups.isDisjoint(with: armGroups) {
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

    private func normalized(_ text: String) -> String {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
