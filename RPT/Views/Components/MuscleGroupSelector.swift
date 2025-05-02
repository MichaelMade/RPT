//
//  MuscleGroupSelector.swift
//  RPT
//
//  Created by Michael Moore on 4/28/25.
//

import SwiftUI

struct MuscleGroupSelector: View {
    @Binding var selectedMuscles: [MuscleGroup]
    var excludedMuscles: [MuscleGroup]
    
    var body: some View {
        ForEach(MuscleGroup.allCases.filter { !excludedMuscles.contains($0) }, id: \.self) { muscle in
            let isSelected = selectedMuscles.contains(muscle)
            
            Button(action: {
                if isSelected {
                    selectedMuscles.removeAll { $0 == muscle }
                } else {
                    selectedMuscles.append(muscle)
                }
            }) {
                HStack {
                    Text(muscle.rawValue.capitalized)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
            .foregroundColor(.primary)
        }
    }
}

#Preview {
    Form {
        Section(header: Text("Primary Muscle Groups")) {
            MuscleGroupSelector(
                selectedMuscles: .constant([.chest, .shoulders]), 
                excludedMuscles: [.other]
            )
        }
        
        Section(header: Text("Secondary Muscle Groups")) {
            MuscleGroupSelector(
                selectedMuscles: .constant([.triceps]), 
                excludedMuscles: [.chest, .shoulders, .other]
            )
        }
    }
}
