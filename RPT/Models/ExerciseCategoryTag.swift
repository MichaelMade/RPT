//
//  ExerciseCategoryTag.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI

struct ExerciseCategoryTag: View {
    let category: ExerciseCategory
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.style.icon)
                .font(.system(size: 10, weight: .semibold))

            Text(category.rawValue.capitalized)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(category.style.color.opacity(0.15), in: Capsule())
        .foregroundStyle(category.style.color)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 10) {
        Text("Exercise Categories")
            .font(.headline)
            .padding(.bottom, 4)
        
        ForEach(ExerciseCategory.allCases, id: \.self) { category in
            ExerciseCategoryTag(category: category)
        }
    }
    .padding()
}
