//
//  Workout.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import Foundation
import SwiftData

@Model
final class Workout {
    var date: Date
    var name: String
    var notes: String
    var duration: TimeInterval
    var isCompleted: Bool
    var startedFromTemplate: String?
    
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workout)
    var sets: [ExerciseSet]
    
    @Relationship(deleteRule: .nullify)
    var user: User?
    
    init(
        date: Date = Date(),
        name: String = "Workout",
        notes: String = "",
        duration: TimeInterval = 0,
        isCompleted: Bool = false,
        startedFromTemplate: String? = nil
    ) {
        self.date = date
        self.name = name
        self.notes = notes
        self.duration = duration
        self.isCompleted = isCompleted
        self.startedFromTemplate = startedFromTemplate
        self.sets = []
    }
    
    // Calculate exercise count
    var exerciseCount: Int {
        Set(sets.compactMap { $0.exercise }).count
    }
    
    // Calculate total volume from completed working sets only
    var totalVolume: Double {
        sets
            .filter(\.isCompletedWorkingSet)
            .reduce(0.0) { $0 + (Double($1.weight) * Double($1.reps)) }
    }

    // Calculate completed reps for bodyweight working sets
    var totalBodyweightReps: Int {
        sets
            .filter { $0.isCompletedWorkingSet && $0.exercise?.category == .bodyweight }
            .reduce(0) { $0 + $1.reps }
    }

    var hasPreferredWorkMetric: Bool {
        totalVolume > 0 || totalBodyweightReps > 0
    }

    var preferredWorkMetricTitle: String {
        if totalVolume > 0 {
            return "Volume"
        }

        if totalBodyweightReps > 0 {
            return "Reps"
        }

        return "Volume"
    }

    var preferredWorkMetricValue: String {
        if totalVolume > 0 {
            return formattedTotalVolume()
        }

        if totalBodyweightReps > 0 {
            return formattedTotalBodyweightReps()
        }

        return formattedTotalVolume()
    }
    
    // Calculate total working sets (completed, non-warmup)
    var workingSetsCount: Int {
        sets.filter(\.isCompletedWorkingSet).count
    }

    var hasLoggedWarmupOnly: Bool {
        workingSetsCount == 0 && sets.contains { $0.isWarmup && $0.isCompletedLoggedSet }
    }
    
    // Group sets by exercise
    var exerciseGroups: [Exercise: [ExerciseSet]] {
        let setsWithExercise = sets.compactMap { set -> (Exercise, ExerciseSet)? in
            guard let exercise = set.exercise else { return nil }
            return (exercise, set)
        }
        return Dictionary(grouping: setsWithExercise, by: { $0.0 }).mapValues { $0.map { $0.1 } }
    }

    // Group sets by exercise while preserving canonical logged order.
    // - Exercise order: first appearance in workout.sets.
    // - Set order: insertion order inside each exercise.
    var orderedExerciseGroups: [(exercise: Exercise, sets: [ExerciseSet])] {
        var grouped: [Exercise: [ExerciseSet]] = [:]
        var exerciseOrder: [Exercise] = []

        for set in sets {
            guard let exercise = set.exercise else { continue }

            if grouped[exercise] == nil {
                grouped[exercise] = []
                exerciseOrder.append(exercise)
            }

            grouped[exercise]?.append(set)
        }

        return exerciseOrder.compactMap { exercise in
            guard let sets = grouped[exercise], !sets.isEmpty else { return nil }
            return (exercise: exercise, sets: sets)
        }
    }

    func orderedSets(for exercise: Exercise) -> [ExerciseSet] {
        orderedExerciseGroups.first(where: { $0.exercise.id == exercise.id })?.sets ?? []
    }
    
    // Calculate best set for each exercise
    var bestSets: [Exercise: ExerciseSet] {
        var result: [Exercise: ExerciseSet] = [:]
        
        for (exercise, sets) in exerciseGroups {
            let completedWorkingSets = sets.filter(\.isCompletedWorkingSet)

            if let bestSet = completedWorkingSets.max(by: { lhs, rhs in
                rhs.isBetterPerformance(than: lhs)
            }) {
                result[exercise] = bestSet
            }
        }
        
        return result
    }
    
    // Mark workout as completed
    func complete() {
        isCompleted = true

        let safeDuration = duration.isFinite ? max(0, duration) : 0
        duration = safeDuration

        if duration == 0 {
            let rawDuration = Date().timeIntervalSince(date)
            duration = rawDuration.isFinite ? max(0, rawDuration) : 0
        }
    }
    
    // Add a new set to the workout
    func addSet(exercise: Exercise, weight: Int, reps: Int, isWarmup: Bool = false, rpe: Int? = nil) -> ExerciseSet {
        let isComplete = ExerciseSet.hasCompletedValues(
            weight: weight,
            reps: reps,
            exerciseCategory: exercise.category
        )

        let newSet = ExerciseSet(
            weight: weight,
            reps: reps,
            exercise: exercise,
            workout: self,
            completedAt: isComplete ? Date() : .distantPast,
            isWarmup: isWarmup,
            rpe: rpe
        )
        
        sets.append(newSet)
        return newSet
    }
    
    // Create a follow-up workout with the same exercises but increased weights
    func createFollowUpWorkout(percentageIncrease: Double = 0.025) -> Workout {
        let followUp = Workout(
            name: "Follow-up: \(name)",
            startedFromTemplate: startedFromTemplate
        )

        let safePercentageIncrease = percentageIncrease.isFinite ? max(0, percentageIncrease) : 0

        for (exercise, exerciseSets) in orderedExerciseGroups {
            let workingSets = exerciseSets.filter(\.isCompletedWorkingSet)
            guard !workingSets.isEmpty else { continue }

            guard let originalFirstWeight = workingSets.first?.weight else { continue }

            let shouldPreserveBodyweightLoads = originalFirstWeight == 0 && exercise.category == .bodyweight
            guard shouldPreserveBodyweightLoads || originalFirstWeight > 0 else { continue }

            var newFirstSetWeight = 0

            for (index, previousSet) in workingSets.enumerated() {
                let safePreviousWeight = max(0, previousSet.weight)
                let roundedWeight: Int

                if shouldPreserveBodyweightLoads {
                    roundedWeight = safePreviousWeight
                } else if index == 0 {
                    let calculatedWeight = Double(safePreviousWeight) * (1.0 + safePercentageIncrease)
                    roundedWeight = max(0, Int(round(calculatedWeight / 5.0) * 5.0))
                    newFirstSetWeight = roundedWeight
                } else {
                    let rawDropPercentage = 1.0 - (Double(safePreviousWeight) / Double(originalFirstWeight))
                    let safeDropPercentage = min(max(rawDropPercentage, 0), 1)
                    let calculatedWeight = Double(newFirstSetWeight) * (1.0 - safeDropPercentage)
                    roundedWeight = max(0, Int(round(calculatedWeight / 5.0) * 5.0))
                }

                let safeReps = max(0, previousSet.reps)
                let safeRPE = previousSet.rpe.flatMap { (1...10).contains($0) ? $0 : nil }

                let followUpSet = followUp.addSet(
                    exercise: exercise,
                    weight: roundedWeight,
                    reps: safeReps,
                    isWarmup: false,
                    rpe: safeRPE
                )
                followUpSet.completedAt = .distantPast
            }
        }

        return followUp
    }
    
    // Format total volume with lb unit
    func formattedTotalVolume() -> String {
        let safeTotalVolume = totalVolume.isFinite ? max(0, totalVolume) : 0
        let isWholeNumber = safeTotalVolume.truncatingRemainder(dividingBy: 1) == 0
        return isWholeNumber ? "\(Int(safeTotalVolume)) lb" : String(format: "%.1f lb", safeTotalVolume)
    }

    func formattedTotalBodyweightReps() -> String {
        let reps = max(0, totalBodyweightReps)
        return "\(reps) \(reps == 1 ? "rep" : "reps")"
    }

    func formattedDurationForSummary() -> String {
        let safeDuration = duration.isFinite ? max(0, duration) : 0
        let totalSeconds = Int(floor(safeDuration))

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            if seconds > 0 {
                return "\(hours)h \(minutes)m \(seconds)s"
            }

            return "\(hours)h \(minutes)m"
        }

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }

        return "\(seconds)s"
    }

    /// Backward-compatible summary API used by existing tests/callers.
    /// Returns the same output as `generateFormattedSummary()`.
    func generateSummary() -> String {
        generateFormattedSummary()
    }
    
    private func normalizedSummaryExerciseName(_ rawName: String) -> (display: String, key: String)? {
        let collapsedName = rawName
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedName.isEmpty else {
            return nil
        }

        let normalizedKey = collapsedName.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )

        return (display: collapsedName, key: normalizedKey)
    }

    private func normalizedSummaryWorkoutName() -> String {
        let collapsedName = name
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedName.isEmpty else {
            return "Workout"
        }

        return String(collapsedName.prefix(80))
    }

    private func normalizedSummaryNotes() -> String? {
        let collapsedNotes = notes
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedNotes.isEmpty else {
            return nil
        }

        return collapsedNotes
    }

    private func summaryExerciseNamesInOrder() -> [String] {
        var seenExerciseNames: Set<String> = []

        let completedExerciseNamesInOrder = sets.compactMap { set -> String? in
            guard set.isCompletedWorkingSet,
                  let exerciseName = set.exercise?.name,
                  let normalizedName = normalizedSummaryExerciseName(exerciseName)
            else {
                return nil
            }

            return seenExerciseNames.insert(normalizedName.key).inserted
                ? normalizedName.display
                : nil
        }

        if !completedExerciseNamesInOrder.isEmpty {
            return completedExerciseNamesInOrder
        }

        guard isCompleted else {
            return []
        }

        let fallbackSets = hasLoggedWarmupOnly
            ? sets
            : sets.filter { !$0.isWarmup }

        return fallbackSets.compactMap { set -> String? in
            guard let exerciseName = set.exercise?.name,
                  let normalizedName = normalizedSummaryExerciseName(exerciseName)
            else {
                return nil
            }

            return seenExerciseNames.insert(normalizedName.key).inserted
                ? normalizedName.display
                : nil
        }
    }

    private func summarySetCount() -> Int {
        let completedWorkingSetCount = workingSetsCount
        if completedWorkingSetCount > 0 {
            return completedWorkingSetCount
        }

        guard isCompleted else {
            return completedWorkingSetCount
        }

        let nonWarmupLoggedSetCount = sets.filter { !$0.isWarmup }.count
        return nonWarmupLoggedSetCount > 0 ? nonWarmupLoggedSetCount : sets.count
    }

    // Generate workout summary
    func generateFormattedSummary() -> String {
        let summaryExerciseNames = summaryExerciseNamesInOrder()
        let exerciseList = summaryExerciseNames.isEmpty
            ? "None"
            : summaryExerciseNames.joined(separator: ", ")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dateString = dateFormatter.string(from: date)
        
        let summaryWorkoutName = normalizedSummaryWorkoutName()

        var summary = "\(summaryWorkoutName) - \(dateString)\n"
        summary += "Exercises: \(exerciseList)\n"
        summary += "Sets: \(summarySetCount())\n"

        let safeDuration = duration.isFinite ? max(0, duration) : 0
        if safeDuration > 0 {
            summary += "Duration: \(formattedDurationForSummary())\n"
        }

        if totalVolume > 0 {
            summary += "Total Volume: \(formattedTotalVolume())\n"

            if totalBodyweightReps > 0 {
                summary += "Bodyweight Reps: \(formattedTotalBodyweightReps())\n"
            }
        } else if totalBodyweightReps > 0 {
            summary += "Total Reps: \(formattedTotalBodyweightReps())\n"
        } else if isCompleted, hasLoggedWarmupOnly {
            summary += "Work: Warm-up sets only\n"
        } else {
            summary += "Total Volume: \(formattedTotalVolume())\n"
        }
        
        if let normalizedNotes = normalizedSummaryNotes() {
            summary += "Notes: \(normalizedNotes)"
        }
        
        return summary
    }
}
