//
//  WorkoutRow.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI
import SwiftData

struct WorkoutRow: View {
    let workout: Workout

    static func displayName(for workout: Workout) -> String {
        let collapsedName = workout.name
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedName.isEmpty else {
            return "Workout"
        }

        return String(collapsedName.prefix(80))
    }

    static func relativeDateText(
        for date: Date,
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        var displayCalendar = calendar
        displayCalendar.timeZone = timeZone

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone

        if displayCalendar.isDate(date, inSameDayAs: now) {
            formatter.dateFormat = "h:mm a"
            return "Today • \(formatter.string(from: date))"
        }

        if let yesterday = displayCalendar.date(byAdding: .day, value: -1, to: now),
           displayCalendar.isDate(date, inSameDayAs: yesterday) {
            formatter.dateFormat = "h:mm a"
            return "Yesterday • \(formatter.string(from: date))"
        }

        let startOfToday = displayCalendar.startOfDay(for: now)
        let startOfDate = displayCalendar.startOfDay(for: date)
        let dayDelta = displayCalendar.dateComponents([.day], from: startOfDate, to: startOfToday).day ?? 0

        if (2...6).contains(dayDelta) {
            formatter.dateFormat = "EEEE • h:mm a"
            return formatter.string(from: date)
        }

        if displayCalendar.component(.year, from: date) == displayCalendar.component(.year, from: now) {
            formatter.dateFormat = "MMM d • h:mm a"
            return formatter.string(from: date)
        }

        formatter.dateFormat = "MMM d, yyyy • h:mm a"
        return formatter.string(from: date)
    }

    static func displayExerciseCount(for workout: Workout) -> Int {
        let completedExercises = Set(
            workout.sets
                .filter(\.isCompletedWorkingSet)
                .compactMap { $0.exercise }
        ).count

        return completedExercises > 0 ? completedExercises : workout.exerciseCount
    }

    static func exerciseCountText(for workout: Workout) -> String {
        let count = displayExerciseCount(for: workout)
        return "\(count) \(count == 1 ? "exercise" : "exercises")"
    }

    static func displaySetCount(for workout: Workout) -> Int {
        workout.visibleSetCount
    }

    static func setCountText(for workout: Workout) -> String {
        let count = displaySetCount(for: workout)
        return "\(count) \(count == 1 ? "set" : "sets")"
    }

    static func countsFallbackText(for workout: Workout) -> String? {
        if workout.isCompleted, workout.hasLoggedWarmupOnly {
            return "Warm-up sets only"
        }

        if workout.sets.isEmpty {
            return "No sets logged"
        }

        if workout.isCompleted, workout.workingSetsCount == 0 {
            return "No sets logged"
        }

        return nil
    }

    static func durationMetric(for workout: Workout) -> (label: String, value: String)? {
        let safeDuration = workout.duration.isFinite ? max(0, workout.duration) : 0

        guard safeDuration > 0 else {
            return nil
        }

        return (
            label: "Duration",
            value: workout.formattedDurationForSummary()
        )
    }

    static func secondaryMetric(for workout: Workout) -> (label: String, value: String)? {
        guard workout.hasPreferredWorkMetric else {
            return nil
        }

        return (
            label: "Total \(workout.preferredWorkMetricTitle)",
            value: workout.preferredWorkMetricValue
        )
    }

    static func supplementalMetric(for workout: Workout) -> (label: String, value: String)? {
        guard workout.totalVolume > 0, workout.totalBodyweightReps > 0 else {
            return nil
        }

        return (
            label: "Bodyweight Reps",
            value: workout.formattedTotalBodyweightReps()
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Self.displayName(for: workout))
                .font(.headline)
            
            Text(Self.relativeDateText(for: workout.date))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let countsFallbackText = Self.countsFallbackText(for: workout) {
                Text(countsFallbackText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                HStack {
                    Text(Self.exerciseCountText(for: workout))
                        .font(.caption)

                    Spacer()

                    Text(Self.setCountText(for: workout))
                        .font(.caption)
                }
            }
            
            if let durationMetric = Self.durationMetric(for: workout) {
                HStack {
                    Text("\(durationMetric.label):")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(durationMetric.value)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            if let secondaryMetric = Self.secondaryMetric(for: workout) {
                HStack {
                    Text("\(secondaryMetric.label):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(secondaryMetric.value)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            if let supplementalMetric = Self.supplementalMetric(for: workout) {
                HStack {
                    Text("\(supplementalMetric.label):")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(supplementalMetric.value)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            HStack {
                Spacer()
                Text("Tap to view details")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 2)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}
