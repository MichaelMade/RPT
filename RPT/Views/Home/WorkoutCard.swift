//
//  WorkoutCard.swift
//  RPT
//
//  Row for a completed workout inside a bordered list card: a template
//  key bar, name with summary line, and trailing volume plus PR count.
//

import SwiftData
import SwiftUI

// MARK: - PR Counter

/// Counts how many exercises hit a new best estimated 1RM in each workout,
/// walking the completed history in ascending date order. An exercise's
/// first appearance sets the baseline rather than counting as a PR.
enum WorkoutPRCounter {
    static func counts(forCompletedWorkoutsAscending workouts: [Workout]) -> [PersistentIdentifier: Int] {
        var bestByExercise: [PersistentIdentifier: Double] = [:]
        var counts: [PersistentIdentifier: Int] = [:]

        for workout in workouts {
            var newRecords = 0

            for group in workout.orderedExerciseGroups {
                let best = OneRepMax.bestEstimate(in: group.sets)
                guard best > 0 else { continue }

                let exerciseID = group.exercise.id
                if let previousBest = bestByExercise[exerciseID] {
                    if best > previousBest {
                        newRecords += 1
                        bestByExercise[exerciseID] = best
                    }
                } else {
                    bestByExercise[exerciseID] = best
                }
            }

            if newRecords > 0 {
                counts[workout.id] = newRecords
            }
        }

        return counts
    }
}

// MARK: - Workout Row

struct WorkoutCard: View {
    let workout: Workout
    var prCount: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(WorkoutNameFormatter.displayName(for: workout))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Text(summaryLine)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                if workout.hasPreferredWorkMetric {
                    Text(workMetricText)
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }

                if prCount > 0 {
                    Text(prCount == 1 ? "1 PR" : "\(prCount) PRs")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.done)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.leading, 30)
        .padding(.trailing, 14)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(TemplateKeyColor.color(for: workout))
                .frame(width: 4)
                .padding(.vertical, 10)
                .padding(.leading, 14)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var workMetricText: String {
        if workout.totalVolume.isFinite, workout.totalVolume > 0 {
            return "\(Int(workout.totalVolume).formatted()) lb"
        }

        return workout.preferredWorkMetricValue
    }

    private var summaryLine: String {
        var parts: [String] = [workout.date.formatted(.dateTime.month(.abbreviated).day())]

        let exercises = workout.visibleExerciseCount
        parts.append(exercises == 1 ? "1 exercise" : "\(exercises) exercises")

        if workout.isCompleted, workout.duration.isFinite, workout.duration > 0 {
            let minutes = max(1, Int((workout.duration / 60).rounded()))
            parts.append("\(minutes) min")
        }

        return parts.joined(separator: " · ")
    }
}
