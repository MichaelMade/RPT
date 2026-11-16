//
//  OneRepMax.swift
//  RPT
//
//  Estimated one-rep-max math. RPT progress is best judged by e1RM trend
//  rather than raw weight, since rep counts vary set to set.
//

import Foundation

enum OneRepMax {
    /// Epley: 1RM = w * (1 + r/30)
    static func epley(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        guard reps > 1 else { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    /// Brzycki: 1RM = w * 36 / (37 - r)
    static func brzycki(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        guard reps > 1 else { return weight }
        let clampedReps = min(reps, 36)
        return weight * 36.0 / (37.0 - Double(clampedReps))
    }

    /// RPT's standard estimate: Epley with reps clamped to 12, since rep-max
    /// formulas lose accuracy in higher rep ranges.
    static func estimate(weight: Int, reps: Int) -> Double {
        estimate(pounds: Double(weight), reps: reps)
    }

    /// The same estimate from an exact load, so a set logged in kilograms
    /// is not first rounded to a whole pound.
    static func estimate(pounds: Double, reps: Int) -> Double {
        guard pounds.isFinite, pounds > 0, reps > 0 else { return 0 }
        return epley(weight: pounds, reps: min(reps, 12))
    }

    /// Best estimated 1RM across a collection of completed working sets.
    static func bestEstimate(in sets: [ExerciseSet]) -> Double {
        sets
            .filter(\.isCompletedWorkingSet)
            .map { estimate(pounds: $0.exactPounds, reps: $0.reps) }
            .max() ?? 0
    }

    /// An estimate, which is always held in pounds, written in the
    /// lifter's unit.
    static func formatted(_ value: Double, unit: WeightUnit = .current) -> String {
        guard value.isFinite, value > 0 else { return "—" }
        return unit.formatted(pounds: value)
    }
}
