//
//  WorkoutCard.swift
//  RPT
//
//  Compact summary card for a completed workout in lists.
//

import SwiftUI

struct WorkoutCard: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(workout.date, format: .dateTime.day())
                    .font(Theme.statFont(size: 20))
                Text(workout.date, format: .dateTime.month(.abbreviated))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            .frame(width: 46)
            .padding(.vertical, 8)
            .background(Theme.subtleBrandGradient, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(WorkoutNameFormatter.displayName(for: workout))
                    .font(.headline)
                    .lineLimit(1)

                Text(summaryLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if workout.hasPreferredWorkMetric {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(workout.preferredWorkMetricValue)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    Text(workout.preferredWorkMetricTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .rptCard(padding: 12)
    }

    private var summaryLine: String {
        var parts: [String] = []

        let exercises = workout.visibleExerciseCount
        parts.append(exercises == 1 ? "1 exercise" : "\(exercises) exercises")

        let sets = workout.visibleSetCount
        parts.append(sets == 1 ? "1 set" : "\(sets) sets")

        if workout.isCompleted, workout.duration > 0 {
            parts.append(workout.formattedDurationForSummary())
        }

        return parts.joined(separator: " • ")
    }
}
