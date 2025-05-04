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
    @State private var exerciseName: String
    @State private var suggestedSets: Int
    @State private var notes: String
    @State private var repRanges: [TemplateRepRange]
    
    let exercise: TemplateExercise
    let onSave: (TemplateExercise) -> Void
    
    init(exercise: TemplateExercise, onSave: @escaping (TemplateExercise) -> Void) {
        self.exercise = exercise
        self.onSave = onSave
        
        // Initialize state
        _exerciseName = State(initialValue: exercise.exerciseName)
        _suggestedSets = State(initialValue: exercise.suggestedSets)
        _notes = State(initialValue: exercise.notes)
        _repRanges = State(initialValue: exercise.repRanges)
    }
    
    private func updateRepRangesForSets(oldValue: Int, newValue: Int) {
        // Sort current rep ranges by set number
        let sortedRepRanges = repRanges.sorted(by: { $0.setNumber < $1.setNumber })
        
        if newValue > oldValue {
            // Adding sets
            for setNum in (oldValue + 1)...newValue {
                // Create new rep ranges for added sets
                let lastRange = sortedRepRanges.last ?? TemplateRepRange(setNumber: 0, minReps: 8, maxReps: 10, percentageOfFirstSet: 1.0)
                
                // Each new set gets 2 more reps than the previous
                let newMinReps = min(lastRange.minReps + 2, 15)
                let newMaxReps = min(lastRange.maxReps + 2, 20)
                
                // Calculate percentage of first set for RPT (decrease by 10% each set)
                let percentageOfFirstSet = max(1.0 - (Double(setNum - 1) * 0.1), 0.5)
                
                let newRange = TemplateRepRange(
                    setNumber: setNum,
                    minReps: newMinReps,
                    maxReps: newMaxReps,
                    percentageOfFirstSet: percentageOfFirstSet
                )
                
                repRanges.append(newRange)
            }
        } else if newValue < oldValue {
            // Removing sets
            repRanges.removeAll(where: { $0.setNumber > newValue })
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Exercise Details")) {
                    HStack {
                        Text(exerciseName)
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    Stepper("Sets: \(suggestedSets)", value: $suggestedSets, in: 1...5)
                        .onChange(of: suggestedSets) { oldValue, newValue in
                            updateRepRangesForSets(oldValue: oldValue, newValue: newValue)
                        }
                    
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(5)
                }
                
                Section(header: Text("Rep Ranges")) {
                    ForEach(repRanges.indices.sorted(by: { repRanges[$0].setNumber < repRanges[$1].setNumber }), id: \.self) { index in
                        let setNumber = repRanges[index].setNumber
                        
                        VStack {
                            HStack {
                                Text("Set \(setNumber)")
                                    .font(.headline)
                                Spacer()
                            }
                            
                            if setNumber > 1 {
                                HStack {
                                    Text("Weight:")
                                                                        
                                    let percentBinding = Binding<Double>(
                                        get: { repRanges[index].percentageOfFirstSet ?? 1.0 },
                                        set: { repRanges[index].percentageOfFirstSet = $0 }
                                    )
                                    
                                    Text("\(Int((percentBinding.wrappedValue) * 100))%")
                                    
                                    Spacer()
                                    
                                    Stepper("", value: percentBinding, in: 0.5...1.0, step: 0.05)
                                        .labelsHidden()
                                }
                            }
                            
                            HStack {
                                Text("Rep Range:")
                                
                                Stepper("\(repRanges[index].minReps)-\(repRanges[index].maxReps)", onIncrement: {
                                    repRanges[index].minReps += 1
                                    repRanges[index].maxReps += 1
                                }, onDecrement: {
                                    if repRanges[index].minReps > 1 {
                                        repRanges[index].minReps -= 1
                                        repRanges[index].maxReps -= 1
                                    }
                                })
                            }
                        }
                    }
                    
                    Text("Note: For RPT, the first set is always 100% weight. Subsequent sets reduce weight by percentage.")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                        // Create updated exercise
                        let updatedExercise = TemplateExercise(
                            id: exercise.id,
                            exerciseName: exerciseName,
                            suggestedSets: suggestedSets,
                            repRanges: repRanges,
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
