//
//  ActiveWorkoutView.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    static let toolbarSaveForLaterLabel = "Save for Later"

    static var emptyStateHelperMessage: String {
        "Add at least one exercise before you can finish this workout. \(toolbarSaveForLaterLabel) keeps it as a draft if you're not ready yet."
    }

    static func toolbarSaveForLaterLabel(for workoutName: String) -> String {
        let normalizedWorkout = Workout(name: workoutName)

        guard let displayName = WorkoutRow.specificDisplayName(for: normalizedWorkout) else {
            return toolbarSaveForLaterLabel
        }

        return "Save “\(displayName)” for Later"
    }

    static func emptyStateSaveForLaterLabel(for workoutName: String) -> String {
        toolbarSaveForLaterLabel(for: workoutName)
    }

    static func emptyStateHelperMessage(for workoutName: String) -> String {
        let normalizedWorkout = Workout(name: workoutName)

        guard let displayName = WorkoutRow.specificDisplayName(for: normalizedWorkout) else {
            return emptyStateHelperMessage
        }

        return "Add at least one exercise to “\(displayName)” before you can finish it. \(emptyStateSaveForLaterLabel(for: workoutName)) keeps it as a draft if you're not ready yet."
    }

    static func navigationTitle(for workoutName: String) -> String {
        WorkoutRow.displayName(forWorkoutName: workoutName)
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ActiveWorkoutViewModel
    @State private var showingExerciseSelector = false
    @State private var showingConfirmationDialog = false
    @State private var showingCompleteConfirmation = false
    @State private var showingExitConfirmation = false
    
    // Track whether to show custom back button
    var showCustomBackButton: Bool
    
    // Callback for when the workout is completed or discarded
    var onCompleteWorkout: (() -> Void)?
    
    init(workout: Workout, showCustomBackButton: Bool = false, onCompleteWorkout: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ActiveWorkoutViewModel(workout: workout))
        self.showCustomBackButton = showCustomBackButton
        self.onCompleteWorkout = onCompleteWorkout
    }

    private func presentDiscardConfirmationFromExitDialog() {
        showingExitConfirmation = false

        DispatchQueue.main.async {
            showingConfirmationDialog = true
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Add progress indicator at the top when there are exercises
                    if !viewModel.exerciseGroups.isEmpty {
                        WorkoutProgressView(
                            completedExercises: viewModel.completedExercisesCount,
                            totalExercises: viewModel.totalExercisesCount
                        )
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .background(Color(UIColor.systemBackground))
                    }
                    
                    // Exercise list
                    if !viewModel.exerciseGroups.isEmpty {
                        List {
                            // Use exerciseOrder to display exercises in their added order
                            ForEach(viewModel.exerciseOrder, id: \.self) { exercise in
                                if viewModel.exerciseGroups[exercise] != nil {
                                    // Use the new ExerciseSectionView component
                                    ExerciseSectionView(
                                        viewModel: viewModel,
                                        exercise: exercise,
                                        sets: viewModel.orderedSetsForDisplay(in: exercise)
                                    )
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    } else {
                        // Use the new EmptyWorkoutView component
                        EmptyWorkoutView(
                            helperMessage: Self.emptyStateHelperMessage(for: viewModel.workoutName),
                            onAddExercise: {
                                showingExerciseSelector = true
                            }
                        )
                    }
                    
                    // Bottom action bar - only show when we have exercises
                    if !viewModel.exerciseGroups.isEmpty {
                        VStack(spacing: 8) {
                            if let finishHelperText = viewModel.finishHelperText {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.badge.questionmark")
                                        .foregroundColor(.secondary)
                                        .padding(.top, 1)

                                    Text(finishHelperText)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)

                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal)
                            }

                            HStack {
                                Button(action: {
                                    showingExerciseSelector = true
                                }) {
                                    Label("Add Exercise", systemImage: "plus")
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }

                                Spacer()

                                // Manual rest timer button
                                Button(action: {
                                    viewModel.startRestTimer()
                                }) {
                                    Label("Timer", systemImage: "timer")
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .background(Color.orange)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }

                                Spacer()

                                Button(action: {
                                    showingCompleteConfirmation = true
                                }) {
                                    Text(viewModel.finishButtonTitle())
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .background(viewModel.allExercisesCompleted ? Color.green : Color.gray)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .disabled(!viewModel.allExercisesCompleted)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                        .background(Color(UIColor.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
                    }
                }
                
                // Rest timer overlay
                if viewModel.showingRestTimer {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .animation(.easeInOut, value: viewModel.showingRestTimer)
                    
                    RestTimerView(
                        defaultDuration: viewModel.currentRestDuration,
                        isShowing: $viewModel.showingRestTimer
                    )
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(), value: viewModel.showingRestTimer)
                }
            }
            .navigationTitle(Self.navigationTitle(for: viewModel.workoutName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Save the current workout as a draft and close the sheet.
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        guard viewModel.saveWorkoutForLaterSafely() else {
                            return
                        }

                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text(Self.toolbarSaveForLaterLabel(for: viewModel.workoutName))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .accessibilityLabel(viewModel.saveForLaterButtonTitle())
                }
                
                // Right side of navigation bar (menu)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        TextField("Workout Name", text: $viewModel.workoutName)
                            .onChange(of: viewModel.workoutName) { _, _ in
                                _ = viewModel.updateWorkoutNameSafely()
                            }
                        
                        Button(action: {
                            showingExitConfirmation = true
                        }) {
                            Label(viewModel.exitWorkoutMenuTitle(), systemImage: "xmark.circle")
                        }
                        
                        if viewModel.hasSets {
                            Button(role: .destructive) {
                                showingConfirmationDialog = true
                            } label: {
                                Label(viewModel.discardWorkoutMenuTitle(), systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingExerciseSelector) {
                ExerciseSelectorView(
                    excludedExerciseNames: viewModel.exerciseOrder.map(\.name)
                ) { selectedExercise in
                    _ = viewModel.addExerciseToWorkoutSafely(selectedExercise)
                }
            }
            // Exit confirmation
            .confirmationDialog(
                viewModel.exitWorkoutMenuTitle(),
                isPresented: $showingExitConfirmation
            ) {
                Button(viewModel.saveForLaterButtonTitle()) {
                    guard viewModel.saveWorkoutForLaterSafely() else {
                        return
                    }

                    onCompleteWorkout?()
                    dismiss()
                }

                if viewModel.canCompleteWorkoutFromExitDialog {
                    Button(viewModel.completeWorkoutButtonTitle()) {
                        guard viewModel.completeAndMarkSavedSafely() else {
                            return
                        }

                        onCompleteWorkout?()
                        dismiss()
                    }
                }

                Button(viewModel.discardWorkoutButtonTitle(), role: .destructive) {
                    presentDiscardConfirmationFromExitDialog()
                }

                Button("Cancel", role: .cancel) { }
            } message: {
                Text(viewModel.exitDialogHelperText)
            }
            // Discard confirmation
            .confirmationDialog(
                viewModel.discardWorkoutAlertTitle(),
                isPresented: $showingConfirmationDialog
            ) {
                Button(viewModel.discardWorkoutButtonTitle(), role: .destructive) {
                    guard viewModel.discardAndMarkDiscardedSafely() else {
                        return
                    }

                    if let callback = onCompleteWorkout {
                        callback()
                    }

                    dismiss()
                }
            } message: {
                Text(viewModel.discardWorkoutMessage())
            }
            // Complete confirmation
            .confirmationDialog(
                viewModel.completeWorkoutAlertTitle(),
                isPresented: $showingCompleteConfirmation
            ) {
                Button(viewModel.completeWorkoutButtonTitle()) {
                    guard viewModel.completeAndMarkSavedSafely() else {
                        return
                    }

                    if let callback = onCompleteWorkout {
                        callback()
                    }

                    dismiss()
                }
                Button(viewModel.continueWorkoutButtonTitle(), role: .cancel) { }
            } message: {
                Text(viewModel.completeWorkoutMessage())
            }
            // Delete exercise confirmation
            .confirmationDialog(
                viewModel.deleteExerciseAlertTitle(for: viewModel.exerciseToDelete),
                isPresented: $viewModel.showingDeleteExerciseConfirmation,
                presenting: viewModel.exerciseToDelete
            ) { exercise in
                Button(viewModel.deleteExerciseButtonTitle(for: exercise), role: .destructive) {
                    _ = viewModel.deleteExerciseFromWorkoutSafely(exercise)
                    viewModel.exerciseToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    viewModel.exerciseToDelete = nil
                }
            } message: { exercise in
                Text(viewModel.deleteExerciseMessage(for: exercise))
            }
        }
        .alert(
            viewModel.errorAlertTitle,
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.clearError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong. Please try again.")
        }
        .interactiveDismissDisabled() // Prevent swipe-to-dismiss
    }
    
    // updateDropSets method moved to ExerciseSectionView
}

#Preview {
    let modelContainer = try! ModelContainer(for: Workout.self, ExerciseSet.self, Exercise.self)
    
    // Create a workout
    let workout = Workout(date: Date(), name: "Preview Workout")
    
    ActiveWorkoutView(
        workout: workout,
        onCompleteWorkout: {}
    )
    .modelContainer(modelContainer)
}
