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
        Text(muscleGroup.displayName)
            .font(.caption.weight(isPrimary ? .medium : .regular))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(isPrimary ? 0.1 : 0.05), in: Capsule())
            .foregroundStyle(isPrimary ? .primary : .secondary)
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
