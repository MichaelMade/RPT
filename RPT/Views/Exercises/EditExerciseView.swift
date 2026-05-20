//
//  EditExerciseView.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData

struct EditExerciseView: View {
    private struct DraftSnapshot: Equatable {
        let name: String
        let category: ExerciseCategory
        let primaryMuscles: [MuscleGroup]
        let secondaryMuscles: [MuscleGroup]
        let instructions: String

        init(
            name: String,
            category: ExerciseCategory,
            primaryMuscles: [MuscleGroup],
            secondaryMuscles: [MuscleGroup],
            instructions: String
        ) {
            self.name = ExerciseManager.sanitizeExerciseName(name)
            self.category = category
            self.primaryMuscles = primaryMuscles
            self.secondaryMuscles = secondaryMuscles
            self.instructions = Self.normalizedDraftText(instructions)
        }

        private static func normalizedDraftText(_ raw: String) -> String {
            raw
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
    }

    static func navigationTitle(for rawExerciseName: String, fallbackExercise: Exercise) -> String {
        guard let displayName = Exercise.specificDisplayName(rawExerciseName) ?? fallbackExercise.specificDisplayName else {
            return "Edit Exercise"
        }

        return "Edit “\(displayName)”"
    }

    static func saveFailureAlertTitle(for rawExerciseName: String, fallbackExercise: Exercise) -> String {
        guard let displayName = Exercise.specificDisplayName(rawExerciseName) ?? fallbackExercise.specificDisplayName else {
            return "Couldn’t Save This Exercise"
        }

        return "Couldn’t Save “\(displayName)”"
    }

    static func discardAlertTitle(for rawExerciseName: String, fallbackExercise: Exercise) -> String {
        guard let displayName = Exercise.specificDisplayName(rawExerciseName) ?? fallbackExercise.specificDisplayName else {
            return "Discard Exercise Changes?"
        }

        return "Discard “\(displayName)”?"
    }

    static func discardAlertActionTitle(for rawExerciseName: String, fallbackExercise: Exercise) -> String {
        guard let displayName = Exercise.specificDisplayName(rawExerciseName) ?? fallbackExercise.specificDisplayName else {
            return "Discard Changes"
        }

        return "Discard “\(displayName)”"
    }

    static func discardAlertMessage() -> String {
        "You’ll lose your unsaved changes to this exercise."
    }

    @Environment(\.dismiss) private var dismiss
    @Bindable var exercise: Exercise
    
    @State private var exerciseName: String
    @State private var selectedCategory: ExerciseCategory
    @State private var selectedPrimaryMuscles: [MuscleGroup]
    @State private var selectedSecondaryMuscles: [MuscleGroup]
    @State private var instructions: String
    @State private var showingDiscardConfirmation = false
    @State private var saveResult: ExerciseManager.MutationResult?
    
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

    private var initialDraftSnapshot: DraftSnapshot {
        DraftSnapshot(
            name: exercise.name,
            category: exercise.category,
            primaryMuscles: exercise.primaryMuscleGroups,
            secondaryMuscles: exercise.secondaryMuscleGroups,
            instructions: exercise.instructions
        )
    }

    private var currentDraftSnapshot: DraftSnapshot {
        DraftSnapshot(
            name: exerciseName,
            category: selectedCategory,
            primaryMuscles: selectedPrimaryMuscles,
            secondaryMuscles: selectedSecondaryMuscles,
            instructions: instructions
        )
    }

    private var hasUnsavedChanges: Bool {
        currentDraftSnapshot != initialDraftSnapshot
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
            .navigationTitle(Self.navigationTitle(for: exerciseName, fallbackExercise: exercise))
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                saveResult == .persistenceFailure
                    ? Self.saveFailureAlertTitle(for: exerciseName, fallbackExercise: exercise)
                    : (saveResult?.alertTitle ?? "Unable to Save Exercise"),
                isPresented: Binding(
                    get: { saveResult != nil },
                    set: { isPresented in
                        if !isPresented {
                            saveResult = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    saveResult = nil
                }
            } message: {
                Text(saveResult?.alertMessage ?? "Your changes could not be saved right now. Please try again.")
            }
            .alert(
                Self.discardAlertTitle(for: exerciseName, fallbackExercise: exercise),
                isPresented: $showingDiscardConfirmation
            ) {
                Button("Keep Editing", role: .cancel) {}
                Button(
                    Self.discardAlertActionTitle(for: exerciseName, fallbackExercise: exercise),
                    role: .destructive
                ) {
                    dismiss()
                }
            } message: {
                Text(Self.discardAlertMessage())
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showingDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
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
        let result = exerciseManager.updateExercise(
            exercise,
            name: exerciseName,
            category: selectedCategory,
            primaryMuscleGroups: selectedPrimaryMuscles,
            secondaryMuscleGroups: selectedSecondaryMuscles,
            instructions: instructions
        )

        if result == .success {
            dismiss()
        } else {
            saveResult = result
        }
    }
}
