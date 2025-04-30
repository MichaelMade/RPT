//
//  ExerciseCategoryStyle.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI

// MARK: - Exercise Category Icons and Colors

struct ExerciseCategoryStyle {
    let icon: String
    let color: Color
    let gradientTop: Color
    let gradientBottom: Color
    
    init(icon: String, color: Color) {
        self.icon = icon
        self.color = color
        self.gradientTop = color.opacity(0.8)
        self.gradientBottom = color.opacity(0.6)
    }
}

// Preview provider
struct ExerciseIcons_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                ForEach(ExerciseCategory.allCases, id: \.self) { category in
                    ExerciseIconView(category: category)
                }
            }
            
            HStack(spacing: 8) {
                ForEach(ExerciseCategory.allCases, id: \.self) { category in
                    ExerciseCategoryTag(category: category)
                }
            }
            .padding(.horizontal)
            
            HStack(spacing: 6) {
                MuscleGroupTag(muscleGroup: .chest, isPrimary: true)
                MuscleGroupTag(muscleGroup: .triceps, isPrimary: false)
                MuscleGroupTag(muscleGroup: .shoulders, isPrimary: false)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
