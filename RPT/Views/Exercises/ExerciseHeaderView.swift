//
//  ExerciseHeaderView.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//


import SwiftUI
import SwiftData

struct ExerciseHeaderView: View {
    let exercise: Exercise
    let isCompleted: Bool
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                // Exercise icon
                ExerciseIconView(category: exercise.category, size: 32)
                    .padding(.trailing, 4)
                
                // Exercise name
                Text(exercise.name)
                    .font(.headline)
                
                // Add a checkmark if exercise has at least one completed set
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                }
                
                Spacer()
                
                // Delete button
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            // Muscle groups
            HStack {
                ForEach(exercise.primaryMuscleGroups.prefix(3), id: \.self) { muscle in
                    MuscleGroupTag(muscleGroup: muscle, isPrimary: true)
                }
                
                if exercise.primaryMuscleGroups.count > 3 {
                    Text("+\(exercise.primaryMuscleGroups.count - 3)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
