//
//  ExerciseSetRowView.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData

struct ExerciseSetRowView: View {
    enum DraftValidationResult: Equatable {
        case valid
        case invalidWeight
        case invalidReps
        case invalidRPE

        var helperText: String? {
            switch self {
            case .valid:
                return nil
            case .invalidWeight:
                return "Enter a valid weight in pounds, or leave it blank to clear the set."
            case .invalidReps:
                return "Enter a valid rep count, or leave it blank to clear the set."
            case .invalidRPE:
                return "Leave RPE blank or enter a whole number from 1 to 10."
            }
        }
    }

    @Bindable var set: ExerciseSet
    @State private var isEditing = false
    @State private var weightInput = ""
    @State private var repsInput = ""
    @State private var rpeInput = ""
    @State private var showingDiscardChangesAlert = false
    @State private var showingDeleteConfirmation = false
    @AppStorage("showRPE") private var showRPE = true
    
    // MARK: - New Properties
    // New property to track if this is the first set
    let isFirstSet: Bool
    // New callback for updating drop sets
    let onUpdateDropSets: ((Int) -> Void)?
    // MARK: - End New Properties
        
    let onUpdate: (Int, Int, Int?) -> Void
    let onDelete: () -> Void
    var onStartRestTimer: (() -> Void)? = nil // Optional rest timer callback
    
    // MARK: - Updated Initializer
    init(set: ExerciseSet,
         isFirstSet: Bool = false, // New parameter
         onUpdate: @escaping (Int, Int, Int?) -> Void,
         onDelete: @escaping () -> Void,
         onStartRestTimer: (() -> Void)? = nil,
         onUpdateDropSets: ((Int) -> Void)? = nil) { // New parameter
        self.set = set
        self.isFirstSet = isFirstSet
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onStartRestTimer = onStartRestTimer
        self.onUpdateDropSets = onUpdateDropSets
    }
    // MARK: - End Updated Initializer

    private var draftValidation: DraftValidationResult {
        Self.validateDraft(weightInput: weightInput, repsInput: repsInput, rpeInput: rpeInput)
    }

    private var canSaveDraft: Bool {
        draftValidation == .valid
    }

    private var hasUnsavedChanges: Bool {
        Self.hasUnsavedChanges(
            comparedTo: set,
            weightInput: weightInput,
            repsInput: repsInput,
            rpeInput: rpeInput
        )
    }

    
    var body: some View {
        if isEditing {
            VStack(spacing: 12) {
                // Weight input with quick adjust buttons
                VStack(alignment: .leading, spacing: 6) {
                    Text("Weight")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        // Quick decrease buttons
                        HStack(spacing: 0) {
                            QuickAdjustButton(
                                label: "-5",
                                action: { adjustWeight(by: -5) }
                            )
                        }
                        
                        // Weight input field
                        HStack {
                            TextField("Weight", text: $weightInput)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                                .frame(minWidth: 70)
                            
                            Text("lb")
                                .foregroundColor(.secondary)
                        }
                        
                        // Quick increase buttons
                        HStack(spacing: 0) {
                            QuickAdjustButton(
                                label: "+5",
                                action: { adjustWeight(by: 5) }
                            )
                        }
                    }
                }
                
                // Reps input with quick adjust buttons
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        // Quick decrease buttons
                        HStack(spacing: 0) {
                            QuickAdjustButton(
                                label: "-1",
                                action: { adjustReps(by: -1) }
                            )
                        }
                        
                        // Reps input field
                        TextField("Reps", text: $repsInput)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                            .frame(width: 60)
                        
                        // Quick increase buttons
                        HStack(spacing: 0) {
                            QuickAdjustButton(
                                label: "+1",
                                action: { adjustReps(by: 1) }
                            )
                        }
                    }
                }
                
                // RPE input (optional)
                if showRPE {
                    VStack(alignment: .center, spacing: 6) {
                        Text("RPE (1-10)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            // RPE input field
                            TextField("Optional", text: $rpeInput)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 80)
                        }
                    }
                }
                
                if let helperText = draftValidation.helperText {
                    Text(helperText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                
                // Action buttons
                HStack(spacing: 15) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showingDiscardChangesAlert = true
                        } else {
                            isEditing = false
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button(Self.deleteButtonTitle(for: set), role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Save") {
                        saveSet()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSaveDraft)
                }
                .frame(height: 50)
            }
            .padding(8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
            .onAppear {
                
                // Initialize text fields with current values
                weightInput = "\(set.weight)"
                repsInput = "\(set.reps)"
                
                if let rpe = set.displayRPE {
                    rpeInput = "\(rpe)"
                } else {
                    rpeInput = ""
                }
            }
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(ExerciseSetRowView.displayWeightText(weight: set.weight, exerciseCategory: set.exercise?.category))
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("×")
                            .font(.headline)
                        
                        Text(ExerciseSetRowView.displayRepsText(set.reps))
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    
                    if let rpe = set.displayRPE {
                        Text("RPE: \(rpe)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    HapticFeedbackManager.shared.medium()
                    isEditing = true
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                HapticFeedbackManager.shared.medium()
                isEditing = true
            }
        }
        .alert(Self.discardChangesAlertTitle(for: set), isPresented: $showingDiscardChangesAlert) {
            Button("Keep Editing", role: .cancel) {}
            Button(Self.discardChangesAlertActionTitle(for: set), role: .destructive) {
                showingDiscardChangesAlert = false
                isEditing = false
            }
        } message: {
            Text(
                Self.discardChangesAlertMessage(
                    for: set,
                    weightInput: weightInput,
                    repsInput: repsInput,
                    rpeInput: rpeInput
                )
            )
        }
        .alert(Self.deleteAlertTitle(for: set), isPresented: $showingDeleteConfirmation) {
            Button("Keep Set", role: .cancel) {
                showingDeleteConfirmation = false
            }
            Button(Self.deleteButtonTitle(for: set), role: .destructive) {
                showingDeleteConfirmation = false
                HapticFeedbackManager.shared.heavy()
                onDelete()
            }
        } message: {
            Text(Self.deleteAlertMessage(for: set))
        }
    }

    static func deleteButtonTitle(for set: ExerciseSet) -> String {
        let prefix = set.isWarmup ? "Delete Warm-up Set" : "Delete Set"
        let hasMeaningfulLoad = set.weight > 0 || set.exercise?.category == .bodyweight
        let hasMeaningfulReps = set.reps > 0

        guard hasMeaningfulLoad || hasMeaningfulReps else {
            return prefix
        }

        let weightText = displayWeightText(weight: set.weight, exerciseCategory: set.exercise?.category)
        let repsText = displayRepsText(set.reps)
        return "\(prefix) \(weightText) × \(repsText)"
    }

    static func deleteAlertTitle(for set: ExerciseSet) -> String {
        "\(deleteButtonTitle(for: set))?"
    }

    static func deleteAlertMessage(for set: ExerciseSet) -> String {
        let workoutReference = deleteAlertWorkoutReference(for: set)

        if set.isCompletedLoggedSet {
            let kind = set.isWarmup ? "logged warm-up set" : "logged working set"

            if set.displayRPE != nil {
                return "This will remove this \(kind) and its recorded RPE from \(workoutReference)."
            }

            return "This will remove this \(kind) from \(workoutReference)."
        }

        if set.isWarmup {
            return "This warm-up set will be removed from \(workoutReference)."
        }

        if set.weight == 0 && set.reps == 0 {
            return "This empty set will be removed from \(workoutReference)."
        }

        return "This set will be removed from \(workoutReference)."
    }

    private static func deleteAlertWorkoutReference(for set: ExerciseSet) -> String {
        guard let workout = set.workout,
              let displayName = WorkoutRow.specificDisplayName(for: workout) else {
            return "this workout"
        }

        return "“\(displayName)”"
    }

    static func discardChangesAlertActionTitle(for set: ExerciseSet) -> String {
        let prefix = set.isWarmup ? "Discard Warm-up Set Changes" : "Discard Set Changes"
        let hasMeaningfulLoad = set.weight > 0 || set.exercise?.category == .bodyweight
        let hasMeaningfulReps = set.reps > 0

        guard hasMeaningfulLoad || hasMeaningfulReps else {
            return prefix
        }

        let weightText = displayWeightText(weight: set.weight, exerciseCategory: set.exercise?.category)
        let repsText = displayRepsText(set.reps)
        return "\(prefix) to \(weightText) × \(repsText)"
    }

    static func discardChangesAlertTitle(for set: ExerciseSet) -> String {
        "\(discardChangesAlertActionTitle(for: set))?"
    }

    static func discardChangesAlertMessage(for set: ExerciseSet, weightInput: String, repsInput: String, rpeInput: String) -> String {
        let fieldSummaries = discardFieldSummaries(for: set, weightInput: weightInput, repsInput: repsInput, rpeInput: rpeInput)

        guard !fieldSummaries.isEmpty else {
            return "Your changes to this set haven’t been saved."
        }

        return "This will discard your \(joinedDiscardFieldSummary(fieldSummaries)) for this set."
    }

    static func hasUnsavedChanges(comparedTo set: ExerciseSet, weightInput: String, repsInput: String, rpeInput: String) -> Bool {
        let parsedWeight = sanitizedInteger(from: weightInput, emptyValue: 0)
        let parsedReps = sanitizedInteger(from: repsInput, emptyValue: 0)
        let parsedRPE = sanitizedInteger(from: rpeInput, emptyValue: nil)

        guard let parsedWeight, let parsedReps else {
            let trimmedWeight = weightInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedReps = repsInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedRPE = rpeInput.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmedWeight.isEmpty || !trimmedReps.isEmpty || !trimmedRPE.isEmpty
        }

        return parsedWeight != set.weight
            || parsedReps != set.reps
            || parsedRPE != set.displayRPE
    }

    static func validateDraft(weightInput: String, repsInput: String, rpeInput: String) -> DraftValidationResult {
        guard sanitizedInteger(from: weightInput, emptyValue: 0) != nil else {
            return .invalidWeight
        }

        guard sanitizedInteger(from: repsInput, emptyValue: 0) != nil else {
            return .invalidReps
        }

        let trimmedRPE = rpeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRPE.isEmpty {
            guard let rpe = sanitizedInteger(from: rpeInput, emptyValue: nil), (1...10).contains(rpe) else {
                return .invalidRPE
            }
        }

        return .valid
    }

    static func sanitizedInteger(from input: String, emptyValue: Int?) -> Int? {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedInput.isEmpty else {
            return emptyValue
        }

        guard let parsedValue = Int(trimmedInput), parsedValue >= 0 else {
            return nil
        }

        return parsedValue
    }

    private static func discardFieldSummaries(for set: ExerciseSet, weightInput: String, repsInput: String, rpeInput: String) -> [String] {
        var summaries: [String] = []

        if hasDraftFieldChanged(parsedValue: sanitizedInteger(from: weightInput, emptyValue: 0), rawInput: weightInput, currentValue: set.weight) {
            summaries.append(
                "weight (\(displayWeightText(weight: set.weight, exerciseCategory: set.exercise?.category)) → \(draftWeightText(weightInput, exerciseCategory: set.exercise?.category)))"
            )
        }

        if hasDraftFieldChanged(parsedValue: sanitizedInteger(from: repsInput, emptyValue: 0), rawInput: repsInput, currentValue: set.reps) {
            summaries.append("reps (\(displayRepsText(set.reps)) → \(draftRepsText(repsInput)))")
        }

        if hasDraftFieldChanged(parsedValue: sanitizedInteger(from: rpeInput, emptyValue: nil), rawInput: rpeInput, currentValue: set.displayRPE) {
            summaries.append("RPE (\(displayRPEText(set.displayRPE)) → \(draftRPEText(rpeInput)))")
        }

        return summaries
    }

    private static func hasDraftFieldChanged(parsedValue: Int?, rawInput: String, currentValue: Int?) -> Bool {
        if let parsedValue {
            return parsedValue != currentValue
        }

        return !rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func draftWeightText(_ input: String, exerciseCategory: ExerciseCategory?) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return "cleared"
        }

        guard let parsedWeight = Int(trimmed), parsedWeight >= 0 else {
            return "“\(trimmed)”"
        }

        return displayWeightText(weight: parsedWeight, exerciseCategory: exerciseCategory)
    }

    private static func draftRepsText(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return "cleared"
        }

        guard let parsedReps = Int(trimmed), parsedReps >= 0 else {
            return "“\(trimmed)”"
        }

        return displayRepsText(parsedReps)
    }

    private static func draftRPEText(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return "cleared"
        }

        guard let parsedRPE = Int(trimmed), parsedRPE >= 0 else {
            return "“\(trimmed)”"
        }

        return String(parsedRPE)
    }

    private static func displayRPEText(_ rpe: Int?) -> String {
        guard let rpe else {
            return "blank"
        }

        return String(rpe)
    }

    private static func joinedDiscardFieldSummary(_ fields: [String]) -> String {
        switch fields.count {
        case 0:
            return "changes"
        case 1:
            return fields[0] + " change"
        case 2:
            return fields[0] + " and " + fields[1] + " changes"
        default:
            let head = fields.dropLast().joined(separator: ", ")
            return head + ", and " + fields.last! + " changes"
        }
    }
    
    // MARK: - Helper Methods
    
    private func adjustWeight(by amount: Int) {
        // Provide haptic feedback
        HapticFeedbackManager.shared.medium()
        
        // Parse current weight
        if let currentWeight = Int(weightInput) {
            let newWeight = max(0, currentWeight + amount)
            // Round to nearest 5
            let roundedWeight = WorkoutManager.shared.roundToNearest5(Double(newWeight))
            weightInput = "\(roundedWeight)"
        } else if amount > 0 {
            // If field is empty and we're increasing, start at the increment
            let roundedAmount = WorkoutManager.shared.roundToNearest5(Double(abs(amount)))
            weightInput = "\(roundedAmount)"
        }
    }
    
    private func adjustReps(by amount: Int) {
        // Provide haptic feedback
        HapticFeedbackManager.shared.medium()
        
        // Parse current reps
        if let currentReps = Int(repsInput) {
            let newReps = max(0, currentReps + amount)
            repsInput = "\(newReps)"
        } else if amount > 0 {
            // If field is empty and we're increasing, start at the increment
            repsInput = "\(abs(amount))"
        }
    }
    
    // MARK: - Modified saveSet method
    private func saveSet() {
        guard canSaveDraft else {
            return
        }

        // Provide haptic feedback
        HapticFeedbackManager.shared.heavy()
        
        // Convert inputs to appropriate types
        if let parsedWeight = Self.sanitizedInteger(from: weightInput, emptyValue: 0),
           let parsedReps = Self.sanitizedInteger(from: repsInput, emptyValue: 0) {
            let rpe = Self.sanitizedInteger(from: rpeInput, emptyValue: nil)

            // Validate inputs
            let weight = WorkoutManager.shared.roundToNearest5(Double(parsedWeight))
            let validatedReps = parsedReps
            let validatedRPE = rpe

            let wasCompletedWorkingSet = set.isCompletedWorkingSet

            // Update the set
            onUpdate(weight, validatedReps, validatedRPE)

            if isFirstSet && ExerciseSetRowView.shouldUpdateDropSets(
                weight: weight,
                reps: validatedReps,
                isWarmup: set.isWarmup,
                exerciseCategory: set.exercise?.category
            ) {
                onUpdateDropSets?(weight)
            }

            isEditing = false

            // Start rest timer only when a set transitions into a completed working set.
            if ExerciseSetRowView.shouldStartRestTimer(
                weight: weight,
                reps: validatedReps,
                isWarmup: set.isWarmup,
                exerciseCategory: set.exercise?.category,
                wasCompletedWorkingSet: wasCompletedWorkingSet
            ), let startTimer = onStartRestTimer {
                // Small delay to allow the keyboard to dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    startTimer()
                }
            }
        }
    }

    static func shouldUpdateDropSets(weight: Int, reps: Int, isWarmup: Bool, exerciseCategory: ExerciseCategory? = nil) -> Bool {
        !isWarmup && ExerciseSet.hasCompletedValues(weight: weight, reps: reps, exerciseCategory: exerciseCategory)
    }

    static func shouldStartRestTimer(weight: Int, reps: Int, isWarmup: Bool, exerciseCategory: ExerciseCategory? = nil, wasCompletedWorkingSet: Bool = false) -> Bool {
        !wasCompletedWorkingSet && shouldUpdateDropSets(weight: weight, reps: reps, isWarmup: isWarmup, exerciseCategory: exerciseCategory)
    }

    static func displayWeightText(weight: Int, exerciseCategory: ExerciseCategory? = nil) -> String {
        if exerciseCategory == .bodyweight && weight == 0 {
            return "BW"
        }

        return "\(weight) lb"
    }

    static func displayRepsText(_ reps: Int) -> String {
        "\(reps) \(reps == 1 ? "rep" : "reps")"
    }

    // MARK: - Quick Adjust Button Component
    struct QuickAdjustButton: View {
        let label: String
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
        }
    }
}

#Preview {
    // Create a model container for preview
    let modelContainer = try! ModelContainer(for: ExerciseSet.self, Exercise.self)
    
    // Create a sample exercise and set
    let exercise = Exercise(
        name: "Bench Press",
        category: .compound,
        primaryMuscleGroups: [.chest],
        secondaryMuscleGroups: [.triceps, .shoulders]
    )
    
    let set = ExerciseSet(
        weight: 225,
        reps: 8,
        exercise: exercise
    )
    
    return VStack(spacing: 20) {
        // Normal set view
        ExerciseSetRowView(
            set: set,
            isFirstSet: true,
            onUpdate: { _, _, _ in },
            onDelete: { }
        )
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
        
        // Another set with edit mode on initially
        let editSet = ExerciseSet(
            weight: 200,
            reps: 10,
            exercise: exercise,
            rpe: 8
        )
        
        ExerciseSetRowView(
            set: editSet,
            onUpdate: { _, _, _ in },
            onDelete: { }
        )
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
        .onAppear {
            // This doesn't actually work in preview, but shows the editing UI
            // for demonstration purposes
        }
    }
    .padding()
    .modelContainer(modelContainer)
}
