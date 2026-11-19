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

    private var modelContext: ModelContext {
        dataManager.getModelContext()
    }

    init(dataManager: DataManaging? = nil, defaults: UserDefaults = .standard) {
        self.dataManager = dataManager ?? DataManager.shared
        self.defaults = defaults
    }

    // MARK: - What can be done

    /// Where earlier history stands for a lifter training in `unit`.
    func status(for unit: WeightUnit) -> Status {
        let relabeledCount = (try? modelContext.fetchCount(relabeledSetsDescriptor)) ?? 0

        // The candidates are only read when they can matter: a pound
        // lifter with nothing relabeled never pays for the fetch.
        let preview = relabeledCount == 0 && unit == .kilograms ? self.preview() : nil
        return KilogramRelabelPolicy.status(unit: unit, relabeledSetCount: relabeledCount, preview: preview)
    }

    /// What a relabel would change, or `nil` when there is nothing to
    /// relabel.
    func preview() -> Preview? {
        guard let sets = try? unlabeledSets(), !sets.isEmpty else {
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

    /// The question to put to the lifter right after they switch to
    /// `unit`, or `nil` when it should not be asked.
    func question(afterSwitchingTo unit: WeightUnit) -> Preview? {
        guard !hasAnsweredPrompt else { return nil }
        return KilogramRelabelPolicy.question(hasAnswered: hasAnsweredPrompt, status: status(for: unit))
    }

    var hasAnsweredPrompt: Bool {
        defaults.bool(forKey: KilogramRelabelPolicy.promptAnsweredDefaultsKey)
    }

    /// The lifter answered the question. Either answer counts.
    func recordPromptAnswered() {
        defaults.set(true, forKey: KilogramRelabelPolicy.promptAnsweredDefaultsKey)
    }

    // MARK: - Relabel and undo

    /// Reads every earlier bare whole number as kilograms: a set stored as
    /// 100 becomes 100 kg. Sets logged in kilograms are not touched.
    @discardableResult
    func relabelEarlierSetsAsKilograms() -> Outcome {
        let sets: [ExerciseSet]
        do {
            sets = try unlabeledSets()
        } catch {
            return .failed
        }

        let outcome = rewrite(sets) { $0.relabelAsKilograms() }
        if outcome != .failed {
            recordPromptAnswered()
        }
        return outcome
    }

    /// Puts back the whole-pound number of every relabeled set that still
    /// holds the load the relabel gave it. A set edited since keeps its
    /// edit.
    @discardableResult
    func undoRelabel() -> Outcome {
        let sets: [ExerciseSet]
        do {
            sets = try relabeledSets()
        } catch {
            return .failed
        }

        return rewrite(sets) { $0.undoKilogramRelabel() }
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

    /// Sets still holding a bare whole number. The fetch narrows the rows;
    /// the set itself decides, so there is one definition of a candidate.
    private func unlabeledSets() throws -> [ExerciseSet] {
        let descriptor = FetchDescriptor<ExerciseSet>(
            predicate: #Predicate<ExerciseSet> { $0.loadUnitRaw == nil && $0.weight > 0 }
        )
        return try modelContext.fetch(descriptor).filter(\.holdsUnlabeledWholePounds)
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
