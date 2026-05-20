//
//  AddExerciseView.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData

struct AddExerciseView: View {
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

    let initialExerciseName: String
    let initialCategory: ExerciseCategory
    let initialPrimaryMuscles: [MuscleGroup]
    let onExerciseSaved: ((String) -> Void)?

    static func navigationTitle(for rawExerciseName: String) -> String {
        let displayName = ExerciseManager.sanitizeExerciseName(rawExerciseName)
        return displayName.isEmpty ? "Add Exercise" : "Add “\(displayName)”"
    }

    static func saveFailureAlertTitle(for rawExerciseName: String) -> String {
        guard let displayName = Exercise.specificDisplayName(rawExerciseName) else {
            return "Couldn’t Save This Exercise"
        }

        return "Couldn’t Save “\(displayName)”"
    }

    static func discardAlertTitle(for rawExerciseName: String) -> String {
        guard let displayName = Exercise.specificDisplayName(rawExerciseName) else {
            return "Discard New Exercise?"
        }

        return "Discard “\(displayName)”?"
    }

    static func discardAlertActionTitle(for rawExerciseName: String) -> String {
        guard let displayName = Exercise.specificDisplayName(rawExerciseName) else {
            return "Discard New Exercise"
        }

        return "Discard “\(displayName)”"
    }

    static func discardAlertMessage() -> String {
        "You’ll lose this exercise draft and any setup changes."
    }

    @Environment(\.dismiss) private var dismiss
    @State private var exerciseName = ""
    @State private var selectedCategory: ExerciseCategory
    @State private var selectedPrimaryMuscles: [MuscleGroup]
    @State private var selectedSecondaryMuscles: [MuscleGroup] = []
    @State private var instructions = ""
    @State private var showingDiscardConfirmation = false
    @State private var saveResult: ExerciseManager.MutationResult?
    
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

    private var initialDraftSnapshot: DraftSnapshot {
        DraftSnapshot(
            name: ExerciseLibraryViewModel.normalizedSearchQuery(initialExerciseName),
            category: initialCategory,
            primaryMuscles: initialPrimaryMuscles,
            secondaryMuscles: [],
            instructions: ""
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

    init(
        initialExerciseName: String = "",
        initialCategory: ExerciseCategory = .compound,
        initialPrimaryMuscles: [MuscleGroup] = [],
        onExerciseSaved: ((String) -> Void)? = nil
    ) {
        self.initialExerciseName = initialExerciseName
        self.initialCategory = initialCategory
        self.initialPrimaryMuscles = initialPrimaryMuscles
        self.onExerciseSaved = onExerciseSaved
        _selectedCategory = State(initialValue: initialCategory)
        _selectedPrimaryMuscles = State(initialValue: initialPrimaryMuscles)
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
            .navigationTitle(Self.navigationTitle(for: exerciseName))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if exerciseName.isEmpty {
                    exerciseName = ExerciseLibraryViewModel.normalizedSearchQuery(initialExerciseName)
                }
            }
            .alert(
                saveResult == .persistenceFailure
                    ? Self.saveFailureAlertTitle(for: exerciseName)
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
            .alert(Self.discardAlertTitle(for: exerciseName), isPresented: $showingDiscardConfirmation) {
                Button("Keep Editing", role: .cancel) {}
                Button(Self.discardAlertActionTitle(for: exerciseName), role: .destructive) {
                    dismiss()
                }
            } message: {
                Text(Self.discardAlertMessage())
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
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
        let result = exerciseManager.addExercise(
            name: exerciseName,
            category: selectedCategory,
            primaryMuscleGroups: selectedPrimaryMuscles,
            secondaryMuscleGroups: selectedSecondaryMuscles,
            instructions: instructions
        )

        if result == .success {
            onExerciseSaved?(ExerciseManager.sanitizeExerciseName(exerciseName))
            dismiss()
        } else {
            saveResult = result
        }
    }
}
