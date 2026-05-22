//
//  TemplateExerciseEditView.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData

struct TemplateExerciseEditView: View {
    private struct DraftSnapshot: Equatable {
        let suggestedSets: Int
        let notes: String

        init(suggestedSets: Int, notes: String) {
            self.suggestedSets = suggestedSets
            self.notes = Self.normalizedDraftText(notes)
        }

        private static func normalizedDraftText(_ raw: String) -> String {
            raw
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var suggestedSets: Int
    @State private var notes: String
    @State private var showingDiscardConfirmation = false
    
    // Store the exercise for reference
    let exercise: TemplateExercise
    let onSave: (TemplateExercise) -> Void
    
    init(exercise: TemplateExercise, onSave: @escaping (TemplateExercise) -> Void) {
        self.exercise = exercise
        self.onSave = onSave
        
        // Initialize state with explicit values
        _suggestedSets = State(initialValue: exercise.suggestedSets)
        _notes = State(initialValue: exercise.notes)
    }

    private var previewRepRanges: [TemplateRepRange] {
        TemplateExercise.normalizedRepRanges(for: suggestedSets, from: exercise.repRanges)
    }

    private var initialDraftSnapshot: DraftSnapshot {
        DraftSnapshot(suggestedSets: exercise.suggestedSets, notes: exercise.notes)
    }

    private var currentDraftSnapshot: DraftSnapshot {
        DraftSnapshot(suggestedSets: suggestedSets, notes: notes)
    }

    private var hasUnsavedChanges: Bool {
        currentDraftSnapshot != initialDraftSnapshot
    }

    private var discardImpactFields: [String] {
        var fields: [String] = []

        if currentDraftSnapshot.suggestedSets != initialDraftSnapshot.suggestedSets {
            fields.append("planned set count")
        }

        if currentDraftSnapshot.notes != initialDraftSnapshot.notes {
            fields.append("notes")
        }

        return fields
    }

    private var discardAlertTitle: String {
        Self.discardAlertTitle(for: exercise.exerciseName)
    }

    private var discardAlertActionTitle: String {
        Self.discardAlertActionTitle(for: exercise.exerciseName)
    }

    static func discardAlertTitle(for exerciseName: String) -> String {
        let displayName = TemplateExercise.normalizedDisplayName(exerciseName)
        return displayName == "Unnamed Exercise"
            ? "Discard Exercise Changes?"
            : "Discard “\(displayName)”?"
    }

    static func discardAlertActionTitle(for exerciseName: String) -> String {
        let displayName = TemplateExercise.normalizedDisplayName(exerciseName)
        return displayName == "Unnamed Exercise"
            ? "Discard Changes"
            : "Discard “\(displayName)”"
    }

    static func discardAlertMessage(changedFields: [String]) -> String {
        guard !changedFields.isEmpty else {
            return "You’ll lose your unsaved changes to this template exercise."
        }

        return "You’ll lose your unsaved changes to this template exercise, including its \(humanReadableList(changedFields))."
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
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Exercise Details")) {
                    Text(TemplateExercise.normalizedDisplayName(exercise.exerciseName))
                        .font(.headline)
                    
                    VStack(alignment: .leading) {
                        Text("Number of Sets")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.bottom, 4)
                        
                        HStack(spacing: 10) {
                            ForEach([1, 2, 3, 4, 5], id: \.self) { num in
                                Button(action: {
                                    suggestedSets = num
                                }) {
                                    Text("\(num)")
                                        .frame(width: 50, height: 50)
                                        .background(suggestedSets == num ? Color.blue : Color.gray.opacity(0.2))
                                        .foregroundColor(suggestedSets == num ? .white : .primary)
                                        .cornerRadius(8)
                                        .font(.headline)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel("\(num) sets")
                            }
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                    
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(5)
                }
                
                Section {
                    Text("This exercise will use \(suggestedSets) sets with the Reverse Pyramid Training pattern.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sets will follow this pattern:")
                            .font(.subheadline)
                            .padding(.bottom, 4)
                        
                        ForEach(previewRepRanges, id: \.setNumber) { repRange in
                            let percentage = Int((repRange.percentageOfFirstSet ?? 1.0) * 100)

                            HStack {
                                Text("Set \(repRange.setNumber):")
                                    .fontWeight(.medium)
                                
                                Text("\(repRange.minReps)-\(repRange.maxReps) reps")
                                
                                if repRange.setNumber > 1 {
                                    Text("(\(percentage)% of first set)")
                                        .foregroundColor(.blue)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle(TemplateViewModel.templateExerciseEditorNavigationTitle(for: exercise.exerciseName))
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
                        // Create a completely new exercise object with the updated values
                        let updatedExercise = TemplateExercise(
                            id: exercise.id,
                            exerciseName: exercise.exerciseName,
                            suggestedSets: suggestedSets,  // Use the updated set count
                            repRanges: exercise.repRanges,
                            notes: notes
                        )
                        
                        onSave(updatedExercise)
                        dismiss()
                    }
                }
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
                Text(Self.discardAlertMessage(changedFields: discardImpactFields))
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
        }
    }
}

#Preview {
    // Create a sample template exercise for the preview
    let sampleExercise = TemplateExercise(
        exerciseName: "Bench Press",
        suggestedSets: 3,
        repRanges: [
            TemplateRepRange(setNumber: 1, minReps: 4, maxReps: 6, percentageOfFirstSet: 1.0),
            TemplateRepRange(setNumber: 2, minReps: 6, maxReps: 8, percentageOfFirstSet: 0.9),
            TemplateRepRange(setNumber: 3, minReps: 8, maxReps: 10, percentageOfFirstSet: 0.8)
        ],
        notes: "Focus on chest contraction"
    )
    
    return TemplateExerciseEditView(
        exercise: sampleExercise,
        onSave: { _ in
            // This is just a preview, so no need to handle the save action
        }
    )
}
