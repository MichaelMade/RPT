//
//  TemplateExerciseEditView.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData

struct TemplateExerciseEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var suggestedSets: Int
    @State private var notes: String
    
    // Store the exercise for reference
    let exercise: TemplateExercise
    let onSave: (TemplateExercise) -> Void
    
    init(exercise: TemplateExercise, onSave: @escaping (TemplateExercise) -> Void) {
        self.exercise = exercise
        self.onSave = onSave
        
        // Initialize state with explicit values
        _suggestedSets = State(initialValue: exercise.suggestedSets)
        _notes = State(initialValue: exercise.notes)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Exercise Details")) {
                    Text(exercise.exerciseName)
                        .font(.headline)
                    
                    VStack(alignment: .leading) {
                        Text("Number of Sets")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.bottom, 4)
                        
                        HStack(spacing: 10) {
                            ForEach([1, 2, 3, 4, 5], id: \.self) { num in
                                Button(action: {
                                    suggestedSets = num
                                }) {
                                    Text("\(num)")
                                        .frame(width: 50, height: 50)
                                        .background(suggestedSets == num ? Color.blue : Color.gray.opacity(0.2))
                                        .foregroundColor(suggestedSets == num ? .white : .primary)
                                        .cornerRadius(8)
                                        .font(.headline)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel("\(num) sets")
                            }
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                    
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(5)
                }
                
                Section {
                    Text("This exercise will use \(suggestedSets) sets with the Reverse Pyramid Training pattern.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sets will follow this pattern:")
                            .font(.subheadline)
                            .padding(.bottom, 4)
                        
                        ForEach(1...suggestedSets, id: \.self) { setNum in
                            let percentage = setNum == 1 ? 100 : Int((1.0 - (Double(setNum - 1) * 0.1)) * 100)
                            let minReps = min(6 + ((setNum - 1) * 2), 15)
                            let maxReps = min(8 + ((setNum - 1) * 2), 20)
                            
                            HStack {
                                Text("Set \(setNum):")
                                    .fontWeight(.medium)
                                
                                Text("\(minReps)-\(maxReps) reps")
                                
                                if setNum > 1 {
                                    Text("(\(percentage)% of first set)")
                                        .foregroundColor(.blue)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Configure Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Create a completely new exercise object with the updated values
                        let updatedExercise = TemplateExercise(
                            id: exercise.id,
                            exerciseName: exercise.exerciseName,
                            suggestedSets: suggestedSets,  // Use the updated set count
                            repRanges: [],  // Empty array - the initializer will create proper rep ranges
                            notes: notes
                        )
                        
                        onSave(updatedExercise)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    // Create a sample template exercise for the preview
    let sampleExercise = TemplateExercise(
        exerciseName: "Bench Press",
        suggestedSets: 3,
        repRanges: [
            TemplateRepRange(setNumber: 1, minReps: 4, maxReps: 6, percentageOfFirstSet: 1.0),
            TemplateRepRange(setNumber: 2, minReps: 6, maxReps: 8, percentageOfFirstSet: 0.9),
            TemplateRepRange(setNumber: 3, minReps: 8, maxReps: 10, percentageOfFirstSet: 0.8)
        ],
        notes: "Focus on chest contraction"
    )
    
    return TemplateExerciseEditView(
        exercise: sampleExercise,
        onSave: { _ in
            // This is just a preview, so no need to handle the save action
        }
    )
}
