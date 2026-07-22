//
//  TemplateEditView.swift
//  RPT
//
//  Create or edit a routine: name, notes, and the exercise list with
//  per-exercise set counts and rep ranges.
//

import SwiftUI
import SwiftData

struct TemplateEditView: View {
    enum Mode {
        case create
        case edit(WorkoutTemplate)
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    var onSaved: (() -> Void)? = nil

    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var exercises: [TemplateExercise] = []

    @State private var showingExercisePicker = false
    @State private var editingExercise: TemplateExercise?
    @State private var showingDiscardConfirmation = false
    @State private var saveErrorTitle: String?
    @State private var saveErrorMessage: String = ""

    // TemplateExercise equality is id-based, so rep-range edits don't show
    // up in array comparison; track them explicitly.
    @State private var didEditPrescriptions = false

    private let templateManager = TemplateManager.shared

    private var editedTemplate: WorkoutTemplate? {
        if case .edit(let template) = mode {
            return template
        }
        return nil
    }

    private var validation: TemplateManager.DraftValidationResult {
        templateManager.validateDraft(
            name: name,
            exercises: exercises,
            excludingTemplateId: editedTemplate?.id
        )
    }

    private var hasChanges: Bool {
        if let template = editedTemplate {
            return name != template.name
                || notes != template.notes
                || exercises != template.exercises
                || didEditPrescriptions
        }

        return !name.trimmingCharacters(in: .whitespaces).isEmpty
            || !notes.trimmingCharacters(in: .whitespaces).isEmpty
            || !exercises.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Upper Body A", text: $name)

                    if let helperText = validation.helperText {
                        Text(helperText)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.dropOneForeground)
                    }
                }
                .listRowBackground(Theme.cardBackground)

                Section("Exercises") {
                    if exercises.isEmpty {
                        Text("Add at least one exercise.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    ForEach(exercises) { exercise in
                        Button {
                            editingExercise = exercise
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.exerciseName)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Theme.textPrimary)

                                    Text(prescriptionSummary(for: exercise))
                                        .font(.system(size: 12))
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "pencil")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        exercises.remove(atOffsets: offsets)
                    }
                    .onMove { source, destination in
                        exercises.move(fromOffsets: source, toOffset: destination)
                    }

                    Button {
                        showingExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                            .foregroundStyle(Theme.primary)
                    }
                }
                .listRowBackground(Theme.cardBackground)

                Section("Notes") {
                    TextField("Rest 2–3 minutes between sets…", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
                .listRowBackground(Theme.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.screenBackground)
            .navigationTitle(editedTemplate == nil ? "New Template" : "Edit Template")
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
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(
                    excludedExerciseIDs: alreadyAddedExerciseIDs,
                    title: "Add to Template"
                ) { exercise in
                    addExercise(named: exercise.name)
                }
            }
            .sheet(item: $editingExercise) { exercise in
                TemplateExerciseEditorSheet(templateExercise: exercise) { updated in
                    if let index = exercises.firstIndex(where: { $0.id == updated.id }) {
                        exercises[index] = updated
                        didEditPrescriptions = true
                    }
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
            .alert(saveErrorTitle ?? "Couldn’t Save Template", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
            .onAppear {
                if let template = editedTemplate {
                    name = template.name
                    notes = template.notes
                    exercises = template.exercises
                }
            }
            .interactiveDismissDisabled(hasChanges)
        }
    }

    // MARK: - Helpers

    private func prescriptionSummary(for exercise: TemplateExercise) -> String {
        let ranges = exercise.repRanges.sorted { $0.setNumber < $1.setNumber }
        guard let first = ranges.first else {
            return "\(exercise.suggestedSets) sets"
        }

        return "\(exercise.suggestedSets) sets • top set \(first.minReps)–\(first.maxReps) reps"
    }

    /// Library exercises already in this template, so the picker hides them
    /// instead of silently swallowing a duplicate selection.
    private var alreadyAddedExerciseIDs: Set<PersistentIdentifier> {
        let templateExerciseNames = exercises.map(\.exerciseName)
        let matchingIDs = ExerciseManager.shared.fetchAllExercises()
            .filter { libraryExercise in
                templateExerciseNames.contains {
                    ExerciseManager.namesCollide($0, libraryExercise.name)
                }
            }
            .map(\.id)
        return Set(matchingIDs)
    }

    private func addExercise(named exerciseName: String) {
        let alreadyAdded = exercises.contains {
            ExerciseManager.namesCollide($0.exerciseName, exerciseName)
        }
        guard !alreadyAdded else { return }

        exercises.append(
            TemplateExercise(
                exerciseName: exerciseName,
                suggestedSets: 3,
                repRanges: [
                    TemplateRepRange(setNumber: 1, minReps: 6, maxReps: 8, percentageOfFirstSet: 1.0),
                    TemplateRepRange(setNumber: 2, minReps: 8, maxReps: 10, percentageOfFirstSet: 0.9),
                    TemplateRepRange(setNumber: 3, minReps: 10, maxReps: 12, percentageOfFirstSet: 0.8)
                ],
                notes: ""
            )
        )
    }

    private func save() {
        let result: TemplateManager.MutationResult

        if let template = editedTemplate {
            result = templateManager.updateTemplate(template, name: name, exercises: exercises, notes: notes)
        } else {
            result = templateManager.createTemplate(name: name, exercises: exercises, notes: notes)
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

// MARK: - Template Exercise Editor

struct TemplateExerciseEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let templateExercise: TemplateExercise
    let onSave: (TemplateExercise) -> Void

    @State private var setCount: Int = 3
    @State private var repRanges: [TemplateRepRange] = []
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Sets") {
                    Stepper("Working sets: \(setCount)", value: $setCount, in: 1...6)
                        .monospacedDigit()
                        .onChange(of: setCount) { _, newValue in
                            repRanges = TemplateExercise.normalizedRepRanges(for: newValue, from: repRanges)
                        }
                }
                .listRowBackground(Theme.cardBackground)

                Section("Rep Ranges") {
                    ForEach($repRanges, id: \.setNumber) { $range in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(range.setNumber == 1 ? "Top set" : "Back-off \(range.setNumber - 1)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)

                            HStack {
                                Stepper("Min \(range.minReps)", value: $range.minReps, in: 1...30)
                                    .font(.system(size: 14))
                                    .monospacedDigit()
                            }

                            HStack {
                                Stepper("Max \(range.maxReps)", value: $range.maxReps, in: range.minReps...30)
                                    .font(.system(size: 14))
                                    .monospacedDigit()
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listRowBackground(Theme.cardBackground)

                Section("Notes") {
                    TextField("Form cues for this movement…", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                .listRowBackground(Theme.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.screenBackground)
            .navigationTitle(templateExercise.exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let updated = TemplateExercise(
                            id: templateExercise.id,
                            exerciseName: templateExercise.exerciseName,
                            suggestedSets: setCount,
                            repRanges: sanitizedRanges(),
                            notes: notes
                        )
                        onSave(updated)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                setCount = max(1, templateExercise.suggestedSets)
                repRanges = TemplateExercise.normalizedRepRanges(
                    for: max(1, templateExercise.suggestedSets),
                    from: templateExercise.repRanges
                )
                notes = templateExercise.notes
            }
        }
    }

    private func sanitizedRanges() -> [TemplateRepRange] {
        repRanges.map { range in
            TemplateRepRange(
                setNumber: range.setNumber,
                minReps: range.minReps,
                maxReps: max(range.minReps, range.maxReps),
                percentageOfFirstSet: range.percentageOfFirstSet
            )
        }
    }
}
