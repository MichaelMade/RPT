//
//  ActiveWorkoutView.swift
//  RPT
//
//  The live training screen: exercise cards with RPT set tables,
//  a docked rest timer, and finish/save/discard lifecycle.
//

import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject private var session: WorkoutSession
    @StateObject private var viewModel: ActiveWorkoutViewModel

    @State private var showingExercisePicker = false
    @State private var showingFinishDialog = false
    @State private var showingDiscardConfirmation = false
    @State private var showingNotesEditor = false
    @State private var isEditingName = false

    init(workout: Workout) {
        _viewModel = StateObject(wrappedValue: ActiveWorkoutViewModel(workout: workout))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: Theme.sectionSpacing) {
                        if viewModel.exerciseOrder.isEmpty {
                            EmptyStateCard(
                                icon: "dumbbell",
                                title: "No Exercises Yet",
                                message: "Add your first movement to start logging sets.",
                                actionTitle: "Add Exercise"
                            ) {
                                showingExercisePicker = true
                            }
                        } else {
                            ForEach(viewModel.exerciseOrder) { exercise in
                                ExerciseSectionView(viewModel: viewModel, exercise: exercise)
                            }

                            Button {
                                showingExercisePicker = true
                            } label: {
                                Label("Add Exercise", systemImage: "plus")
                            }
                            .buttonStyle(SecondaryCapsuleButtonStyle(fullWidth: true))
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.top, Theme.sectionSpacing)
                    .padding(.bottom, 24)
                }
                .background(Theme.screenBackground)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                bottomDock
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(
                    excludedExerciseIDs: Set(viewModel.exerciseOrder.map(\.id)),
                    title: "Add to Workout"
                ) { exercise in
                    if viewModel.addExerciseToWorkoutSafely(exercise) {
                        HapticFeedbackManager.shared.light()
                    }
                }
            }
            .sheet(isPresented: $showingNotesEditor) {
                WorkoutNotesEditorSheet(initialNotes: viewModel.workout.notes) { notes in
                    _ = viewModel.updateNotesSafely(notes)
                }
                .presentationDetents([.medium])
            }
            .confirmationDialog(
                "Finish Workout?",
                isPresented: $showingFinishDialog,
                titleVisibility: .visible
            ) {
                if viewModel.workout.sets.contains(where: \.isCompletedLoggedSet) {
                    Button("Complete & Save") {
                        completeWorkout()
                    }
                }
                Button("Keep Training", role: .cancel) {}
            } message: {
                Text(finishDialogMessage)
            }
            .confirmationDialog(
                "Discard This Workout?",
                isPresented: $showingDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard Workout", role: .destructive) {
                    if viewModel.discardAndMarkDiscardedSafely() {
                        session.finishSession()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(discardMessage)
            }
            .alert(viewModel.errorAlertTitle, isPresented: errorBinding) {
                Button("OK", role: .cancel) { viewModel.clearError() }
            } message: {
                Text(viewModel.errorMessage ?? "Please try again.")
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if isEditingName {
                    TextField("Workout name", text: $viewModel.workoutName)
                        .font(Theme.titleFont(size: 18))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.surfaceMuted, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
                        .submitLabel(.done)
                        .onSubmit { commitNameEdit() }

                    Button("Done") { commitNameEdit() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(viewModel.workoutName)
                                .font(Theme.titleFont(size: 18))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)

                            Button {
                                isEditingName = true
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .accessibilityLabel("Rename workout")
                        }

                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(headerSubline(now: context.date))
                                .font(.system(size: 12))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    Spacer(minLength: 8)

                    Button {
                        if viewModel.saveWorkoutForLaterSafely() {
                            session.dismissKeepingDraft()
                        }
                    } label: {
                        Text("Save for later")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
                                    .strokeBorder(Theme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Save for Later")

                    Menu {
                        Button {
                            viewModel.startRestTimer()
                        } label: {
                            Label("Rest Timer", systemImage: "timer")
                        }

                        Button {
                            showingNotesEditor = true
                        } label: {
                            Label("Workout Notes", systemImage: "note.text")
                        }

                        Button(role: .destructive) {
                            showingDiscardConfirmation = true
                        } label: {
                            Label("Discard Workout", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 28, height: 32)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Workout options")
                }
            }

            if !viewModel.exerciseOrder.isEmpty {
                exerciseProgressBar
            }
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Theme.cardBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
    }

    /// One 4pt segment per exercise: done → green, active → blue, upcoming → muted.
    private var exerciseProgressBar: some View {
        HStack(spacing: 4) {
            ForEach(viewModel.exerciseOrder) { exercise in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(segmentColor(for: exercise))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: viewModel.completedExercisesCount)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(viewModel.completedExercisesCount) of \(viewModel.totalExercisesCount) exercises done")
    }

    private func segmentColor(for exercise: Exercise) -> Color {
        if viewModel.isExerciseCompleted(exercise) {
            return Theme.done
        }
        if isActiveExercise(exercise) {
            return Theme.primary
        }
        return Theme.surfaceMuted
    }

    private func isActiveExercise(_ exercise: Exercise) -> Bool {
        viewModel.exerciseOrder.first(where: { !viewModel.isExerciseCompleted($0) })?.id == exercise.id
    }

    private func headerSubline(now: Date) -> String {
        // A draft resumed days later would show a nonsense day-scale elapsed
        // time; past a plausible session length, show only the logged work.
        let seconds = max(0, Int(now.timeIntervalSince(viewModel.workout.date)))
        if seconds >= 12 * 60 * 60 {
            if viewModel.workout.hasPreferredWorkMetric {
                return "\(viewModel.workout.preferredWorkMetricValue) logged"
            }
            return "In progress"
        }

        let elapsed = elapsedString(now: now)
        if viewModel.workout.hasPreferredWorkMetric {
            return "\(elapsed) · \(viewModel.workout.preferredWorkMetricValue) logged"
        }
        return "\(elapsed) elapsed"
    }

    private func elapsedString(now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(viewModel.workout.date)))
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
        }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Bottom Dock

    private var bottomDock: some View {
        VStack(spacing: 10) {
            if viewModel.showingRestTimer {
                RestTimerView(duration: viewModel.currentRestDuration) {
                    viewModel.cancelRestTimer()
                }
                // Fresh identity per start: logging the next set mid-rest
                // must restart the countdown, not keep the stale one.
                .id(viewModel.restTimerStartedAt)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Button {
                requestFinish()
            } label: {
                Label("Finish workout", systemImage: "checkmark")
            }
            .buttonStyle(BrandButtonStyle())
            .accessibilityIdentifier("Finish")
            .disabled(!viewModel.hasSets)
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.cardBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showingRestTimer)
    }

    // MARK: - Actions

    private func commitNameEdit() {
        isEditingName = false
        _ = viewModel.updateWorkoutNameSafely()
    }

    private func requestFinish() {
        showingFinishDialog = true
    }

    private var finishDialogMessage: String {
        if !viewModel.workout.sets.contains(where: \.isCompletedLoggedSet) {
            return "No sets are logged yet, so this session can’t be completed. Log a set first, or save it for later or discard it."
        }

        if viewModel.allExercisesCompleted {
            return "Nice work — everything is checked off. Save this session to your history?"
        }

        let remaining = viewModel.remainingExercises.map(\.displayName)
        if remaining.isEmpty {
            return "Save this session to your history?"
        }

        let preview = remaining.prefix(2).joined(separator: ", ")
        let suffix = remaining.count > 2 ? " and \(remaining.count - 2) more" : ""
        return "Still unchecked: \(preview)\(suffix). You can finish anyway — only logged sets count toward your stats."
    }

    private var discardMessage: String {
        let exercises = viewModel.workout.exerciseCount
        let sets = viewModel.workout.sets.count

        guard exercises > 0 || sets > 0 else {
            return "This empty draft will be removed. This cannot be undone."
        }

        let exercisePart = exercises == 1 ? "1 exercise" : "\(exercises) exercises"
        let setPart = sets == 1 ? "1 set" : "\(sets) sets"
        return "This removes \(exercisePart) and \(setPart). This cannot be undone."
    }

    private func completeWorkout() {
        if viewModel.completeAndMarkSavedSafely() {
            HapticFeedbackManager.shared.success()
            SoundManager.shared.playWorkoutComplete()
            session.finishSession()
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )
    }
}

// MARK: - Notes Editor

struct WorkoutNotesEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialNotes: String
    let onSave: (String) -> Void

    @State private var notes: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField(
                    "How did the session feel? Sleep, energy, tweaks…",
                    text: $notes,
                    axis: .vertical
                )
                .lineLimit(4...10)
                .padding(12)
                .background(Theme.surfaceMuted, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
                .focused($isFocused)

                Spacer()
            }
            .padding(Theme.screenPadding)
            .background(Theme.screenBackground)
            .navigationTitle("Workout Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(notes)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                notes = initialNotes
                isFocused = true
            }
        }
    }
}
