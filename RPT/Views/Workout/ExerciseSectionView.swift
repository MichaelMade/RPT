//
//  ExerciseSectionView.swift
//  RPT
//
//  One exercise inside the live workout: its sets, RPT back-off
//  suggestions, warm-up generation, and completion state.
//

import SwiftUI

struct ExerciseSectionView: View {
    @ObservedObject var viewModel: ActiveWorkoutViewModel
    let exercise: Exercise

    @State private var editingSet: ExerciseSet?
    @State private var setToDelete: ExerciseSet?
    @State private var showingDeleteExercise = false
    @State private var showingWarmupPlan = false
    @State private var progressionNote: String?

    private var isExpanded: Bool {
        viewModel.expandedExercises.contains(exercise.id)
    }

    private var isCompleted: Bool {
        viewModel.isExerciseCompleted(exercise)
    }

    private var orderedSets: [ExerciseSet] {
        viewModel.orderedSetsForDisplay(in: exercise)
    }

    private var topWorkingSet: ExerciseSet? {
        orderedSets.first { !$0.isWarmup }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isExpanded {
                if let progressionNote {
                    Label(progressionNote, systemImage: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.amber)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 8) {
                    ForEach(orderedSets) { set in
                        SetRowView(
                            set: set,
                            setLabel: label(for: set),
                            onAdjustWeight: { delta in adjustWeight(of: set, by: delta) },
                            onAdjustReps: { delta in adjustReps(of: set, by: delta) },
                            onEdit: { editingSet = set },
                            onDelete: { setToDelete = set },
                            onLogTapped: { handleLogTap(for: set) },
                            onSetRPE: { rpe in
                                _ = viewModel.updateSetSafely(set, weight: set.weight, reps: set.reps, rpe: rpe)
                            }
                        )
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        if viewModel.addSetToExerciseSafely(exercise) {
                            SoundManager.shared.playAddSet()
                        }
                    } label: {
                        Label("Add Set", systemImage: "plus")
                    }
                    .buttonStyle(SecondaryCapsuleButtonStyle())

                    Button {
                        showingWarmupPlan = true
                    } label: {
                        Label("Warm-up", systemImage: "thermometer.low")
                    }
                    .buttonStyle(SecondaryCapsuleButtonStyle(tint: Theme.amber))

                    Spacer()
                }
            }
        }
        .rptCard(padding: 14)
        .onAppear { loadProgressionNote() }
        .sheet(item: $editingSet) { set in
            SetValueEditorSheet(set: set) { weight, reps in
                applyEditedValues(to: set, weight: weight, reps: reps)
            }
            .presentationDetents([.height(280)])
        }
        .sheet(isPresented: $showingWarmupPlan) {
            WarmupPlanView(topSetWeight: topWorkingSet?.weight ?? 0) { steps in
                for step in steps {
                    _ = viewModel.addWarmupSetSafely(to: exercise, weight: step.weight, reps: step.reps)
                }
            }
            .presentationDetents([.medium])
        }
        .alert(item: $setToDelete) { set in
            Alert(
                title: Text("Delete This Set?"),
                message: Text(deleteSetMessage(for: set)),
                primaryButton: .destructive(Text("Delete Set")) {
                    _ = viewModel.deleteSetSafely(set)
                },
                secondaryButton: .cancel()
            )
        }
        .confirmationDialog(
            "Delete \(exercise.displayName)?",
            isPresented: $showingDeleteExercise,
            titleVisibility: .visible
        ) {
            Button("Delete Exercise", role: .destructive) {
                _ = viewModel.deleteExerciseFromWorkoutSafely(exercise)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All of its sets in this workout will be removed.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.toggleExerciseCompletion(exercise)
                HapticFeedbackManager.shared.light()
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? Theme.success : Color.secondary)
            }
            .buttonStyle(.plain)

            ExerciseIconView(category: exercise.category, size: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(exercise.displayName)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(isCompleted, color: .secondary)
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                    .lineLimit(1)

                Text(setCountSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                Button(role: .destructive) {
                    showingDeleteExercise = true
                } label: {
                    Label("Delete Exercise", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toggleExerciseExpansion(exercise)
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var setCountSummary: String {
        let working = orderedSets.filter { !$0.isWarmup }.count
        let warmups = orderedSets.count - working
        var parts: [String] = [working == 1 ? "1 working set" : "\(working) working sets"]
        if warmups > 0 {
            parts.append(warmups == 1 ? "1 warm-up" : "\(warmups) warm-ups")
        }
        return parts.joined(separator: " • ")
    }

    private func label(for set: ExerciseSet) -> String {
        if set.isWarmup {
            return "W"
        }

        var number = 0
        for candidate in orderedSets where !candidate.isWarmup {
            number += 1
            if candidate.id == set.id {
                break
            }
        }
        return "\(max(1, number))"
    }

    // MARK: - Set Mutations

    private func adjustWeight(of set: ExerciseSet, by delta: Int) {
        let newWeight = max(0, set.weight + delta)
        guard viewModel.updateSetSafely(set, weight: newWeight, reps: set.reps, rpe: set.rpe) else { return }
        propagateTopSetChangeIfNeeded(for: set, newWeight: newWeight)
    }

    private func adjustReps(of set: ExerciseSet, by delta: Int) {
        let newReps = max(0, set.reps + delta)
        _ = viewModel.updateSetSafely(set, weight: set.weight, reps: newReps, rpe: set.rpe)
    }

    private func applyEditedValues(to set: ExerciseSet, weight: Int, reps: Int) {
        guard viewModel.updateSetSafely(set, weight: weight, reps: reps, rpe: set.rpe) else { return }
        propagateTopSetChangeIfNeeded(for: set, newWeight: weight)
    }

    /// Editing the top working set recalculates all back-off set suggestions.
    private func propagateTopSetChangeIfNeeded(for set: ExerciseSet, newWeight: Int) {
        guard !set.isWarmup, newWeight > 0, set.id == topWorkingSet?.id else { return }
        _ = viewModel.updateDropSetSuggestionsSafely(for: exercise, firstSetWeight: newWeight)
    }

    private func handleLogTap(for set: ExerciseSet) {
        HapticFeedbackManager.shared.medium()
        if set.isCompletedLoggedSet, viewModel.autoStartRestTimerEnabled {
            viewModel.startRestTimer()
        }
    }

    private func deleteSetMessage(for set: ExerciseSet) -> String {
        if set.isCompletedLoggedSet {
            let kind = set.isWarmup ? "logged warm-up set" : "logged working set"
            return "This removes a \(kind) (\(set.formattedWeightReps)) from \(exercise.displayName)."
        }

        return "This removes an unlogged set from \(exercise.displayName)."
    }

    // MARK: - Progression

    private func loadProgressionNote() {
        guard !viewModel.workout.isCompleted else { return }

        let history = WorkoutManager.shared.getWorkoutHistory(for: exercise)
        let lastCompleted = history.first { workout, sets in
            workout.isCompleted && workout.id != viewModel.workout.id && sets.contains(where: \.isCompletedWorkingSet)
        }

        guard let lastTopSet = lastCompleted?.sets.first(where: \.isCompletedWorkingSet), lastTopSet.weight > 0 else {
            progressionNote = nil
            return
        }

        let suggestion = ProgressionAdvisor.suggestion(
            lastWeight: lastTopSet.weight,
            lastReps: lastTopSet.reps
        )
        progressionNote = "Last top set \(lastTopSet.weight)×\(lastTopSet.reps). \(suggestion.note)"
    }
}

// MARK: - Set Row

struct SetRowView: View {
    let set: ExerciseSet
    let setLabel: String
    let onAdjustWeight: (Int) -> Void
    let onAdjustReps: (Int) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onLogTapped: () -> Void
    let onSetRPE: (Int?) -> Void

    private var isLogged: Bool {
        set.isCompletedLoggedSet
    }

    private var showRPE: Bool {
        SettingsManager.shared.settings.showRPE && !set.isWarmup
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onEdit) {
                Text(setLabel)
                    .font(.caption.weight(.bold))
                    .frame(width: 26, height: 26)
                    .background(
                        set.isWarmup ? Theme.amber.opacity(0.15) : Theme.accent.opacity(0.12),
                        in: Circle()
                    )
                    .foregroundStyle(set.isWarmup ? Theme.amber : Theme.accent)
            }
            .buttonStyle(.plain)

            ValueStepperControl(
                value: weightText,
                unit: "lb",
                onDecrement: { onAdjustWeight(-5) },
                onIncrement: { onAdjustWeight(5) }
            )

            ValueStepperControl(
                value: "\(max(0, set.reps))",
                unit: "reps",
                onDecrement: { onAdjustReps(-1) },
                onIncrement: { onAdjustReps(1) }
            )

            Spacer(minLength: 0)

            if showRPE {
                Menu {
                    ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                        Button("RPE \(value)") { onSetRPE(value) }
                    }
                    if set.displayRPE != nil {
                        Button("Clear", role: .destructive) { onSetRPE(nil) }
                    }
                } label: {
                    Text(set.displayRPE.map { "RPE \($0)" } ?? "RPE")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.05), in: Capsule())
                        .foregroundStyle(set.displayRPE != nil ? Theme.info : Color.secondary)
                }
            }

            Button(action: onLogTapped) {
                Image(systemName: isLogged ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.title3)
                    .foregroundStyle(isLogged ? Theme.success : Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit Values", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete Set", systemImage: "trash")
            }
        }
    }

    private var weightText: String {
        if set.weight == 0, set.exercise?.category == .bodyweight {
            return "BW"
        }
        return "\(max(0, set.weight))"
    }
}

// MARK: - Set Value Editor

struct SetValueEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let set: ExerciseSet
    let onSave: (Int, Int) -> Void

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case weight, reps
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Weight (lb)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("0", text: $weightText)
                            .keyboardType(.numberPad)
                            .font(Theme.statFont(size: 26))
                            .padding(12)
                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                            .focused($focusedField, equals: .weight)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reps")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("0", text: $repsText)
                            .keyboardType(.numberPad)
                            .font(Theme.statFont(size: 26))
                            .padding(12)
                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                            .focused($focusedField, equals: .reps)
                    }
                }

                Button {
                    save()
                } label: {
                    Text("Save Set")
                }
                .buttonStyle(BrandButtonStyle())

                Spacer()
            }
            .padding(Theme.screenPadding)
            .navigationTitle(set.isWarmup ? "Warm-up Set" : "Working Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                weightText = set.weight > 0 ? "\(set.weight)" : ""
                repsText = set.reps > 0 ? "\(set.reps)" : ""
                focusedField = .weight
            }
        }
    }

    private func save() {
        let weight = max(0, Int(weightText.trimmingCharacters(in: .whitespaces)) ?? 0)
        let reps = max(0, Int(repsText.trimmingCharacters(in: .whitespaces)) ?? 0)
        onSave(weight, reps)
        dismiss()
    }
}
