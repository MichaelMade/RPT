//
//  TemplateDetailView.swift - Updated for Back Confirmation
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI
import SwiftData

struct TemplateDetailView: View {
    let template: WorkoutTemplate
    let onStartWorkout: (Workout) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var navigatingToWorkout = false
    
    private let templateManager = TemplateManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                List {
                    Section(header: Text("Template Information")) {
                        Text(template.name)
                            .font(.headline)
                        
                        if !template.notes.isEmpty {
                            Text("Notes:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(template.notes)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section(header: Text("Exercises")) {
                        ForEach(template.exercises.indices, id: \.self) { index in
                            let exercise = template.exercises[index]
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(index + 1). \(exercise.exerciseName)")
                                    .font(.headline)
                                
                                Text("\(exercise.suggestedSets) sets")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                // Rep ranges
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(exercise.repRanges.sorted(by: { $0.setNumber < $1.setNumber }), id: \.setNumber) { repRange in
                                        HStack {
                                            Text("Set \(repRange.setNumber):")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                            
                                            Text("\(repRange.minReps)-\(repRange.maxReps) reps")
                                                .font(.caption)
                                            
                                            if repRange.percentageOfFirstSet != nil && repRange.setNumber > 1 {
                                                Text("(\(Int((repRange.percentageOfFirstSet ?? 1.0) * 100))% of first set)")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                }
                                
                                if !exercise.notes.isEmpty {
                                    Text(exercise.notes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .padding(.bottom, 80) // Add padding at the bottom to make room for the button
                
                // Bottom button
                VStack {
                    Spacer()
                    
                    Button(action: {
                        let workout = templateManager.createWorkoutFromTemplate(template)
                        // Pass the workout to the callback which will handle navigation
                        onStartWorkout(workout)
                    }) {
                        HStack {
                            Image(systemName: "figure.strengthtraining.traditional")
                            Text("Start Workout")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    .background(
                        Rectangle()
                            .fill(Color(UIColor.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
                            .edgesIgnoringSafeArea(.bottom)
                    )
                }
            }
            .navigationTitle("Template Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
