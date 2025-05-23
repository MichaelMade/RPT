//
//  MuscleGroupTag.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI

struct MuscleGroupTag: View {
    let muscleGroup: MuscleGroup
    let isPrimary: Bool
    
    var body: some View {
        Text(muscleGroup.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.gray.opacity(isPrimary ? 0.2 : 0.1))
            .foregroundColor(isPrimary ? .primary : .secondary)
            .cornerRadius(4)
    }
}

#Preview {
    VStack(spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Primary Muscle Groups")
                .font(.headline)
            
            HStack {
                MuscleGroupTag(muscleGroup: .chest, isPrimary: true)
                MuscleGroupTag(muscleGroup: .back, isPrimary: true)
                MuscleGroupTag(muscleGroup: .quadriceps, isPrimary: true)
            }
        }
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Secondary Muscle Groups")
                .font(.headline)
            
            HStack {
                MuscleGroupTag(muscleGroup: .biceps, isPrimary: false)
                MuscleGroupTag(muscleGroup: .triceps, isPrimary: false)
                MuscleGroupTag(muscleGroup: .shoulders, isPrimary: false)
            }
        }
    }
    .padding()
}
