//
//  WorkoutTemplateBuilder.swift
//  RPT
//
//  Turns a logged workout back into a reusable template: one template
//  exercise per movement, rep ranges seeded from the reps you actually
//  hit, and back-off percentages derived from the real weight drops.
//

import Foundation

enum WorkoutTemplateBuilder {
    /// Builds template exercises from a workout's non-warm-up sets,
    /// preserving exercise order. Exercises with no usable sets are skipped.
    static func templateExercises(from workout: Workout) -> [TemplateExercise] {
        workout.orderedExerciseGroups.compactMap { group in
            let workingSets = group.sets.filter { !$0.isWarmup && $0.reps > 0 }
            guard !workingSets.isEmpty else {
                return nil
            }

            let firstWeight = workingSets.first?.weight ?? 0

            let repRanges = workingSets.enumerated().map { index, set -> TemplateRepRange in
                let reps = max(1, set.reps)

                let percentage: Double?
                if index == 0 {
                    percentage = 1.0
                } else if firstWeight > 0, set.weight > 0 {
                    let ratio = Double(set.weight) / Double(firstWeight)
                    percentage = min(max(ratio, 0.1), 1.0)
                } else {
                    percentage = nil
                }

                return TemplateRepRange(
                    setNumber: index + 1,
                    minReps: reps,
                    maxReps: reps + 2,
                    percentageOfFirstSet: percentage
                )
            }

            return TemplateExercise(
                exerciseName: group.exercise.name,
                suggestedSets: workingSets.count,
                repRanges: repRanges,
                notes: ""
            )
        }
    }
}
