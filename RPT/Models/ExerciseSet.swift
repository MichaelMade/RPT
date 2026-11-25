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
    /// The whole number this set held as pounds before the lifter said
    /// their earlier workouts had been typed in kilograms. Written only by
    /// that relabel, and only so it can be undone exactly; `nil` on every
    /// other set. See `LoadHistoryRelabeler`.
    var relabeledFromPounds: Int? = nil

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

    /// The same rule for a load typed in any unit.
    static func hasCompletedValues(load: Double, reps: Int, exerciseCategory: ExerciseCategory? = nil) -> Bool {
        guard load.isFinite else { return false }
        return hasCompletedValues(weight: load > 0 ? 1 : 0, reps: reps, exerciseCategory: exerciseCategory)
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

        return "\(writtenLoad(in: unit)) \(unit.short) × \(repsText)"
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

        // An exact value with no readable unit cannot be trusted; `weight`
        // is the load in that case, so drop the leftover before comparing.
        if loadValue != nil, loadUnitRaw.flatMap(WeightUnit.init(rawValue:)) == nil {
            loadValue = nil
            loadUnitRaw = nil
        }

        // Clearing always clears. Otherwise a load that is the one already
        // stored is left exactly as it is.
        if safeValue > 0, weight > 0, isSameLoad(safeValue, in: unit) {
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

    /// The load to plan from in `unit`: exactly what was logged when it was
    /// logged in that unit, otherwise the nearest step that can be loaded.
    /// A 225 lb set is 102.06 kg, which nobody can put on a bar.
    func loadableLoad(in unit: WeightUnit) -> Double {
        loadUnit == unit ? load(in: unit) : unit.roundedToIncrement(load(in: unit))
    }

    /// The weight column: the number alone, "BW" for a bodyweight set with
    /// no added load, and `empty` when nothing has been entered.
    func loadText(in unit: WeightUnit, empty: String = "—") -> String {
        if weight <= 0 {
            return exercise?.category == .bodyweight ? "BW" : empty
        }
        return writtenLoad(in: unit)
    }

    /// What the weight field starts with when the set is opened for
    /// editing: blank when there is no load.
    func loadEntryText(in unit: WeightUnit) -> String {
        weight > 0 ? writtenLoad(in: unit) : ""
    }

    /// Whether `value`, typed in `unit`, is the load this set already holds.
    ///
    /// In the set's own unit that is a comparison of numbers: 7.3 over 7.26
    /// is a correction. In the other unit the stored load is only ever seen
    /// converted and rounded, so typing back what is shown (220 lb over
    /// 100 kg) is not a change.
    private func isSameLoad(_ value: Double, in unit: WeightUnit) -> Bool {
        if loadUnit == unit {
            return abs(value - load(in: unit)) < 0.001
        }
        return unit.displaysSameLoad(value, load(in: unit))
    }

    /// The load as it is written in `unit`, without the unit symbol:
    /// exactly as entered when it was entered in that unit, otherwise the
    /// conversion as a lifter would write it.
    func writtenLoad(in unit: WeightUnit) -> String {
        loadUnit == unit ? unit.exactString(for: load(in: unit)) : unit.string(for: load(in: unit))
    }

    /// Writes a whole-pound load, clearing any exact value. For the paths
    /// that still think in pounds.
    func setWholePounds(_ pounds: Int) {
        weight = max(0, pounds)
        loadValue = nil
        loadUnitRaw = nil
    }
}

// MARK: - Relabeling earlier history

extension ExerciseSet {
    /// Whether this set holds a bare whole number with no unit of its own,
    /// the way every load was stored while RPT only knew pounds. A set
    /// logged in kilograms carries its unit and is never one of these, and
    /// neither is a set already relabeled.
    ///
    /// A number above what a kilogram entry accepts is left alone: it could
    /// not be relabeled without being changed.
    ///
    /// A set logged in pounds today is stored the same way, so this alone
    /// does not make a set a candidate: see
    /// `canBeRelabeledAsKilograms(enteredBy:)`.
    var holdsUnlabeledWholePounds: Bool {
        weight > 0
            && Double(weight) <= WeightUnit.kilograms.maximumLoad
            && loadValue == nil
            && loadUnitRaw == nil
            && relabeledFromPounds == nil
    }

    /// When the lifter last stood behind this set's number: the moment it
    /// was logged, or, for a set that is still only planned, the day its
    /// workout was started.
    var loadEnteredAt: Date {
        if completedAt != .distantPast {
            return completedAt
        }
        return workout?.date ?? .distantPast
    }

    /// Whether a relabel may reinterpret this set, given the first moment
    /// the lifter's unit was kilograms.
    ///
    /// Before that moment the lifter had no way to say a number was
    /// kilograms, so a bare number may have been one. After it, a bare
    /// number was entered with the unit deliberately on pounds, and is
    /// pounds.
    func canBeRelabeledAsKilograms(enteredBy firstKilogramChoice: Date) -> Bool {
        holdsUnlabeledWholePounds && loadEnteredAt <= firstKilogramChoice
    }

    /// Reads the stored whole number as kilograms instead of pounds: a set
    /// stored as 100 becomes 100 kg. The number it held is remembered so
    /// `undoKilogramRelabel()` can put it back. Returns whether the set
    /// changed.
    @discardableResult
    func relabelAsKilograms() -> Bool {
        guard holdsUnlabeledWholePounds else { return false }

        let original = weight
        setLoad(Double(original), in: .kilograms)

        // The load setter is the one place that knows how a kilogram load
        // is stored. If it did not store exactly this number, leave the set
        // as it was instead of recording a relabel that cannot be undone.
        guard loadUnit == .kilograms, loadValue == Double(original) else {
            setWholePounds(original)
            return false
        }

        relabeledFromPounds = original
        return true
    }

    /// Puts back the whole-pound number a relabel replaced. Either way the
    /// set is no longer marked as relabeled. Returns whether the load was
    /// put back.
    ///
    /// Two kinds of set keep what they hold:
    /// - one whose load has been edited since the relabel, and
    /// - one logged after `firstKilogramChoice`. Only sets entered before
    ///   that moment were ever relabeled, so a later date means the lifter
    ///   has since logged the set at the kilogram load it showed. It is
    ///   their own kilogram entry now.
    @discardableResult
    func undoKilogramRelabel(keepingLoadsEnteredAfter firstKilogramChoice: Date? = nil) -> Bool {
        guard let original = relabeledFromPounds else { return false }
        relabeledFromPounds = nil

        if let firstKilogramChoice, loadEnteredAt > firstKilogramChoice {
            return false
        }

        guard original > 0,
              loadUnit == .kilograms,
              let loadValue,
              abs(loadValue - Double(original)) < 0.001 else {
            return false
        }

        setWholePounds(original)
        return true
    }
}
