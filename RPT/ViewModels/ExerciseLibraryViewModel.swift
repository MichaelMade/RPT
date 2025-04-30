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
    
    init(exerciseManager: ExerciseManager? = nil) {
        self.exerciseManager = exerciseManager ?? ExerciseManager.shared
        refreshExercises()
    }
    
    func refreshExercises() {
        exercises = exerciseManager.fetchAllExercises()
    }
    
    func fetchExercises() -> [Exercise] {
        // Filter in memory based on search text and filters
        return exercises.filter { exercise in
            // Apply search filter
            let matchesSearch = searchText.isEmpty ||
                                exercise.name.localizedCaseInsensitiveContains(searchText)
            
            // Apply category filter
            let matchesCategory = selectedCategory == nil ||
                                  exercise.category == selectedCategory
            
            // Apply muscle group filter
            let matchesMuscleGroup = selectedMuscleGroup == nil ||
                                     exercise.primaryMuscleGroups.contains(selectedMuscleGroup!) ||
                                     exercise.secondaryMuscleGroups.contains(selectedMuscleGroup!)
            
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
