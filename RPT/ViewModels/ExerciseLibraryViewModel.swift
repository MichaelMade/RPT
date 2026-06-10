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

        return result.filter { matches($0, query: query) }
    }

    var hasActiveFilters: Bool {
        selectedCategory != nil || selectedMuscleGroup != nil || !searchText.trimmingCharacters(in: .whitespaces).isEmpty
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

    private func matches(_ exercise: Exercise, query: String) -> Bool {
        if normalized(exercise.name).contains(query) { return true }
        if normalized(exercise.category.rawValue).contains(query) { return true }
        if normalized(exercise.instructions).contains(query) { return true }

        let muscles = exercise.primaryMuscleGroups + exercise.secondaryMuscleGroups
        return muscles.contains { normalized($0.displayName).contains(query) }
    }

    private func normalized(_ text: String) -> String {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
