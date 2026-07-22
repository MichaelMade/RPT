//
//  ExerciseFormView.swift
//  RPT
//
//  Create or edit a custom exercise: name, category, muscles, and
//  coaching notes, with live validation from ExerciseManager.
//

import SwiftUI

struct ExerciseFormView: View {
    enum Mode {
        case create
        case edit(Exercise)
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    var onSaved: (() -> Void)? = nil

    @State private var name: String = ""
    @State private var category: ExerciseCategory = .compound
    @State private var primaryMuscles: Set<MuscleGroup> = []
    @State private var secondaryMuscles: Set<MuscleGroup> = []
    @State private var instructions: String = ""

    @State private var saveErrorTitle: String?
    @State private var saveErrorMessage: String = ""
    @State private var showingDiscardConfirmation = false

    private let exerciseManager = ExerciseManager.shared

    private var editedExercise: Exercise? {
        if case .edit(let exercise) = mode {
            return exercise
        }
        return nil
    }

    private var validation: ExerciseManager.DraftValidationResult {
        exerciseManager.validateDraft(
            name: name,
            primaryMuscleGroups: Array(primaryMuscles),
            excludingExerciseId: editedExercise?.id
        )
    }

    private var hasChanges: Bool {
        if let exercise = editedExercise {
            return name != exercise.name
                || category != exercise.category
                || primaryMuscles != Set(exercise.primaryMuscleGroups)
                || secondaryMuscles != Set(exercise.secondaryMuscleGroups)
                || instructions != exercise.instructions
        }

        return !name.trimmingCharacters(in: .whitespaces).isEmpty
            || !primaryMuscles.isEmpty
            || !secondaryMuscles.isEmpty
            || !instructions.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Incline Dumbbell Press", text: $name)

                    if let helperText = validation.helperText {
                        Text(helperText)
                            .font(.caption)
                            .foregroundStyle(Theme.amber)
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(ExerciseCategory.allCases, id: \.self) { category in
                            Text(category.rawValue.capitalized).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Primary Muscles") {
                    MuscleGroupGrid(selection: $primaryMuscles, tint: Theme.accent)
                }

                Section("Secondary Muscles") {
                    MuscleGroupGrid(selection: $secondaryMuscles, tint: Theme.info)
                }

                Section("Instructions") {
                    TextField("Form cues, setup notes…", text: $instructions, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(editedExercise == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if hasChanges {
                            showingDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(validation != .valid)
                }
            }
            .confirmationDialog(
                "Discard Changes?",
                isPresented: $showingDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard Changes", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) {}
            }
            .alert(saveErrorTitle ?? "Couldn’t Save Exercise", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
            .onAppear {
                if let exercise = editedExercise {
                    name = exercise.name
                    category = exercise.category
                    primaryMuscles = Set(exercise.primaryMuscleGroups)
                    secondaryMuscles = Set(exercise.secondaryMuscleGroups)
                    instructions = exercise.instructions
                }
            }
            .interactiveDismissDisabled(hasChanges)
        }
    }

    private func save() {
        let result: ExerciseManager.MutationResult

        if let exercise = editedExercise {
            result = exerciseManager.updateExercise(
                exercise,
                name: name,
                category: category,
                primaryMuscleGroups: Array(primaryMuscles),
                secondaryMuscleGroups: Array(secondaryMuscles.subtracting(primaryMuscles)),
                instructions: instructions
            )
        } else {
            result = exerciseManager.addExercise(
                name: name,
                category: category,
                primaryMuscleGroups: Array(primaryMuscles),
                secondaryMuscleGroups: Array(secondaryMuscles.subtracting(primaryMuscles)),
                instructions: instructions
            )
        }

        if result == .success {
            onSaved?()
            dismiss()
        } else {
            saveErrorTitle = result.alertTitle
            saveErrorMessage = result.alertMessage
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorTitle != nil },
            set: { if !$0 { saveErrorTitle = nil } }
        )
    }
}

// MARK: - Muscle Group Grid

struct MuscleGroupGrid: View {
    @Binding var selection: Set<MuscleGroup>
    var tint: Color = Theme.accent

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
            ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                let isSelected = selection.contains(muscle)

                Button {
                    if isSelected {
                        selection.remove(muscle)
                    } else {
                        selection.insert(muscle)
                    }
                } label: {
                    Text(muscle.displayName)
                        .font(.caption.weight(isSelected ? .semibold : .regular))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(
                            isSelected ? tint.opacity(0.18) : Color.primary.opacity(0.05),
                            in: Capsule()
                        )
                        .foregroundStyle(isSelected ? tint : .primary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 4)
    }
}
