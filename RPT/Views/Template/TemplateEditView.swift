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
    @State private var saveResult: TemplateManager.MutationResult?
    
    let isNewTemplate: Bool
    let existingTemplate: WorkoutTemplate?
    let initialTemplateName: String
    let initialTemplateNotes: String
    let initialExercises: [TemplateExercise]
    
    private let templateManager = TemplateManager.shared

    private var draftValidation: TemplateManager.DraftValidationResult {
        templateManager.validateDraft(
            name: templateName,
            exercises: exercises,
            excludingTemplateId: existingTemplate?.id
        )
    }

    private var saveHelperText: String? {
        switch draftValidation {
        case .duplicateExercise:
            return templateManager.duplicateExerciseMessage(for: exercises, style: .helper)
        default:
            return draftValidation.helperText
        }
    }

    private func saveAlertMessage(for result: TemplateManager.MutationResult) -> String {
        switch result {
        case .duplicateExercise:
            return templateManager.duplicateExerciseMessage(for: exercises, style: .alert)
        default:
            return result.alertMessage
        }
    }

    private var canSave: Bool {
        draftValidation == .valid
    }

    private var duplicateExerciseLookupKeys: Set<String> {
        var counts: [String: Int] = [:]

        for exercise in exercises {
            let lookupKey = ExerciseManager.normalizedNameLookupKey(exercise.exerciseName)
            counts[lookupKey, default: 0] += 1
        }

        return Set(counts.compactMap { lookupKey, count in
            count > 1 ? lookupKey : nil
        })
    }

    private func isDuplicateExercise(_ exercise: TemplateExercise) -> Bool {
        duplicateExerciseLookupKeys.contains(
            ExerciseManager.normalizedNameLookupKey(exercise.exerciseName)
        )
    }

    private func removeExercise(id: UUID) {
        exercises.removeAll { $0.id == id }
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
                        let exercise = exercises[index]

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(TemplateExercise.normalizedDisplayName(exercise.exerciseName))
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    if isDuplicateExercise(exercise) {
                                        HStack(alignment: .center, spacing: 8) {
                                            Label("Repeated entry — only the first copy will be added", systemImage: "square.on.square.fill")
                                                .font(.caption)
                                                .foregroundColor(.orange)

                                            Button("Remove Extra Copy") {
                                                removeExercise(id: exercise.id)
                                            }
                                            .font(.caption.weight(.semibold))
                                            .buttonStyle(.borderless)
                                        }
                                    }

                                    Text("\(exercise.suggestedSets) sets")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    // Show rep ranges
                                    HStack {
                                        ForEach(exercise.repRanges.sorted(by: { $0.setNumber < $1.setNumber }), id: \.setNumber) { repRange in
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

                                Spacer(minLength: 0)

                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingExerciseEditor = exercise
                        }
                    }
                    .onDelete { indexSet in
                        exercises.remove(atOffsets: indexSet)
                    }
                    
                    Button("Add Exercise") {
                        showingExerciseSelector = true
                    }

                    if let saveHelperText, draftValidation == .noExercises || draftValidation == .duplicateExercise {
                        Text(saveHelperText)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(TemplateViewModel.templateEditorNavigationTitle(isNewTemplate: isNewTemplate, templateName: templateName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let result = saveTemplate()
                        if result == .success {
                            dismiss()
                        } else {
                            saveResult = result
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
                } else if templateName.isEmpty && templateNotes.isEmpty && exercises.isEmpty {
                    templateName = TemplateViewModel.normalizedSearchQuery(initialTemplateName)
                    templateNotes = WorkoutTemplate.normalizedDisplayNotes(initialTemplateNotes) ?? ""
                    exercises = initialExercises
                }
            }
            .sheet(isPresented: $showingExerciseSelector) {
                ExerciseSelectorForTemplateView(
                    excludedExerciseNames: exercises.map(\.exerciseName)
                ) { exerciseName in
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
            .alert(
                saveResult?.alertTitle ?? "Unable to Save Template",
                isPresented: Binding(
                    get: { saveResult != nil },
                    set: { isPresented in
                        if !isPresented {
                            saveResult = nil
                        }
                    }
                ),
                presenting: saveResult
            ) { _ in
                Button("OK", role: .cancel) {
                    saveResult = nil
                }
            } message: { result in
                Text(saveAlertMessage(for: result))
            }
        }
    }
    
    private func saveTemplate() -> TemplateManager.MutationResult {
        if isNewTemplate {
            return templateManager.createTemplate(name: templateName, exercises: exercises, notes: templateNotes)
        } else if let template = existingTemplate {
            return templateManager.updateTemplate(template, name: templateName, exercises: exercises, notes: templateNotes)
        }

        return .persistenceFailure
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
            existingTemplate: template,
            initialTemplateName: "",
            initialTemplateNotes: "",
            initialExercises: []
        )
        .modelContainer(modelContainer)
    }
}
