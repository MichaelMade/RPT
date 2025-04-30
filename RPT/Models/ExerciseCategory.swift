//
//  ExerciseCategory.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import Foundation

enum ExerciseCategory: String, Codable, CaseIterable {
    case compound
    case isolation
    case bodyweight
    case cardio
    case other
    
    var style: ExerciseCategoryStyle {
        switch self {
        case .compound:
            return ExerciseCategoryStyle(
                icon: "figure.strengthtraining.traditional",
                color: .blue
            )
        case .isolation:
            return ExerciseCategoryStyle(
                icon: "figure.arms.open",
                color: .green
            )
        case .bodyweight:
            return ExerciseCategoryStyle(
                icon: "figure.gymnastics",
                color: .purple
            )
        case .cardio:
            return ExerciseCategoryStyle(
                icon: "figure.run",
                color: .red
            )
        case .other:
            return ExerciseCategoryStyle(
                icon: "figure.mixed.cardio",
                color: .gray
            )
        }
    }
}

