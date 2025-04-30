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
    private let modelContext: ModelContext
    static let shared = ExerciseManager()
    
    private init() {
        let dataManager = DataManager.shared
        self.modelContext = dataManager.getModelContext()
        loadDefaultExercisesIfNeeded()
    }
    
    // MARK: - Fetch Operations
    
    func fetchAllExercises() -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func fetchExercise(withName name: String) -> Exercise? {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate<Exercise> { $0.name == name }
        )
        return try? modelContext.fetch(descriptor).first
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
    
    // MARK: - Mutation Operations
    
    func addExercise(name: String, category: ExerciseCategory, primaryMuscleGroups: [MuscleGroup], secondaryMuscleGroups: [MuscleGroup], instructions: String) {
        let exercise = Exercise(
            name: name,
            category: category,
            primaryMuscleGroups: primaryMuscleGroups,
            secondaryMuscleGroups: secondaryMuscleGroups,
            instructions: instructions,
            isCustom: true
        )
        
        modelContext.insert(exercise)
        try? modelContext.save()
    }
    
    func updateExercise(_ exercise: Exercise, name: String, category: ExerciseCategory, primaryMuscleGroups: [MuscleGroup], secondaryMuscleGroups: [MuscleGroup], instructions: String) {
        exercise.name = name
        exercise.category = category
        exercise.primaryMuscleGroups = primaryMuscleGroups
        exercise.secondaryMuscleGroups = secondaryMuscleGroups
        exercise.instructions = instructions
        
        try? modelContext.save()
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
    
    // MARK: - Private Methods
    
    private func loadDefaultExercisesIfNeeded() {
        var descriptor = FetchDescriptor<Exercise>()
        descriptor.fetchLimit = 1
        
        // Check if any exercises exist
        if let count = try? modelContext.fetchCount(descriptor), count > 0 {
            return // Exercises already exist
        }
        
        // Create default exercises
        let defaultExercises: [(String, ExerciseCategory, [MuscleGroup], [MuscleGroup], String)] = [
            // Compound exercises
            ("Barbell Bench Press", .compound, [.chest], [.triceps, .shoulders], "Lie on a bench and press the barbell from chest to full extension."),
            ("Barbell Squat", .compound, [.quadriceps], [.glutes, .hamstrings, .lowerBack], "Place bar on upper back, squat down until thighs are parallel to floor, then stand up."),
            ("Deadlift", .compound, [.back, .hamstrings], [.glutes, .quadriceps, .traps, .forearms], "Bend at hips and knees to grab bar, then stand up straight while keeping back flat."),
            ("Overhead Press", .compound, [.shoulders], [.triceps, .traps], "Press barbell from shoulders to overhead with straight arms."),
            ("Pull-up", .compound, [.back], [.biceps, .shoulders], "Hang from bar and pull yourself up until chin is over the bar."),
            ("Barbell Row", .compound, [.back], [.biceps, .shoulders, .traps], "Bend at hips with back flat, pull barbell to lower chest."),
            ("Dip", .compound, [.chest, .triceps], [.shoulders], "Support yourself on parallel bars, lower body until upper arms are parallel to floor, then push up."),
            
            // Isolation exercises
            ("Bicep Curl", .isolation, [.biceps], [.forearms], "Curl weight from full extension to full flexion."),
            ("Tricep Extension", .isolation, [.triceps], [], "Extend arms from flexed position to straight position."),
            ("Leg Extension", .isolation, [.quadriceps], [], "Extend knees from 90 degrees to full extension."),
            ("Leg Curl", .isolation, [.hamstrings], [], "Curl legs from straight position to full flexion."),
            ("Lateral Raise", .isolation, [.shoulders], [], "Raise arms out to sides until parallel with floor."),
            ("Calf Raise", .isolation, [.calves], [], "Raise heels off ground by extending ankles."),
            
            // Bodyweight exercises
            ("Push-up", .bodyweight, [.chest], [.triceps, .shoulders], "Lower body to ground and push back up with arms."),
            ("Body Weight Squat", .bodyweight, [.quadriceps], [.glutes, .hamstrings], "Squat down until thighs are parallel to floor, then stand up."),
            ("Lunge", .bodyweight, [.quadriceps], [.glutes, .hamstrings], "Step forward and lower body until both knees are at 90 degrees, then push back up.")
        ]
        
        for (name, category, primary, secondary, instructions) in defaultExercises {
            let exercise = Exercise(
                name: name,
                category: category,
                primaryMuscleGroups: primary,
                secondaryMuscleGroups: secondary,
                instructions: instructions,
                isCustom: false
            )
            modelContext.insert(exercise)
        }
        
        try? modelContext.save()
    }
}
