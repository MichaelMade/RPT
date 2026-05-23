//
//  TemplateEditView.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData

struct TemplateEditView: View {
    private struct DraftSnapshot: Equatable {
        struct ExerciseSnapshot: Equatable {
            let id: UUID
            let name: String
            let suggestedSets: Int
            let repRanges: [TemplateRepRange]
            let notes: String
        }

        let name: String
        let notes: String
        let exercises: [ExerciseSnapshot]

        init(name: String, notes: String, exercises: [TemplateExercise]) {
            self.name = Self.normalizedDraftText(name)
            self.notes = Self.normalizedDraftText(notes)
            self.exercises = exercises.map {
                ExerciseSnapshot(
                    id: $0.id,
                    name: Self.normalizedDraftText($0.exerciseName),
                    suggestedSets: $0.suggestedSets,
                    repRanges: $0.repRanges,
                    notes: Self.normalizedDraftText($0.notes)
                )
            }
        }

        private static func normalizedDraftText(_ raw: String) -> String {
            let collapsed = raw
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            return String(collapsed.prefix(80))
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var templateName = ""
    @State private var templateNotes = ""
    @State private var exercises: [TemplateExercise] = []
    @State private var showingExerciseSelector = false
    @State private var showingExerciseEditor: TemplateExercise?
    @State private var showingDiscardConfirmation = false
    @State private var exerciseToDelete: TemplateExercise?
    @State private var showingDeleteExerciseConfirmation = false
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

    private func saveAlertTitle(for result: TemplateManager.MutationResult) -> String {
        switch result {
        case .persistenceFailure:
            return TemplateViewModel.templateSaveFailureAlertTitle(for: templateName)
        default:
            return result.alertTitle
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

    private var initialDraftSnapshot: DraftSnapshot {
        if let existingTemplate {
            return DraftSnapshot(
                name: existingTemplate.name,
                notes: existingTemplate.notes,
                exercises: existingTemplate.exercises
            )
        }

        return DraftSnapshot(
            name: initialTemplateName,
            notes: initialTemplateNotes,
            exercises: initialExercises
        )
    }

    private var currentDraftSnapshot: DraftSnapshot {
        DraftSnapshot(name: templateName, notes: templateNotes, exercises: exercises)
    }

    private var hasUnsavedChanges: Bool {
        currentDraftSnapshot != initialDraftSnapshot
    }

    private var discardAlertTitle: String {
        Self.discardAlertTitle(isNewTemplate: isNewTemplate, templateName: templateName)
    }

    private var discardAlertMessage: String {
        Self.discardAlertMessage(
            isNewTemplate: isNewTemplate,
            changedFields: discardImpactFields
        )
    }

    private var discardAlertActionTitle: String {
        Self.discardAlertActionTitle(isNewTemplate: isNewTemplate, templateName: templateName)
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

    private func queueExerciseDeletion(_ exercise: TemplateExercise) {
        exerciseToDelete = exercise
        showingDeleteExerciseConfirmation = true
    }

    static func discardAlertTitle(isNewTemplate: Bool, templateName: String) -> String {
        if let displayName = specificTemplateDisplayName(templateName) {
            return "Discard “\(displayName)”?"
        }

        return isNewTemplate ? "Discard New Template?" : "Discard Template Changes?"
    }

    static func discardAlertActionTitle(isNewTemplate: Bool, templateName: String) -> String {
        if let displayName = specificTemplateDisplayName(templateName) {
            return "Discard “\(displayName)”"
        }

        return isNewTemplate ? "Discard New Template" : "Discard Changes"
    }

    private static func specificTemplateDisplayName(_ rawTemplateName: String) -> String? {
        let displayName = WorkoutTemplate.normalizedDisplayName(rawTemplateName)
        return displayName == "Template" ? nil : displayName
    }

    static func discardAlertMessage(isNewTemplate: Bool, changedFields: [String]) -> String {
        let prefix = isNewTemplate
            ? "You’ll lose this template draft"
            : "You’ll lose your unsaved changes to this template"

        guard !changedFields.isEmpty else {
            return prefix + "."
        }

        return prefix + ", including its \(humanReadableList(changedFields))."
    }

    private var discardImpactFields: [String] {
        var fields: [String] = []

        if currentDraftSnapshot.name != initialDraftSnapshot.name {
            fields.append("name")
        }

        if currentDraftSnapshot.notes != initialDraftSnapshot.notes {
            fields.append("notes")
        }

        if exerciseLineupChanged {
            fields.append("exercise list")
        }

        if exerciseProgrammingChanged {
            fields.append("planned sets or rep targets")
        }

        if exerciseNotesChanged {
            fields.append("exercise notes")
        }

        return fields
    }

    private var exerciseLineupChanged: Bool {
        guard currentDraftSnapshot.exercises.count == initialDraftSnapshot.exercises.count else {
            return true
        }

        return zip(currentDraftSnapshot.exercises, initialDraftSnapshot.exercises).contains { current, initial in
            current.id != initial.id || current.name != initial.name
        }
    }

    private var exerciseProgrammingChanged: Bool {
        guard currentDraftSnapshot.exercises.count == initialDraftSnapshot.exercises.count else {
            return false
        }

        return zip(currentDraftSnapshot.exercises, initialDraftSnapshot.exercises).contains { current, initial in
            current.suggestedSets != initial.suggestedSets || current.repRanges != initial.repRanges
        }
    }

    private var exerciseNotesChanged: Bool {
        guard currentDraftSnapshot.exercises.count == initialDraftSnapshot.exercises.count else {
            return false
        }

        return zip(currentDraftSnapshot.exercises, initialDraftSnapshot.exercises).contains { current, initial in
            current.notes != initial.notes
        }
    }

    private static func humanReadableList(_ items: [String]) -> String {
        switch items.count {
        case 0:
            return ""
        case 1:
            return items[0]
        case 2:
            return "\(items[0]) and \(items[1])"
        default:
            let head = items.dropLast().joined(separator: ", ")
            return "\(head), and \(items.last!)"
        }
    }

    static func deleteExerciseAlertTitle(for exerciseName: String) -> String {
        if let displayName = specificTemplateExerciseDisplayName(exerciseName) {
            return "Delete “\(displayName)” from Template?"
        }

        return "Delete This Exercise?"
    }

    static func deleteExerciseActionTitle(for exerciseName: String) -> String {
        if let displayName = specificTemplateExerciseDisplayName(exerciseName) {
            return "Delete “\(displayName)”"
        }

        return "Delete Exercise"
    }

    static func deleteExerciseAlertMessage(for exercise: TemplateExercise?) -> String {
        guard let exercise else {
            return "This exercise setup will be removed from this template."
        }

        let hasNotes = TemplateExercise.normalizedDisplayNotes(exercise.notes) != nil
        let hasRepTargets = !exercise.repRanges.isEmpty

        guard exercise.suggestedSets > 0 || hasRepTargets || hasNotes else {
            return "This exercise setup will be removed from this template."
        }

        if exercise.suggestedSets > 0 {
            let setSummary = exercise.suggestedSets == 1 ? "1 planned set" : "\(exercise.suggestedSets) planned sets"
            let repTargetSummary = exercise.suggestedSets == 1 ? "its rep target" : "their rep targets"

            if hasRepTargets && hasNotes {
                return "This will remove \(setSummary), \(repTargetSummary), and any exercise notes from this template."
            }

            if hasRepTargets {
                return "This will remove \(setSummary) and \(repTargetSummary) from this template."
            }

            if hasNotes {
                return "This will remove \(setSummary) and any exercise notes from this template."
            }

            return "This will remove \(setSummary) from this template."
        }

        if hasNotes {
            return hasRepTargets
                ? "This will remove the rep targets and any exercise notes from this template."
                : "This will remove any exercise notes from this template."
        }

        return "This will remove the rep targets from this template."
    }

    private static func specificTemplateExerciseDisplayName(_ rawExerciseName: String) -> String? {
        let displayName = TemplateExercise.normalizedDisplayName(rawExerciseName)
        return displayName == "Exercise" ? nil : displayName
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
                        guard let index = indexSet.first else { return }
                        queueExerciseDeletion(exercises[index])
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
                        if hasUnsavedChanges {
                            showingDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
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
            .alert(discardAlertTitle, isPresented: $showingDiscardConfirmation) {
                Button(discardAlertActionTitle, role: .destructive) {
                    showingDiscardConfirmation = false
                    dismiss()
                }

                Button("Keep Editing", role: .cancel) {
                    showingDiscardConfirmation = false
                }
            } message: {
                Text(discardAlertMessage)
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .confirmationDialog(
                Self.deleteExerciseAlertTitle(for: exerciseToDelete?.exerciseName ?? ""),
                isPresented: $showingDeleteExerciseConfirmation,
                presenting: exerciseToDelete
            ) { exercise in
                Button(Self.deleteExerciseActionTitle(for: exercise.exerciseName), role: .destructive) {
                    removeExercise(id: exercise.id)
                    exerciseToDelete = nil
                }

                Button("Keep Exercise", role: .cancel) {
                    exerciseToDelete = nil
                }
            } message: { exercise in
                Text(Self.deleteExerciseAlertMessage(for: exercise))
            }
            .alert(
                saveResult.map(saveAlertTitle(for:)) ?? TemplateManager.MutationResult.persistenceFailure.alertTitle,
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
