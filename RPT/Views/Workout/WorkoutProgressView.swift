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
    
    var progress: Double {
        if totalExercises == 0 { return 0 }
        return Double(completedExercises) / Double(totalExercises)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Progress text
            HStack {
                Text("Workout Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(completedExercises)/\(totalExercises) Exercises")
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
