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

/// One step of a ramp, in the lifter's unit.
struct WarmupLoadStep: Equatable, Identifiable {
    let load: Double
    let reps: Int

    var id: String { "\(load)x\(reps)" }
}

enum WarmupPlanner {
    static let barWeight = 45

    /// Builds a low-fatigue ramp toward `topSetLoad`, in `unit`.
    ///
    /// Pattern: empty bar × 10, then 40% × 5, 60% × 3, 80% × 1, rounded to
    /// a loadable step (5 lb or 2.5 kg), deduplicated, and only including
    /// steps meaningfully below the top set.
    static func plan(topSetLoad: Double, unit: WeightUnit) -> [WarmupLoadStep] {
        let bar = unit.emptyBarLoad
        let safeTopSetLoad = topSetLoad.isFinite ? max(0, topSetLoad) : 0

        guard safeTopSetLoad > bar else {
            // Too light for a barbell ramp; a single empty-bar set is plenty.
            return safeTopSetLoad > 0 ? [WarmupLoadStep(load: 0, reps: 10)] : []
        }

        var steps: [WarmupLoadStep] = [WarmupLoadStep(load: bar, reps: 10)]

        let percentages: [(fraction: Double, reps: Int)] = [
            (0.4, 5),
            (0.6, 3),
            (0.8, 1)
        ]

        for stage in percentages {
            let rounded = max(bar, unit.roundedToIncrement(safeTopSetLoad * stage.fraction))
            guard rounded > (steps.last?.load ?? 0), rounded < safeTopSetLoad else {
                continue
            }
            steps.append(WarmupLoadStep(load: rounded, reps: stage.reps))
        }

        return steps
    }

    /// The ramp toward a whole-pound top set.
    static func plan(topSetWeight: Int) -> [WarmupStep] {
        plan(topSetLoad: Double(topSetWeight), unit: .pounds).map {
            WarmupStep(weight: Int($0.load), reps: $0.reps)
        }
    }
}
