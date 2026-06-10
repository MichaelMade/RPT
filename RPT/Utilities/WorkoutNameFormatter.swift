//
//  WorkoutNameFormatter.swift
//  RPT
//
//  Display-safe workout naming. Legacy drafts stored placeholder titles
//  like "Current Workout"; those collapse to the generic "Workout" label
//  so stale internal names never leak into the UI.
//

import Foundation

enum WorkoutNameFormatter {
    static let genericName = "Workout"

    /// Collapses whitespace, clamps length, and normalizes legacy placeholder names.
    static func displayName(for rawName: String) -> String {
        let collapsedName = rawName
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedName.isEmpty else {
            return genericName
        }

        let placeholderKey = collapsedName.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )

        switch placeholderKey {
        case "current workout", "current draft", "workout":
            return genericName
        default:
            return String(collapsedName.prefix(80))
        }
    }

    /// The display name only when the workout has a real user-chosen title.
    static func specificName(for rawName: String) -> String? {
        let name = displayName(for: rawName)
        return name == genericName ? nil : name
    }

    static func displayName(for workout: Workout) -> String {
        displayName(for: workout.name)
    }

    static func specificName(for workout: Workout) -> String? {
        specificName(for: workout.name)
    }
}
