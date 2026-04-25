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

    static func setCountText(for workout: Workout) -> String {
        let count = workout.workingSetsCount > 0 ? workout.workingSetsCount : workout.sets.count
        return "\(count) \(count == 1 ? "set" : "sets")"
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(workout.name)
                .font(.headline)
            
            Text(workout.date, style: .date)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                if !workout.sets.isEmpty {
                    Text(Self.exerciseCountText(for: workout))
                        .font(.caption)
                }
                
                Spacer()
                
                Text(Self.setCountText(for: workout))
                    .font(.caption)
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
