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

        return "Showing \(filteredCount) of \(exercises.count) exercises"
    }
    
    func fetchExercises() -> [Exercise] {
        let normalizedSearchText = normalizedSearchText
        let normalizedSearchLookup = Self.normalizedSearchLookupKey(normalizedSearchText)

        // Filter in memory based on search text and filters
        return exercises.filter { exercise in
            // Apply search filter
            let matchesSearch = normalizedSearchLookup.isEmpty ||
                                Self.normalizedSearchLookupKey(exercise.name).contains(normalizedSearchLookup)
            
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
            
            return matchesSearch && matchesCategory && matchesMuscleGroup
        }
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
