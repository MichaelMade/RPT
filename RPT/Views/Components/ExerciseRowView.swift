//
//  ExerciseRowView.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData

struct ExerciseRowView: View {
    let exercise: Exercise
    
    var body: some View {
        HStack(spacing: 12) {
            // Exercise category icon
            ExerciseIconView(category: exercise.category, size: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                // Exercise name and custom badge
                HStack {
                    Text(exercise.name)
                        .font(.headline)
                    
                    if exercise.isCustom {
                        Text("Custom")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                
                HStack {
                    // Category tag
                    ExerciseCategoryTag(category: exercise.category)
                        .padding(.trailing, 4)
                    
                    Spacer()
                    
                    // Primary muscle groups as tags
                    HStack(spacing: 4) {
                        ForEach(exercise.primaryMuscleGroups.prefix(2), id: \.self) { muscle in
                            MuscleGroupTag(muscleGroup: muscle, isPrimary: true)
                        }
                        
                        if exercise.primaryMuscleGroups.count > 2 {
                            Text("+\(exercise.primaryMuscleGroups.count - 2)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        ExerciseRowView(
            exercise: Exercise(
                name: "Barbell Bench Press",
                category: .compound,
                primaryMuscleGroups: [.chest],
                secondaryMuscleGroups: [.triceps, .shoulders]
            )
        )
        
        ExerciseRowView(
            exercise: Exercise(
                name: "Bicep Curl",
                category: .isolation,
                primaryMuscleGroups: [.biceps],
                secondaryMuscleGroups: [.forearms],
                isCustom: true
            )
        )
        
        ExerciseRowView(
            exercise: Exercise(
                name: "Push-Up",
                category: .bodyweight,
                primaryMuscleGroups: [.chest, .triceps, .shoulders],
                secondaryMuscleGroups: [.abs]
            )
        )
    }
}
