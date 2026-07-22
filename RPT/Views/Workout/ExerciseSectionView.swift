//
//  ExerciseSectionView.swift
//  RPT
//
//  One exercise inside the live workout, rendered as a card: the RPT drop
//  ladder as a set table, back-off suggestions, warm-up generation, plate
//  math, and completion state. Completed and upcoming exercises collapse
//  to summary rows; the active exercise carries the full table.
//

import SwiftUI

struct ExerciseSectionView: View {
    @ObservedObject var viewModel: ActiveWorkoutViewModel
    let exercise: Exercise

    @State private var editingSet: ExerciseSet?
    /// True when the editor was opened by a log tap on an empty set, so a
    /// successful save finishes the check-off (haptic + auto rest timer).
    @State private var editorOpenedForLogging = false
    @State private var setToDelete: ExerciseSet?
    @State private var showingDeleteExercise = false
    @State private var showingWarmupPlan = false
    @State private var showingPlateCalculator = false
    @State private var progressionNote: String?
    @State private var progressionTargetWeight: Int?

    private var isExpanded: Bool {
        viewModel.expandedExercises.contains(exercise.id)
    }

    private var isCompleted: Bool {
        viewModel.isExerciseCompleted(exercise)
    }

    /// The first not-yet-completed exercise in the workout is the one being trained.
    private var isActive: Bool {
        viewModel.exerciseOrder.first(where: { !viewModel.isExerciseCompleted($0) })?.id == exercise.id
    }

    private var orderedSets: [ExerciseSet] {
        viewModel.orderedSetsForDisplay(in: exercise)
    }

    private var workingSets: [ExerciseSet] {
        orderedSets.filter { !$0.isWarmup }
    }

    private var topWorkingSet: ExerciseSet? {
        workingSets.first
    }

    /// The next set to perform — first unlogged set in display order.
    private var nextSet: ExerciseSet? {
        orderedSets.first { !$0.isCompletedLoggedSet }
    }

    var body: some View {
        Group {
            if isExpanded {
                expandedCard
            } else if isCompleted {
                completedRow
            } else {
                upNextRow
            }
        }
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .strokeBorder(isActive ? Theme.primary : Theme.border, lineWidth: 1)
        )
        .shadow(
            color: isActive ? Theme.primary.opacity(0.08) : .black.opacity(0.04),
            radius: isActive ? 10 : 6,
            x: 0,
            y: isActive ? 4 : 2
        )
        .onAppear {
            loadProgressionNote()
            // Match the board layout: only the exercise being trained opens
            // with its full set table; the queue stays collapsed.
            if !isActive, !isCompleted, isExpanded {
                viewModel.toggleExerciseExpansion(exercise)
            }
        }
        .onChange(of: isActive) { _, nowActive in
            if nowActive, !isExpanded {
                viewModel.toggleExerciseExpansion(exercise)
            }
        }
        .sheet(item: $editingSet) { set in
            SetValueEditorSheet(set: set) { weight, reps in
                applyEditedValues(to: set, weight: weight, reps: reps)
            }
            .presentationDetents([.height(320), .medium])
        }
        .sheet(isPresented: $showingWarmupPlan) {
            WarmupPlanView(topSetWeight: topWorkingSet?.weight ?? 0) { steps in
                for step in steps {
                    _ = viewModel.addWarmupSetSafely(to: exercise, weight: step.weight, reps: step.reps)
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingPlateCalculator) {
            PlateCalculatorView(initialTargetWeight: nextSet?.weight ?? topWorkingSet?.weight ?? 0)
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

    // MARK: - Expanded Card

    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            if let note = attributedProgressionNote {
                coachingBanner(note)
                    .padding(.horizontal, 14)
            }

            columnHeader

            ForEach(orderedSets) { set in
                SetTableRow(
                    set: set,
                    setLabel: label(for: set),
                    ladder: ladderInfo(for: set),
                    isNextUp: set.id == nextSet?.id,
                    onEdit: {
                        editorOpenedForLogging = false
                        editingSet = set
                    },
                    onDelete: { setToDelete = set },
                    onLogTapped: { handleLogTap(for: set) },
                    onSetRPE: { rpe in
                        _ = viewModel.updateSetSafely(set, weight: set.weight, reps: set.reps, rpe: rpe)
                    }
                )
            }

            footerRow
        }
    }

    private var cardHeader: some View {
        HStack(spacing: 10) {
            completionToggle

            VStack(alignment: .leading, spacing: 1) {
                Text(exercise.displayName)
                    .font(Theme.titleFont(size: 15))
                    .foregroundStyle(isCompleted ? Theme.textSecondary : Theme.textPrimary)
                    .lineLimit(1)

                Text("Reverse pyramid · \(setCountSummary)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            setProgressChip

            Menu {
                Button(role: .destructive) {
                    showingDeleteExercise = true
                } label: {
                    Label("Delete Exercise", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Options for \(exercise.displayName)")

            expandChevron
        }
    }

    @ViewBuilder
    private var setProgressChip: some View {
        if let index = workingSets.firstIndex(where: { !$0.isCompletedLoggedSet }) {
            chip("SET \(index + 1) OF \(workingSets.count)", tint: Theme.primary, background: Theme.primaryTint)
        } else if !workingSets.isEmpty {
            chip("DONE", tint: Theme.doneForeground, background: Theme.done.opacity(0.12))
        }
    }

    private func chip(_ text: String, tint: Color, background: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background, in: RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous))
            .fixedSize()
    }

    private func coachingBanner(_ note: AttributedString) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.dropTwoForeground)
                .padding(.top, 1)

            Text(note)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Theme.amberTint, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
    }

    private var columnHeader: some View {
        HStack(spacing: 8) {
            columnLabel("SET")
                .frame(width: SetColumn.badge, alignment: .leading)
            columnLabel("DROP")
                .frame(maxWidth: .infinity, alignment: .leading)
            columnLabel("WEIGHT")
                .frame(width: SetColumn.weight, alignment: .trailing)
            columnLabel("REPS")
                .frame(width: SetColumn.reps, alignment: .trailing)
            columnLabel("DONE")
                .frame(width: SetColumn.done, alignment: .center)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .accessibilityHidden(true)
    }

    private func columnLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .kerning(0.4)
            .foregroundStyle(Theme.textSecondary)
    }

    private var footerRow: some View {
        HStack(spacing: 16) {
            Button {
                if viewModel.addSetToExerciseSafely(exercise) {
                    SoundManager.shared.playAddSet()
                }
            } label: {
                Label("Add set", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .contentShape(Rectangle())

            Spacer()

            Button {
                showingWarmupPlan = true
            } label: {
                Text("Warm-up plan")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .contentShape(Rectangle())

            Button {
                showingPlateCalculator = true
            } label: {
                Text("Plates")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
        }
    }

    // MARK: - Collapsed Rows

    private var completedRow: some View {
        HStack(spacing: 10) {
            completionToggle

            VStack(alignment: .leading, spacing: 1) {
                Text(exercise.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)

                Text(loggedSummary ?? setCountSummary)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            expandChevron
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var upNextRow: some View {
        HStack(spacing: 10) {
            completionToggle

            VStack(alignment: .leading, spacing: 1) {
                Text(exercise.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Text("\(setCountSummary) · \(isActive ? "in progress" : "up next")")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            expandChevron
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Shared Controls

    private var completionToggle: some View {
        Button {
            let wasCompleted = isCompleted
            viewModel.toggleExerciseCompletion(exercise)
            HapticFeedbackManager.shared.light()
            // Checking off an exercise folds it into its summary row.
            if !wasCompleted, isExpanded {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toggleExerciseExpansion(exercise)
                }
            }
        } label: {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(isCompleted ? Theme.doneForeground : Theme.textTertiary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCompleted ? "Mark \(exercise.displayName) incomplete" : "Mark \(exercise.displayName) complete")
    }

    private var expandChevron: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.toggleExerciseExpansion(exercise)
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textSecondary)
                .rotationEffect(.degrees(isExpanded ? 0 : -90))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse \(exercise.displayName)" : "Expand \(exercise.displayName)")
    }

    // MARK: - Summaries & Ladder Math

    private var setCountSummary: String {
        let working = workingSets.count
        let warmups = orderedSets.count - working
        var parts: [String] = [working == 1 ? "1 working set" : "\(working) working sets"]
        if warmups > 0 {
            parts.append(warmups == 1 ? "1 warm-up" : "\(warmups) warm-ups")
        }
        return parts.joined(separator: " · ")
    }

    /// "185 → 165 → 155 · 5+7+8 reps" from this exercise's logged working sets.
    private var loggedSummary: String? {
        let logged = workingSets.filter(\.isCompletedLoggedSet)
        guard !logged.isEmpty else { return nil }

        let weights = logged
            .map { set in
                set.weight == 0 && set.exercise?.category == .bodyweight ? "BW" : "\(max(0, set.weight))"
            }
            .joined(separator: " → ")
        let reps = logged.map { "\(max(0, $0.reps))" }.joined(separator: "+")
        return "\(weights) · \(reps) reps"
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

    /// Badge color and drop-column text computed from this set's position in
    /// the ladder and its weight relative to the top set.
    private func ladderInfo(for set: ExerciseSet) -> SetLadderInfo {
        if set.isWarmup {
            return SetLadderInfo(
                badgeColor: Theme.surfaceMuted,
                badgeTextColor: Theme.textSecondary,
                dropText: "Warm-up",
                dropColor: Theme.textSecondary
            )
        }

        let index = workingSets.firstIndex(where: { $0.id == set.id }) ?? 0
        let color: Color
        let foregroundColor: Color
        switch index {
        case 0:
            color = Theme.topSet
            foregroundColor = Theme.topSetForeground
        case 1:
            color = Theme.dropOne
            foregroundColor = Theme.dropOneForeground
        default:
            color = Theme.dropTwo
            foregroundColor = Theme.dropTwoForeground
        }

        if index == 0 {
            return SetLadderInfo(badgeColor: color, badgeTextColor: .white, dropText: "Top set", dropColor: foregroundColor)
        }

        var text = "Back-off"
        if let top = topWorkingSet, top.weight > 0, set.weight > 0, set.weight <= top.weight {
            let percent = Int(((1 - Double(set.weight) / Double(top.weight)) * 100).rounded())
            text = percent > 0 ? "−\(percent)% · \(set.weight) lb" : "Same load"
        }
        return SetLadderInfo(
            badgeColor: color,
            badgeTextColor: Theme.inverted,
            dropText: text,
            dropColor: foregroundColor
        )
    }

    // MARK: - Set Mutations

    private func applyEditedValues(to set: ExerciseSet, weight: Int, reps: Int) {
        guard viewModel.updateSetSafely(set, weight: weight, reps: reps, rpe: set.rpe) else { return }
        propagateTopSetChangeIfNeeded(for: set, newWeight: weight)

        // Saving values from a log tap completes the check-off. Value edits
        // never log implicitly, so finish the intent with an explicit toggle.
        if editorOpenedForLogging,
           !set.isCompletedLoggedSet,
           viewModel.toggleSetLoggedSafely(set) == .logged {
            HapticFeedbackManager.shared.medium()
            if viewModel.autoStartRestTimerEnabled {
                viewModel.startRestTimer()
            }
        }
        editorOpenedForLogging = false
    }

    /// Editing the top working set recalculates all back-off set suggestions.
    private func propagateTopSetChangeIfNeeded(for set: ExerciseSet, newWeight: Int) {
        guard !set.isWarmup, newWeight > 0, set.id == topWorkingSet?.id else { return }
        _ = viewModel.updateDropSetSuggestionsSafely(for: exercise, firstSetWeight: newWeight)
    }

    private func handleLogTap(for set: ExerciseSet) {
        switch viewModel.toggleSetLoggedSafely(set) {
        case .logged:
            HapticFeedbackManager.shared.medium()
            if viewModel.autoStartRestTimerEnabled {
                viewModel.startRestTimer()
            }
        case .unlogged:
            HapticFeedbackManager.shared.light()
        case .needsValues:
            // Nothing to log yet — open the editor so the user can enter values.
            editorOpenedForLogging = true
            editingSet = set
        case .failed:
            break // The view model surfaces the error alert.
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

    private var attributedProgressionNote: AttributedString? {
        guard let progressionNote else { return nil }

        var attributed = AttributedString(progressionNote)
        if let target = progressionTargetWeight, target > 0,
           let range = attributed.range(of: "\(target) lb") {
            attributed[range].inlinePresentationIntent = .stronglyEmphasized
        }
        return attributed
    }

    private func loadProgressionNote() {
        guard !viewModel.workout.isCompleted else { return }

        let history = WorkoutManager.shared.getWorkoutHistory(for: exercise)
        let lastCompleted = history.first { workout, sets in
            workout.isCompleted && workout.id != viewModel.workout.id && sets.contains(where: \.isCompletedWorkingSet)
        }

        guard let lastTopSet = lastCompleted?.sets.first(where: \.isCompletedWorkingSet), lastTopSet.weight > 0 else {
            progressionNote = nil
            progressionTargetWeight = nil
            return
        }

        let suggestion = ProgressionAdvisor.suggestion(
            lastWeight: lastTopSet.weight,
            lastReps: lastTopSet.reps
        )
        progressionNote = "Last top set \(lastTopSet.weight)×\(lastTopSet.reps). \(suggestion.note)"
        progressionTargetWeight = suggestion.suggestedWeight
    }
}

// MARK: - Ladder Info

struct SetLadderInfo {
    let badgeColor: Color
    let badgeTextColor: Color
    let dropText: String
    let dropColor: Color
}

// MARK: - Set Table Row

struct SetTableRow: View {
    let set: ExerciseSet
    let setLabel: String
    let ladder: SetLadderInfo
    /// This is the next set to perform: tinted row, blue Log pill.
    let isNextUp: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onLogTapped: () -> Void
    let onSetRPE: (Int?) -> Void

    private var isLogged: Bool {
        // `self.` is required: a leading bare `set` parses as a setter keyword.
        self.set.isCompletedLoggedSet
    }

    private var showRPE: Bool {
        SettingsManager.shared.settings.showRPE && !set.isWarmup
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onEdit) {
                Text(setLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ladder.badgeTextColor)
                    .frame(width: 26, height: 26)
                    .background(ladder.badgeColor, in: RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .accessibilityLabel(set.isWarmup ? "Edit warm-up set" : "Edit set \(setLabel)")
            .frame(width: SetColumn.badge, alignment: .leading)

            Text(dropLine)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ladder.dropColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onEdit) {
                Text(weightText)
                    .font(Theme.titleFont(size: 16))
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: SetColumn.weight, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isWarmup ? "Edit warm-up weight" : "Edit set \(setLabel) weight")
            .accessibilityValue(weightText)
            .frame(minHeight: 44)

            Button(action: onEdit) {
                Text(repsText)
                    .font(Theme.titleFont(size: 16))
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .frame(width: SetColumn.reps, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isWarmup ? "Edit warm-up reps" : "Edit set \(setLabel) reps")
            .accessibilityValue(repsText)
            .frame(minHeight: 44)

            doneControl
                .frame(width: SetColumn.done, alignment: .center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isNextUp ? Theme.primaryTint : Color.clear)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit Values", systemImage: "pencil")
            }
            if showRPE {
                Menu {
                    ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                        Button("RPE \(value)") { onSetRPE(value) }
                    }
                    if set.displayRPE != nil {
                        Button("Clear RPE", role: .destructive) { onSetRPE(nil) }
                    }
                } label: {
                    Label(set.displayRPE.map { "RPE \($0)" } ?? "Set RPE", systemImage: "gauge")
                }
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete Set", systemImage: "trash")
            }
        }
    }

    /// The log control: green check when logged, blue Log pill on the next
    /// set, dashed circle for later sets — one button, restyled per state.
    private var doneControl: some View {
        Button(action: onLogTapped) {
            Group {
                if isLogged {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.doneForeground)
                } else if isNextUp {
                    Text("Log")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.primaryAction, in: RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous))
                } else {
                    Circle()
                        .strokeBorder(Theme.textTertiary, style: StrokeStyle(lineWidth: 1.8, dash: [3, 3.5]))
                        .frame(width: 22, height: 22)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLogged ? "Unlog set" : "Log set")
    }

    private var dropLine: String {
        if showRPE, let rpe = set.displayRPE {
            return "\(ladder.dropText) · RPE \(rpe)"
        }
        return ladder.dropText
    }

    private var valueColor: Color {
        if isLogged {
            return Theme.textPrimary
        }
        return isNextUp ? Theme.primary : Theme.textTertiary
    }

    private var weightText: String {
        if set.weight == 0, set.exercise?.category == .bodyweight {
            return "BW"
        }
        return set.weight > 0 ? "\(set.weight)" : "—"
    }

    private var repsText: String {
        // `self.` is required: a leading bare `set` parses as a setter keyword.
        self.set.reps > 0 ? "\(set.reps)" : "—"
    }
}

/// Fixed column widths shared by the set table's header and rows.
enum SetColumn {
    static let badge: CGFloat = 44
    static let weight: CGFloat = 64
    static let reps: CGFloat = 44
    static let done: CGFloat = 52
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
                            .background(Theme.surfaceMuted, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
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
                            .background(Theme.surfaceMuted, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
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

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
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
