//
//  ExerciseIconView.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI

struct ExerciseIconView: View {
    let category: ExerciseCategory
    var size: CGFloat = 36
    var showBackground: Bool = true
    
    var body: some View {
        ZStack {
            if showBackground {
                RoundedRectangle(cornerRadius: size/4)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(
                                colors: [category.style.gradientTop, category.style.gradientBottom]
                            ),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size, height: size)
            }
            
            Image(systemName: category.style.icon)
                .font(.system(size: size/2))
                .foregroundColor(showBackground ? .white : category.style.color)
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        VStack(spacing: 8) {
            ExerciseIconView(category: .compound)
            Text("Compound")
                .font(.caption)
        }
        
        VStack(spacing: 8) {
            ExerciseIconView(category: .isolation)
            Text("Isolation")
                .font(.caption)
        }
        
        VStack(spacing: 8) {
            ExerciseIconView(category: .bodyweight)
            Text("Bodyweight")
                .font(.caption)
        }
        
        VStack(spacing: 8) {
            ExerciseIconView(category: .cardio)
            Text("Cardio")
                .font(.caption)
        }
    }
    .padding()
}
