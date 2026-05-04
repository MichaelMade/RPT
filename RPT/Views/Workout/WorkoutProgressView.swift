//
//  WorkoutProgressView.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI

struct WorkoutProgressView: View {
    let completedExercises: Int
    let totalExercises: Int

    var safeTotalExercises: Int {
        max(0, totalExercises)
    }

    var safeCompletedExercises: Int {
        min(max(0, completedExercises), safeTotalExercises)
    }

    var progressLabel: String {
        guard safeTotalExercises > 0 else {
            return "No exercises yet"
        }

        if safeCompletedExercises <= 0 {
            return "No exercises marked complete yet"
        }

        if safeCompletedExercises >= safeTotalExercises {
            return "All exercises marked complete"
        }

        return "\(safeCompletedExercises) of \(safeTotalExercises) exercises marked complete"
    }
    
    var progress: Double {
        guard safeTotalExercises > 0 else { return 0 }

        let rawProgress = Double(safeCompletedExercises) / Double(safeTotalExercises)
        return min(max(rawProgress, 0), 1)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Progress text
            HStack {
                Text("Workout Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(progressLabel)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .cornerRadius(5)
                    
                    // Progress
                    Rectangle()
                        .fill(Color.blue)
                        .cornerRadius(5)
                        .frame(width: geometry.size.width * progress)
                        .animation(.spring(response: 0.4), value: progress)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Workout progress")
                .accessibilityValue(progressLabel)
                .accessibilityHint("Shows how many exercises you have manually marked complete out of the total exercises in this workout")
            }
            .frame(height: 10)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

#Preview {
    // Create a preview with some realistic data
    WorkoutProgressView(completedExercises: 2, totalExercises: 4)
}
