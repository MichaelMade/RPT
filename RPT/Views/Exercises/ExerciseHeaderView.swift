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
    let onToggleCompletion: () -> Void
    let onToggleDetails: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                // Completion checkmark toggle
                Button(action: onToggleCompletion) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isCompleted ? .green : .gray)
                        .font(.system(size: 22))
                }
                .buttonStyle(BorderlessButtonStyle())
                
                // Exercise icon and name - wrapped in button to toggle details
                Button(action: onToggleDetails) {
                    HStack {
                        ExerciseIconView(category: exercise.category, size: 32)
                            .padding(.trailing, 4)
                        
                        Text(exercise.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Spacer()
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            // Muscle groups (also toggles details when clicked)
            Button(action: onToggleDetails) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.vertical, 4)
    }
}
