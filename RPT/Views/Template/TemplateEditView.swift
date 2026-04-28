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
    @State private var showingDuplicateTemplateAlert = false
    
    let isNewTemplate: Bool
    let existingTemplate: WorkoutTemplate?
    
    private let templateManager = TemplateManager.shared

    private var draftValidation: TemplateManager.DraftValidationResult {
        templateManager.validateDraft(
            name: templateName,
            exercises: exercises,
            excludingTemplateId: existingTemplate?.id
        )
    }

    private var saveHelperText: String? {
        draftValidation.helperText
    }

    private var canSave: Bool {
        draftValidation == .valid
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Template Information")) {
                    TextField("Template Name", text: $templateName)

                    if let saveHelperText, draftValidation == .missingName || draftValidation == .duplicateName {
                        Text(saveHelperText)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    
                    TextField("Notes (optional)", text: $templateNotes, axis: .vertical)
                        .lineLimit(5)
                }
                
                Section(header: Text("Exercises")) {
                    ForEach(exercises.indices, id: \.self) { index in
                        Button(action: {
                            showingExerciseEditor = exercises[index]
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(TemplateExercise.normalizedDisplayName(exercises[index].exerciseName))
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

                    if let saveHelperText, draftValidation == .noExercises {
                        Text(saveHelperText)
                            .font(.footnote)
                            .foregroundColor(.secondary)
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
                        if saveTemplate() {
                            dismiss()
                        } else {
                            showingDuplicateTemplateAlert = true
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if let template = existingTemplate {
                    templateName = WorkoutTemplate.normalizedDisplayName(template.name)
                    templateNotes = WorkoutTemplate.normalizedDisplayNotes(template.notes) ?? ""
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
            .alert("Duplicate Template Name", isPresented: $showingDuplicateTemplateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("A template with this name already exists. Please choose a unique name.")
            }
        }
    }
    
    private func saveTemplate() -> Bool {
        if isNewTemplate {
            return templateManager.createTemplate(name: templateName, exercises: exercises, notes: templateNotes)
        } else if let template = existingTemplate {
            return templateManager.updateTemplate(template, name: templateName, exercises: exercises, notes: templateNotes)
        }

        return false
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
