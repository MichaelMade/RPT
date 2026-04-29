//
//  AddExerciseView.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var exerciseName = ""
    @State private var selectedCategory: ExerciseCategory = .compound
    @State private var selectedPrimaryMuscles: [MuscleGroup] = []
    @State private var selectedSecondaryMuscles: [MuscleGroup] = []
    @State private var instructions = ""
    @State private var showDuplicateNameAlert = false
    
    private let exerciseManager = ExerciseManager.shared

    private var draftValidation: ExerciseManager.DraftValidationResult {
        exerciseManager.validateDraft(
            name: exerciseName,
            primaryMuscleGroups: selectedPrimaryMuscles
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
                Section(header: Text("Exercise Details")) {
                    TextField("Exercise Name", text: $exerciseName)

                    if let saveHelperText, draftValidation == .missingName || draftValidation == .duplicateName {
                        Text(saveHelperText)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ExerciseCategory.allCases, id: \.self) { category in
                            Text(category.rawValue.capitalized).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("Primary Muscles")) {
                    MuscleGroupSelector(
                        selectedMuscles: $selectedPrimaryMuscles,
                        excludedMuscles: selectedSecondaryMuscles
                    )

                    if let saveHelperText, draftValidation == .noPrimaryMuscles {
                        Text(saveHelperText)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Secondary Muscles")) {
                    MuscleGroupSelector(
                        selectedMuscles: $selectedSecondaryMuscles,
                        excludedMuscles: selectedPrimaryMuscles
                    )
                }
                
                Section(header: Text("Instructions (Optional)")) {
                    TextEditor(text: $instructions)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Exercise Already Exists", isPresented: $showDuplicateNameAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("An exercise with this name already exists. Please choose a different name.")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveExercise()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
    
    private func saveExercise() {
        let didSave = exerciseManager.addExercise(
            name: exerciseName,
            category: selectedCategory,
            primaryMuscleGroups: selectedPrimaryMuscles,
            secondaryMuscleGroups: selectedSecondaryMuscles,
            instructions: instructions
        )

        if didSave {
            dismiss()
        } else {
            showDuplicateNameAlert = true
        }
    }
}
