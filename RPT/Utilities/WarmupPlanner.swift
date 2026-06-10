//
//  WarmupPlanner.swift
//  RPT
//
//  Generates a warm-up ramp for a heavy top set. RPT programs warm up to
//  one all-out top set, so the ramp keeps reps low to avoid fatigue.
//

import Foundation

struct WarmupStep: Equatable, Identifiable {
    let weight: Int
    let reps: Int

    var id: String { "\(weight)x\(reps)" }
}

enum WarmupPlanner {
    static let barWeight = 45

    /// Builds a low-fatigue ramp toward `topSetWeight` (in lb).
    ///
    /// Pattern: empty bar × 10, then 40% × 5, 60% × 3, 80% × 1 — rounded to
    /// the nearest 5 lb, deduplicated, and only including steps meaningfully
    /// below the top set.
    static func plan(topSetWeight: Int) -> [WarmupStep] {
        guard topSetWeight > barWeight else {
            // Too light for a barbell ramp; a single empty-bar set is plenty.
            return topSetWeight > 0 ? [WarmupStep(weight: 0, reps: 10)] : []
        }

        var steps: [WarmupStep] = [WarmupStep(weight: barWeight, reps: 10)]

        let percentages: [(fraction: Double, reps: Int)] = [
            (0.4, 5),
            (0.6, 3),
            (0.8, 1)
        ]

        for stage in percentages {
            let raw = Double(topSetWeight) * stage.fraction
            let rounded = max(barWeight, Int((raw / 5.0).rounded() * 5.0))

            guard rounded > (steps.last?.weight ?? 0), rounded < topSetWeight else {
                continue
            }

            steps.append(WarmupStep(weight: rounded, reps: stage.reps))
        }

        return steps
    }
}
