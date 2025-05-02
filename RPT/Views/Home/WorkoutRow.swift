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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(workout.name)
                .font(.headline)
            
            Text(workout.date, style: .date)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                if !workout.sets.isEmpty {
                    let exercises = Set(workout.sets.compactMap { $0.exercise?.name })
                    Text("\(exercises.count) exercises")
                        .font(.caption)
                }
                
                Spacer()
                
                Text("\(workout.sets.count) sets")
                    .font(.caption)
            }
            
            // Add volume display
            if workout.totalVolume > 0 {
                HStack {
                    Text("Total Volume:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(workout.formattedTotalVolume())
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
