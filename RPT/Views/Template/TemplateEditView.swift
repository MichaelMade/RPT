//
//  TemplateEditView.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData

struct TemplateEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var templateName = ""
    @State private var templateNotes = ""
    @State private var exercises: [TemplateExercise] = []
    @State private var showingExerciseSelector = false
    @State private var showingExerciseEditor: TemplateExercise?
    
    let isNewTemplate: Bool
    let existingTemplate: WorkoutTemplate?
    
    private let templateManager = TemplateManager.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Template Information")) {
                    TextField("Template Name", text: $templateName)
                    
                    TextField("Notes (optional)", text: $templateNotes, axis: .vertical)
                        .lineLimit(5)
                }
                
                Section(header: Text("Exercises")) {
                    ForEach(exercises.indices, id: \.self) { index in
                        Button(action: {
                            showingExerciseEditor = exercises[index]
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercises[index].exerciseName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("\(exercises[index].suggestedSets) sets")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                // Show rep ranges
                                HStack {
                                    ForEach(exercises[index].repRanges.sorted(by: { $0.setNumber < $1.setNumber }), id: \.setNumber) { repRange in
                                        Text("Set \(repRange.setNumber): \(repRange.minReps)-\(repRange.maxReps)")
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(.top, 2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { indexSet in
                        exercises.remove(atOffsets: indexSet)
                    }
                    
                    Button("Add Exercise") {
                        showingExerciseSelector = true
                    }
                }
            }
            .navigationTitle(isNewTemplate ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTemplate()
                        dismiss()
                    }
                    .disabled(templateName.isEmpty || exercises.isEmpty)
                }
            }
            .onAppear {
                if let template = existingTemplate {
                    templateName = template.name
                    templateNotes = template.notes
                    exercises = template.exercises
                }
            }
            .sheet(isPresented: $showingExerciseSelector) {
                ExerciseSelectorForTemplateView { exerciseName in
                    addExerciseToTemplate(exerciseName)
                }
            }
            .sheet(item: $showingExerciseEditor) { exercise in
                TemplateExerciseEditView(
                    exercise: exercise,
                    onSave: { updatedExercise in
                        // Find the exercise to update
                        if let index = exercises.firstIndex(where: { $0.id == updatedExercise.id }) {
                            // Remove the old exercise and insert the updated one at the same index
                            exercises.remove(at: index)
                            exercises.insert(updatedExercise, at: index)
                        }
                    }
                )
            }
        }
    }
    
    private func saveTemplate() {
        if isNewTemplate {
            _ = templateManager.createTemplate(name: templateName, exercises: exercises, notes: templateNotes)
        } else if let template = existingTemplate {
            templateManager.updateTemplate(template, name: templateName, exercises: exercises, notes: templateNotes)
        }
    }
    
    private func addExerciseToTemplate(_ exerciseName: String) {
        // Create default template exercise with RPT pattern
        let newExercise = TemplateExercise(
            exerciseName: exerciseName,
            suggestedSets: 3,
            repRanges: [
                TemplateRepRange(setNumber: 1, minReps: 6, maxReps: 8, percentageOfFirstSet: 1.0),
                TemplateRepRange(setNumber: 2, minReps: 8, maxReps: 10, percentageOfFirstSet: 0.9),
                TemplateRepRange(setNumber: 3, minReps: 10, maxReps: 12, percentageOfFirstSet: 0.8)
            ],
            notes: ""
        )
        
        exercises.append(newExercise)
    }
}

#Preview {
    let modelContainer = try! ModelContainer(for: WorkoutTemplate.self, Exercise.self)
    
    let template = WorkoutTemplate(
        name: "Upper Body Day",
        exercises: [
            TemplateExercise(
                exerciseName: "Bench Press",
                suggestedSets: 3,
                repRanges: [
                    TemplateRepRange(setNumber: 1, minReps: 4, maxReps: 6, percentageOfFirstSet: 1.0),
                    TemplateRepRange(setNumber: 2, minReps: 6, maxReps: 8, percentageOfFirstSet: 0.9)
                ],
                notes: "Focus on chest contraction"
            )
        ],
        notes: "Rest 2-3 minutes between sets"
    )
    
    return NavigationStack {
        TemplateEditView(
            isNewTemplate: false,
            existingTemplate: template
        )
        .modelContainer(modelContainer)
    }
}
