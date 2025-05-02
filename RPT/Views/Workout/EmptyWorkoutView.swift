//
//  EmptyWorkoutView.swift
//  RPT
//
//  Created by Michael Moore on 5/2/25.
//

import SwiftUI

struct EmptyWorkoutView: View {
    var onAddExercise: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Exercises Added")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Tap the button below to add your first exercise")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onAddExercise) {
                Label("Add Exercise", systemImage: "plus")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
}