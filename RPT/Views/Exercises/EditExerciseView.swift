//
//  EditExerciseView.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData

struct EditExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var exercise: Exercise
    
    @State private var exerciseName: String
    @State private var selectedCategory: ExerciseCategory
    @State private var selectedPrimaryMuscles: [MuscleGroup]
    @State private var selectedSecondaryMuscles: [MuscleGroup]
    @State private var instructions: String
    @State private var showDuplicateNameAlert = false
    
    private let exerciseManager = ExerciseManager.shared

    private var draftValidation: ExerciseManager.DraftValidationResult {
        exerciseManager.validateDraft(
            name: exerciseName,
            primaryMuscleGroups: selectedPrimaryMuscles,
            excludingExerciseId: exercise.id
        )
    }

    private var saveHelperText: String? {
        draftValidation.helperText
    }

    private var canSave: Bool {
        draftValidation == .valid
    }
    
    init(exercise: Exercise) {
        self.exercise = exercise
        
        // Initialize state variables with exercise properties
        _exerciseName = State(initialValue: exercise.name)
        _selectedCategory = State(initialValue: exercise.category)
        _selectedPrimaryMuscles = State(initialValue: exercise.primaryMuscleGroups)
        _selectedSecondaryMuscles = State(initialValue: exercise.secondaryMuscleGroups)
        _instructions = State(initialValue: exercise.instructions)
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
            .navigationTitle("Edit Exercise")
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
        let didSave = exerciseManager.updateExercise(
            exercise,
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
