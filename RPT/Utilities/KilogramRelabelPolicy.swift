//
//  KilogramRelabelPolicy.swift
//  RPT
//
//  The rules and wording for relabeling earlier history as kilograms.
//  Pure: no store, no UI. `LoadHistoryRelabeler` does the rewriting.
//

import Foundation

enum KilogramRelabelPolicy {
    /// Set once the lifter has answered the question either way, so
    /// switching units again does not ask a second time.
    static let promptAnsweredDefaultsKey = "training.kilogramRelabelPromptAnswered"
    /// Counts relabels and undos. The tab shell rebuilds the other tabs when
    /// it changes, so no screen keeps showing the loads from before.
    static let revisionDefaultsKey = "training.loadHistoryRevision"
    /// What a relabel would change, for the question put to the lifter.
    struct Preview: Equatable {
        /// Sets still holding a bare whole number.
        let setCount: Int
        /// The most recent logged set among them, so the question can use a
        /// lift and a number the lifter recognizes. `nil` when none of them
        /// has been logged yet.
        let exerciseName: String?
        let number: Int?
    }

    /// Where earlier history stands, for the Settings row.
    enum Status: Equatable {
        /// Nothing to ask and nothing to undo.
        case nothingToOffer
        /// The lifter trains in kilograms and earlier sets are still read
        /// as pounds. They can be relabeled.
        case readAsPounds(Preview)
        /// Earlier sets were relabeled as kilograms. That can be undone.
        case relabeled(setCount: Int)
    }

    /// An undo is offered in either unit, for as long as relabeled sets
    /// exist. A relabel is only offered to a lifter training in kilograms:
    /// in pounds there is no question to ask.
    static func status(unit: WeightUnit, relabeledSetCount: Int, preview: Preview?) -> Status {
        if relabeledSetCount > 0 {
            return .relabeled(setCount: relabeledSetCount)
        }

        guard unit == .kilograms, let preview, preview.setCount > 0 else {
            return .nothingToOffer
        }

        return .readAsPounds(preview)
    }

    /// The question to raise unprompted right after a unit switch, or `nil`
    /// when it should not be raised: the lifter has answered it before, or
    /// there is nothing to relabel in the unit they switched to.
    static func question(hasAnswered: Bool, status: Status) -> Preview? {
        guard !hasAnswered, case .readAsPounds(let preview) = status else {
            return nil
        }

        return preview
    }

    static let questionTitle = "Were your earlier workouts logged in kilograms?"
    static let relabelAnswer = "They Were Kilograms"
    static let keepAnswer = "They Were Pounds"

    /// The question's explanation. It is written from what is stored, not
    /// from a guess about the lifter's history: how many sets are held as
    /// pounds, and what the most recent of them reads now and would read.
    static func questionMessage(for preview: Preview) -> String {
        let kilograms = WeightUnit.kilograms
        let isSingle = preview.setCount == 1
        let number = preview.number ?? 100
        let shownNow = kilograms.formatted(pounds: Double(number))
        let shownAfter = kilograms.formatted(Double(number))

        let stored = isSingle
            ? "RPT stored 1 earlier set as pounds."
            : "RPT stored \(preview.setCount) earlier sets as pounds."

        let example: String
        if let exerciseName = preview.exerciseName, preview.number != nil {
            example = isSingle
                ? "It is a \(exerciseName) set entered as \(number), which now reads \(shownNow)."
                : "The most recent, \(exerciseName), was entered as \(number) and now reads \(shownNow)."
        } else {
            example = "A set entered as \(number) now reads \(shownNow)."
        }

        let offer = "If you typed kilograms back then, RPT can relabel \(isSingle ? "it" : "them") so that \(number) reads \(shownAfter)."
        return "\(stored) \(example) \(offer) You can undo this here in Settings."
    }

    static let undoTitle = "Undo the kilogram relabel?"
    static let undoAnswer = "Undo Relabel"

    /// The explanation shown before an undo.
    static func undoMessage(setCount: Int) -> String {
        let sets = setCount == 1 ? "The 1 relabeled set goes" : "The \(setCount) relabeled sets go"
        let relabeled = WeightUnit.kilograms.formatted(100)
        let restored = WeightUnit.pounds.formatted(100)
        return "\(sets) back to pounds, so \(relabeled) reads \(restored) again. Sets you have edited or logged since stay as they are. Check the planned loads of any workout you saved for later."
    }

    /// The row's second line while earlier sets are relabeled.
    static func relabeledDetail(setCount: Int) -> String {
        setCount == 1 ? "1 set relabeled as kilograms" : "\(setCount) sets relabeled as kilograms"
    }
}
