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
    /// The next top-set target, in `unit`.
    let suggestedLoad: Double
    let unit: WeightUnit
    let note: String

    /// The target as a whole number, for callers that think in pounds.
    var suggestedWeight: Int {
        Int(suggestedLoad.rounded())
    }

    /// The target exactly as it appears inside `note`.
    var formattedLoad: String {
        unit.formatted(suggestedLoad)
    }
}

enum ProgressionAdvisor {
    /// Suggests the next top-set target from the last completed top set.
    ///
    /// - Parameters:
    ///   - lastLoad: load of the most recent completed top working set, in `unit`
    ///   - unit: the unit the lifter trains in
    ///   - lastReps: reps achieved on that set
    ///   - repRange: the programmed rep range for the top set (e.g. 4...6)
    ///   - increment: smallest practical jump; defaults to the unit's
    ///     loadable step (5 lb or 2.5 kg) and is never smaller than it
    static func suggestion(
        lastLoad: Double,
        unit: WeightUnit,
        lastReps: Int,
        repRange: ClosedRange<Int> = 4...6,
        increment: Double? = nil
    ) -> ProgressionSuggestion {
        let safeLoad = lastLoad.isFinite ? max(0, lastLoad) : 0
        let safeIncrement = max(unit.loadIncrement, increment ?? unit.loadIncrement)

        guard safeLoad > 0, lastReps > 0 else {
            return ProgressionSuggestion(
                direction: .holdSteady,
                suggestedLoad: safeLoad,
                unit: unit,
                note: "Log a top set to get a progression target."
            )
        }

        if lastReps >= repRange.upperBound {
            let next = safeLoad + safeIncrement
            return ProgressionSuggestion(
                direction: .increaseWeight,
                suggestedLoad: next,
                unit: unit,
                note: "You hit \(lastReps) reps — load \(unit.formatted(next)) and aim for \(repRange.lowerBound)+ reps."
            )
        }

        if lastReps < repRange.lowerBound {
            let next = max(0, safeLoad - safeIncrement)
            return ProgressionSuggestion(
                direction: .reduceWeight,
                suggestedLoad: next,
                unit: unit,
                note: "Below the rep range — drop to \(unit.formatted(next)) and rebuild to \(repRange.upperBound) reps."
            )
        }

        return ProgressionSuggestion(
            direction: .addReps,
            suggestedLoad: safeLoad,
            unit: unit,
            note: "Stay at \(unit.formatted(safeLoad)) and push for \(lastReps + 1) reps."
        )
    }

    /// The same suggestion for a whole-pound top set.
    static func suggestion(
        lastWeight: Int,
        lastReps: Int,
        repRange: ClosedRange<Int> = 4...6,
        increment: Int = 5
    ) -> ProgressionSuggestion {
        suggestion(
            lastLoad: Double(max(0, lastWeight)),
            unit: .pounds,
            lastReps: lastReps,
            repRange: repRange,
            increment: Double(max(5, increment))
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
