//
//  SetInputParser.swift
//  RPT
//
//  Parsing and bounds for the numbers a lifter types into a set.
//

import Foundation

enum SetInputParser {
    /// Sanity ceiling for a set's weight, in pounds. Far above any real
    /// barbell or machine load; it exists so a slip of the thumb cannot put
    /// an absurd number into history or overflow downstream volume math.
    static let maxWeight = 9_999

    /// Sanity ceiling for reps in a single set.
    static let maxReps = 999

    /// Parses a whole number typed into a weight or reps field.
    ///
    /// - Empty (or whitespace-only) text is `0`: the lifter cleared the field.
    /// - Digits from any script are accepted, since the number pad follows
    ///   the device's numbering system (for example Arabic-Indic digits).
    /// - Anything else — a decimal, a sign, pasted text — or a value above
    ///   `upperBound` returns `nil`, so the caller can explain the problem
    ///   rather than silently saving `0`.
    static func wholeNumber(from text: String, upperBound: Int) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        var value = 0
        for character in trimmed {
            guard let digit = character.wholeNumberValue, (0...9).contains(digit) else {
                return nil
            }

            value = value * 10 + digit
            if value > upperBound {
                // Bail out before a long digit string can overflow `Int`.
                return nil
            }
        }

        return value
    }

    static func weight(from text: String) -> Int? {
        wholeNumber(from: text, upperBound: maxWeight)
    }

    static func reps(from text: String) -> Int? {
        wholeNumber(from: text, upperBound: maxReps)
    }

    /// Parses a decimal the lifter typed, accepting either `.` or `,` as the
    /// decimal separator so entry works in every region's number format
    /// (the decimal pad shows a comma in most of Europe and Latin America).
    /// Grouping separators are not supported: these fields hold a single
    /// barbell load, never thousands. Values above `upperBound` return `nil`,
    /// which also keeps an absurdly long entry out of the plate math.
    static func decimal(from text: String, upperBound: Double = Double(maxWeight)) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var normalized = ""
        var hasSeparator = false

        for character in trimmed {
            if let digit = character.wholeNumberValue, (0...9).contains(digit) {
                normalized.append(String(digit))
            } else if character == "." || character == "," || character == "٫" {
                guard !hasSeparator else { return nil }
                hasSeparator = true
                normalized.append(".")
            } else {
                return nil
            }
        }

        guard let value = Double(normalized), value.isFinite, value <= upperBound else { return nil }
        return value
    }
}
