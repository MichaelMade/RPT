//
//  ProgressionAdvisor.swift
//  RPT
//
//  Double-progression coaching for reverse pyramid training: work within a
//  rep range, and once the top of the range is hit, add weight and drop
//  back to the bottom of the range.
//

import Foundation

struct ProgressionSuggestion: Equatable {
    enum Direction: Equatable {
        case increaseWeight
        case addReps
        case holdSteady
        case reduceWeight
    }

    let direction: Direction
    let suggestedWeight: Int
    let note: String
}

enum ProgressionAdvisor {
    /// Suggests the next top-set target from the last completed top set.
    ///
    /// - Parameters:
    ///   - lastWeight: weight of the most recent completed top working set (lb)
    ///   - lastReps: reps achieved on that set
    ///   - repRange: the programmed rep range for the top set (e.g. 4...6)
    ///   - increment: smallest practical jump (5 lb upper body, 10 lb legs)
    static func suggestion(
        lastWeight: Int,
        lastReps: Int,
        repRange: ClosedRange<Int> = 4...6,
        increment: Int = 5
    ) -> ProgressionSuggestion {
        let safeWeight = max(0, lastWeight)
        let safeIncrement = max(5, increment)

        guard safeWeight > 0, lastReps > 0 else {
            return ProgressionSuggestion(
                direction: .holdSteady,
                suggestedWeight: safeWeight,
                note: "Log a top set to get a progression target."
            )
        }

        if lastReps >= repRange.upperBound {
            let next = safeWeight + safeIncrement
            return ProgressionSuggestion(
                direction: .increaseWeight,
                suggestedWeight: next,
                note: "You hit \(lastReps) reps — load \(next) lb and aim for \(repRange.lowerBound)+ reps."
            )
        }

        if lastReps < repRange.lowerBound {
            let next = max(0, safeWeight - safeIncrement)
            return ProgressionSuggestion(
                direction: .reduceWeight,
                suggestedWeight: next,
                note: "Below the rep range — drop to \(next) lb and rebuild to \(repRange.upperBound) reps."
            )
        }

        return ProgressionSuggestion(
            direction: .addReps,
            suggestedWeight: safeWeight,
            note: "Stay at \(safeWeight) lb and push for \(lastReps + 1) reps."
        )
    }

    /// Per-set rep-range targets from a template exercise, falling back to a
    /// classic RPT 4–6 top-set scheme.
    static func topSetRepRange(for templateExercise: TemplateExercise?) -> ClosedRange<Int> {
        guard
            let firstRange = templateExercise?.repRanges.min(by: { $0.setNumber < $1.setNumber }),
            firstRange.minReps > 0,
            firstRange.maxReps >= firstRange.minReps
        else {
            return 4...6
        }

        return firstRange.minReps...firstRange.maxReps
    }
}
