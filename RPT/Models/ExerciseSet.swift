//
//  ExerciseSet.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import Foundation
import SwiftData

@Model
final class ExerciseSet {
    /// The load in whole pounds. For a set entered in pounds this is the
    /// load. For a set entered in another unit it is the nearest whole
    /// pound, kept so every store written before units existed, and every
    /// comparison that only needs "heavier or lighter", still reads
    /// correctly. Write it through `setLoad(_:in:)`, never directly, so the
    /// exact load below cannot go stale.
    var weight: Int
    var reps: Int
    var completedAt: Date
    var isWarmup: Bool
    var rpe: Int? // Rate of Perceived Exertion (1-10)
    var notes: String
    /// Position of this set within its workout. SwiftData to-many
    /// relationships are unordered, so logged order must be persisted
    /// explicitly. Legacy rows default to 0 and fall back to
    /// `completedAt` ordering.
    var orderIndex: Int = 0

    /// The load exactly as entered, when it is not a whole number of
    /// pounds (a set logged in kilograms). `nil` for every set logged
    /// before units existed and for whole-pound sets, whose load is
    /// `weight`. Optional with no migration needed: see
    /// docs/data-migrations.md.
    var loadValue: Double? = nil
    /// `WeightUnit` raw value for `loadValue`. Set and cleared with it.
    var loadUnitRaw: String? = nil

    @Relationship(deleteRule: .nullify)
    var exercise: Exercise?

    @Relationship(deleteRule: .nullify)
    var workout: Workout?

    init(weight: Int,
         reps: Int,
         exercise: Exercise,
         workout: Workout? = nil,
         completedAt: Date = Date(),
         isWarmup: Bool = false,
         rpe: Int? = nil,
         notes: String = "",
         orderIndex: Int = 0) {
        self.weight = weight
        self.reps = reps
        self.exercise = exercise
        self.workout = workout
        self.completedAt = completedAt
        self.isWarmup = isWarmup
        self.rpe = rpe
        self.notes = notes
        self.orderIndex = orderIndex
    }

    static func hasCompletedValues(weight: Int, reps: Int, exerciseCategory: ExerciseCategory? = nil) -> Bool {
        guard reps > 0 else {
            return false
        }

        guard weight >= 0 else {
            return false
        }

        if weight > 0 {
            return true
        }

        return exerciseCategory == .bodyweight
    }

    var hasCompletedValues: Bool {
        Self.hasCompletedValues(weight: weight, reps: reps, exerciseCategory: exercise?.category)
    }

    var isCompletedLoggedSet: Bool {
        hasCompletedValues && completedAt != .distantPast
    }

    var isCompletedWorkingSet: Bool {
        !isWarmup && isCompletedLoggedSet
    }

    static func sanitizedRPE(_ rpe: Int?) -> Int? {
        guard let rpe, (1...10).contains(rpe) else {
            return nil
        }

        return rpe
    }

    var displayRPE: Int? {
        Self.sanitizedRPE(rpe)
    }

    /// Returns true when this set should rank above another set for "best set" selection.
    /// Priority: heavier weight, then higher reps, then more recent completion.
    func isBetterPerformance(than other: ExerciseSet) -> Bool {
        let load = exactPounds
        let otherLoad = other.exactPounds
        if abs(load - otherLoad) > 0.0001 {
            return load > otherLoad
        }

        if reps != other.reps {
            return reps > other.reps
        }

        return completedAt > other.completedAt
    }

    static func formattedWeightReps(weight: Int, reps: Int, exerciseCategory: ExerciseCategory? = nil) -> String {
        let safeWeight = max(0, weight)
        let safeReps = max(0, reps)
        let repsText = safeReps == 1 ? "1 rep" : "\(safeReps) reps"

        if safeWeight == 0, exerciseCategory == .bodyweight {
            return "BW × \(repsText)"
        }

        return "\(safeWeight) lb × \(repsText)"
    }

    /// The set as a lifter would read it, in the unit they train in.
    var formattedWeightReps: String {
        formattedLoadReps(in: .current)
    }

    func formattedLoadReps(in unit: WeightUnit) -> String {
        let safeReps = max(0, reps)
        let repsText = safeReps == 1 ? "1 rep" : "\(safeReps) reps"

        if weight <= 0, exercise?.category == .bodyweight {
            return "BW × \(repsText)"
        }

        return "\(unit.formatted(load(in: unit))) × \(repsText)"
    }
}

// MARK: - Load

extension ExerciseSet {
    /// Everything that defines a set's load, for restoring it after a save
    /// that did not go through.
    struct StoredLoad: Equatable {
        let weight: Int
        let loadValue: Double?
        let loadUnitRaw: String?
    }

    var storedLoad: StoredLoad {
        StoredLoad(weight: weight, loadValue: loadValue, loadUnitRaw: loadUnitRaw)
    }

    func restoreLoad(_ stored: StoredLoad) {
        weight = stored.weight
        loadValue = stored.loadValue
        loadUnitRaw = stored.loadUnitRaw
    }

    /// The unit this set's load was entered in.
    var loadUnit: WeightUnit {
        guard loadValue != nil, let loadUnitRaw, let unit = WeightUnit(rawValue: loadUnitRaw) else {
            return .pounds
        }
        return unit
    }

    /// The load in pounds, exact. Totals, estimates and records are
    /// computed from this, so a set logged as 100 kg counts as 220.46 lb
    /// and comes back as exactly 100 kg when shown in kilograms.
    var exactPounds: Double {
        load(in: .pounds)
    }

    /// The load in `unit`, exact. A set entered in that unit returns
    /// precisely what was typed.
    func load(in unit: WeightUnit) -> Double {
        if let loadValue, loadValue.isFinite, loadValue > 0,
           let loadUnitRaw, let storedUnit = WeightUnit(rawValue: loadUnitRaw) {
            return unit.converting(loadValue, from: storedUnit)
        }
        return unit.converting(Double(max(0, weight)), from: .pounds)
    }

    /// Records a load entered or suggested in `unit`.
    ///
    /// Whole pounds are stored the way they always were, in `weight` alone.
    /// Anything else keeps the exact value and its unit, with `weight` set
    /// to the nearest whole pound. A load that reads the same as the one
    /// already stored is left untouched, so saving a set from the editor in
    /// another unit without changing its weight does not degrade it.
    func setLoad(_ value: Double, in unit: WeightUnit) {
        let safeValue = unit.normalized(min(value.isFinite ? value : 0, unit.maximumLoad))

        let hasLoad = weight > 0 || loadValue != nil
        if hasLoad, unit.displaysSameLoad(safeValue, load(in: unit)) {
            return
        }

        guard safeValue > 0 else {
            weight = 0
            loadValue = nil
            loadUnitRaw = nil
            return
        }

        if unit == .pounds {
            weight = Int(safeValue)
            loadValue = nil
            loadUnitRaw = nil
            return
        }

        loadValue = safeValue
        loadUnitRaw = unit.rawValue
        // Never zero for a real load: zero means "no weight" throughout.
        weight = max(1, Int(WeightUnit.pounds.converting(safeValue, from: unit).rounded()))
    }

    /// Writes a whole-pound load, clearing any exact value. For the paths
    /// that still think in pounds.
    func setWholePounds(_ pounds: Int) {
        weight = max(0, pounds)
        loadValue = nil
        loadUnitRaw = nil
    }
}
