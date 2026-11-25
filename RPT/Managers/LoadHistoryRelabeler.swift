//
//  LoadHistoryRelabeler.swift
//  RPT
//
//  RPT only knew pounds before it had a weight unit. A lifter who trains in
//  kilograms typed kilogram numbers into it anyway, so their history holds
//  "100" for a 100 kg lift and reads 45.4 kg once they switch the unit.
//  This relabels those bare whole numbers as kilograms when the lifter says
//  that is what they were, and can put every one of them back.
//
//  It is the only place that rewrites logged loads in bulk. Nothing here
//  runs unless the lifter asks for it.
//

import Foundation
import SwiftData

@MainActor
final class LoadHistoryRelabeler {
    typealias Preview = KilogramRelabelPolicy.Preview
    typealias Status = KilogramRelabelPolicy.Status

    enum Outcome: Equatable {
        case changed(sets: Int)
        case nothingToChange
        /// The store could not be read or saved. Nothing was changed.
        case failed
    }

    private let dataManager: DataManaging
    private let defaults: UserDefaults
    private let now: () -> Date

    private var modelContext: ModelContext {
        dataManager.getModelContext()
    }

    init(
        dataManager: DataManaging? = nil,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = { Date() }
    ) {
        self.dataManager = dataManager ?? DataManager.shared
        self.defaults = defaults
        self.now = now
    }

    // MARK: - What can be done

    /// Where earlier history stands for a lifter training in `unit`.
    ///
    /// Asking while the unit is kilograms also records, the first time,
    /// that the lifter has kilograms now: see `firstKilogramChoice`.
    func status(for unit: WeightUnit) -> Status {
        let relabeledCount = (try? modelContext.fetchCount(relabeledSetsDescriptor)) ?? 0
        let firstChoice = firstKilogramChoice(observing: unit)

        // The candidates are only read when they can matter: a pound
        // lifter with nothing relabeled never pays for the fetch.
        var preview: Preview?
        if relabeledCount == 0, unit == .kilograms, let firstChoice {
            preview = self.preview(enteredBy: firstChoice)
        }

        return KilogramRelabelPolicy.status(unit: unit, relabeledSetCount: relabeledCount, preview: preview)
    }

    /// What a relabel would change, or `nil` when there is nothing to
    /// relabel.
    private func preview(enteredBy firstChoice: Date) -> Preview? {
        guard let sets = try? unlabeledSets(enteredBy: firstChoice), !sets.isEmpty else {
            return nil
        }

        let logged = sets.filter(\.isCompletedLoggedSet)
        let example = logged.filter { !$0.isWarmup }.max { $0.completedAt < $1.completedAt }
            ?? logged.max { $0.completedAt < $1.completedAt }

        return Preview(
            setCount: sets.count,
            exerciseName: example?.exercise?.name,
            number: example?.weight
        )
    }

    /// The first moment the lifter's unit was kilograms.
    ///
    /// Nothing but the Settings picker changes the unit, and Settings asks
    /// for the status when it appears and on every switch, so the first
    /// time this is asked with kilograms is that moment, or as close to it
    /// as matters: no set can have been logged in between. Returns `nil`
    /// for a lifter who has only ever trained in pounds.
    private func firstKilogramChoice(observing unit: WeightUnit) -> Date? {
        let key = KilogramRelabelPolicy.firstKilogramChoiceDefaultsKey
        if let recorded = defaults.object(forKey: key) as? Date {
            return recorded
        }

        guard unit == .kilograms else {
            return nil
        }

        let moment = now()
        defaults.set(moment, forKey: key)
        return moment
    }

    /// The question to put to the lifter right after they switch to
    /// `unit`, or `nil` when it should not be asked.
    func question(afterSwitchingTo unit: WeightUnit) -> Preview? {
        // The status is read even when the answer is already known: a
        // switch to kilograms is when the first choice of them is recorded.
        let status = status(for: unit)
        return KilogramRelabelPolicy.question(hasAnswered: hasAnsweredPrompt, status: status)
    }

    var hasAnsweredPrompt: Bool {
        defaults.bool(forKey: KilogramRelabelPolicy.promptAnsweredDefaultsKey)
    }

    /// The lifter answered the question. Either answer counts.
    func recordPromptAnswered() {
        defaults.set(true, forKey: KilogramRelabelPolicy.promptAnsweredDefaultsKey)
    }

    // MARK: - Relabel and undo

    /// Reads every bare whole number entered before the lifter had
    /// kilograms as kilograms: a set stored as 100 becomes 100 kg. Sets
    /// logged in kilograms are not touched, and neither are sets logged in
    /// pounds after the lifter could choose.
    @discardableResult
    func relabelEarlierSetsAsKilograms() -> Outcome {
        // Asking for a relabel is itself a choice of kilograms.
        guard let firstChoice = firstKilogramChoice(observing: .kilograms) else {
            return .failed
        }

        let sets: [ExerciseSet]
        do {
            sets = try unlabeledSets(enteredBy: firstChoice)
        } catch {
            return .failed
        }

        let outcome = rewrite(sets) { $0.relabelAsKilograms() }
        if case .changed = outcome {
            recordPromptAnswered()
        }
        return outcome
    }

    /// Puts back the whole-pound number of every relabeled set that still
    /// holds the load the relabel gave it. A set edited since keeps its
    /// edit, and a set logged since keeps the load it was logged at.
    @discardableResult
    func undoRelabel() -> Outcome {
        let sets: [ExerciseSet]
        do {
            sets = try relabeledSets()
        } catch {
            return .failed
        }

        let firstChoice = defaults.object(forKey: KilogramRelabelPolicy.firstKilogramChoiceDefaultsKey) as? Date
        return rewrite(sets) { $0.undoKilogramRelabel(keepingLoadsEnteredAfter: firstChoice) }
    }

    // MARK: - Implementation

    private struct SetSnapshot {
        let exerciseSet: ExerciseSet
        let load: ExerciseSet.StoredLoad
        let relabeledFromPounds: Int?

        init(_ exerciseSet: ExerciseSet) {
            self.exerciseSet = exerciseSet
            self.load = exerciseSet.storedLoad
            self.relabeledFromPounds = exerciseSet.relabeledFromPounds
        }

        var isCurrent: Bool {
            exerciseSet.storedLoad == load && exerciseSet.relabeledFromPounds == relabeledFromPounds
        }

        func restore() {
            guard !isCurrent else { return }
            exerciseSet.restoreLoad(load)
            exerciseSet.relabeledFromPounds = relabeledFromPounds
        }
    }

    private struct UserSnapshot {
        let user: User
        let totalVolume: Double
        let personalBests: [String: Int]

        init(_ user: User) {
            self.user = user
            self.totalVolume = user.totalVolume
            self.personalBests = user.personalBests
        }

        func restore() {
            if user.totalVolume != totalVolume {
                user.totalVolume = totalVolume
            }
            if user.personalBests != personalBests {
                user.personalBests = personalBests
            }
        }
    }

    private struct TotalsCorrection {
        var volumeDelta = 0.0
        var exerciseNames: Set<String> = []
    }

    /// Applies `change` to each set and saves once. The lifetime totals a
    /// user stores are corrected for the sets that were already counted in
    /// them. If the save fails, every set and total is put back.
    private func rewrite(_ sets: [ExerciseSet], using change: (ExerciseSet) -> Bool) -> Outcome {
        guard !sets.isEmpty else {
            return .nothingToChange
        }

        // The context is shared with every other screen, and a rollback
        // discards everything unsaved in it. Whatever is pending is saved
        // first, so the rollback below can only ever discard this rewrite.
        if modelContext.hasChanges {
            do {
                try dataManager.saveChanges()
            } catch {
                return .failed
            }
        }

        var touched: [SetSnapshot] = []
        var corrections: [User: TotalsCorrection] = [:]
        var changedCount = 0

        for set in sets {
            let before = SetSnapshot(set)
            let poundsBefore = set.exactPounds
            let didChange = change(set)

            // An undo clears the mark on a set it leaves alone, so anything
            // that differs from before is kept for restoring, not only the
            // sets whose load changed.
            if !before.isCurrent {
                touched.append(before)
            }

            guard didChange else { continue }
            changedCount += 1

            // The same sets `User.updateStats(with:)` counted when their
            // workout was completed.
            guard set.isCompletedWorkingSet,
                  let workout = set.workout, workout.isCompleted,
                  let user = workout.user else {
                continue
            }

            var correction = corrections[user] ?? TotalsCorrection()
            correction.volumeDelta += (set.exactPounds - poundsBefore) * Double(set.reps)
            if let name = set.exercise?.name {
                correction.exerciseNames.insert(name)
            }
            corrections[user] = correction
        }

        guard !touched.isEmpty else {
            return .nothingToChange
        }

        let userSnapshots = corrections.keys.map(UserSnapshot.init)
        for (user, correction) in corrections {
            user.correctLoadTotals(volumeDelta: correction.volumeDelta, exerciseNames: correction.exerciseNames)
        }

        do {
            try dataManager.saveChanges()
        } catch {
            // Discard what the context holds, then make sure the objects in
            // memory agree with the store whatever the rollback left behind.
            modelContext.rollback()
            touched.forEach { $0.restore() }
            userSnapshots.forEach { $0.restore() }
            return .failed
        }

        let revisionKey = KilogramRelabelPolicy.revisionDefaultsKey
        defaults.set(defaults.integer(forKey: revisionKey) + 1, forKey: revisionKey)
        return changedCount > 0 ? .changed(sets: changedCount) : .nothingToChange
    }

    /// Sets a relabel may reinterpret. The fetch only narrows the rows and
    /// must never be the rule: the set itself decides, so there is one
    /// definition of a candidate. Every matching row is returned. A relabel
    /// that stopped part-way would leave a history in two units.
    private func unlabeledSets(enteredBy firstChoice: Date) throws -> [ExerciseSet] {
        let descriptor = FetchDescriptor<ExerciseSet>(
            predicate: #Predicate<ExerciseSet> { $0.loadUnitRaw == nil && $0.weight > 0 }
        )
        return try modelContext.fetch(descriptor).filter { $0.canBeRelabeledAsKilograms(enteredBy: firstChoice) }
    }

    private var relabeledSetsDescriptor: FetchDescriptor<ExerciseSet> {
        FetchDescriptor<ExerciseSet>(
            predicate: #Predicate<ExerciseSet> { $0.relabeledFromPounds != nil }
        )
    }

    private func relabeledSets() throws -> [ExerciseSet] {
        try modelContext.fetch(relabeledSetsDescriptor)
    }
}
