//
//  ActiveWorkoutView.swift
//  RPT
//
//  The live training screen: exercise sections with RPT set suggestions,
//  rest timer, and finish/save/discard lifecycle.
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
            ScrollView {
                VStack(spacing: Theme.sectionSpacing) {
                    headerCard

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
                .padding(.bottom, 100)
            }
            .background(Theme.screenBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Save for Later") {
                        if viewModel.saveWorkoutForLaterSafely() {
                            session.dismissKeepingDraft()
                        }
                    }
                    .font(.subheadline)
                }

                ToolbarItem(placement: .topBarTrailing) {
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
                    }
                    .accessibilityLabel("Workout options")
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
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
            .sheet(isPresented: $viewModel.showingRestTimer) {
                RestTimerView(duration: viewModel.currentRestDuration)
                    .presentationDetents([.medium])
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

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if isEditingName {
                    TextField("Workout name", text: $viewModel.workoutName)
                        .font(.title3.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .submitLabel(.done)
                        .onSubmit { commitNameEdit() }

                    Button("Done") { commitNameEdit() }
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text(viewModel.workoutName)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)

                    Button {
                        isEditingName = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Rename workout")

                    Spacer()

                    Text(viewModel.workout.date, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !viewModel.exerciseOrder.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(viewModel.completedExercisesCount) of \(viewModel.totalExercisesCount) exercises done")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(viewModel.workout.hasPreferredWorkMetric ? viewModel.workout.preferredWorkMetricValue : "")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))

                            Capsule()
                                .fill(Theme.brandGradient)
                                .frame(width: proxy.size.width * progressFraction)
                                .animation(.easeOut(duration: 0.3), value: progressFraction)
                        }
                    }
                    .frame(height: 8)
                    .accessibilityHidden(true)
                }
            }
        }
        .rptCard()
    }

    private var progressFraction: Double {
        guard viewModel.totalExercisesCount > 0 else { return 0 }
        return Double(viewModel.completedExercisesCount) / Double(viewModel.totalExercisesCount)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.startRestTimer()
            } label: {
                Label("Rest", systemImage: "timer")
            }
            .buttonStyle(SecondaryCapsuleButtonStyle())

            Button {
                requestFinish()
            } label: {
                Label("Finish", systemImage: "checkmark")
            }
            .buttonStyle(BrandButtonStyle())
            .disabled(!viewModel.hasSets)
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.vertical, 10)
        .background(.bar)
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
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
