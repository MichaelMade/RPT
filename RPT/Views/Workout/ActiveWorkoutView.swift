//
//  ActiveWorkoutView.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
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
                                if let sets = viewModel.exerciseGroups[exercise] {
                                    // Sort sets by completion date to maintain set order
                                    let sortedSets = sets.sorted(by: { $0.completedAt < $1.completedAt })
                                    
                                    // Use the new ExerciseSectionView component
                                    ExerciseSectionView(
                                        viewModel: viewModel,
                                        exercise: exercise,
                                        sets: sortedSets
                                    )
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    } else {
                        // Use the new EmptyWorkoutView component
                        EmptyWorkoutView(onAddExercise: {
                            showingExerciseSelector = true
                        })
                    }
                    
                    // Bottom action bar - only show when we have exercises
                    if !viewModel.exerciseGroups.isEmpty {
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
                                Text("Finish")
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(viewModel.allExercisesCompleted ? Color.green : Color.gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .disabled(!viewModel.allExercisesCompleted)
                        }
                        .padding()
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
            .navigationTitle(viewModel.workoutName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Minimize button to temporarily hide the workout
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // Save the workout without marking it as discarded
                        let saved = viewModel.saveWorkoutSafely()
                        
                        // Explicitly ensure WorkoutStateManager knows this was saved (not discarded)
                        let workoutStateManager = WorkoutStateManager.shared
                        workoutStateManager.markWorkoutAsSaved(viewModel.workout.id)
                        
                        // Just dismiss the sheet
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("Minimize")
                        }
                    }
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
                            Label("Exit Workout", systemImage: "xmark.circle")
                        }
                        
                        if viewModel.hasSets {
                            Button(role: .destructive) {
                                showingConfirmationDialog = true
                            } label: {
                                Label("Discard Workout", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingExerciseSelector) {
                ExerciseSelectorView { selectedExercise in
                    _ = viewModel.addExerciseToWorkoutSafely(selectedExercise)
                }
            }
            // Exit confirmation
            .confirmationDialog(
                "Exit Workout",
                isPresented: $showingExitConfirmation
            ) {
                Button("Save & Exit", role: .none) {
                    _ = viewModel.saveWorkoutSafely()
                    
                    // Explicitly mark as saved, not discarded
                    let workoutStateManager = WorkoutStateManager.shared
                    workoutStateManager.markWorkoutAsSaved(viewModel.workout.id)
                    
                    // Call completion callback if provided
                    if let callback = onCompleteWorkout {
                        callback()
                    }
                    
                    dismiss()
                }
                
                Button("Discard Workout", role: .destructive) {
                    let result = viewModel.discardWorkoutSafely()
                    
                    let workoutStateManager = WorkoutStateManager.shared
                    workoutStateManager.markWorkoutAsDiscarded(viewModel.workout.id)
                    
                    // Call completion callback if provided
                    if let callback = onCompleteWorkout {
                        callback()
                    }
                    
                    dismiss()
                }
                
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Would you like to save or discard this workout?")
            }
            // Discard confirmation
            .confirmationDialog(
                "Discard Workout",
                isPresented: $showingConfirmationDialog
            ) {
                Button("Discard Workout", role: .destructive) {
                    let result = viewModel.discardWorkoutSafely()
                    
                    let workoutStateManager = WorkoutStateManager.shared
                    workoutStateManager.markWorkoutAsDiscarded(viewModel.workout.id)
                    
                    // Call completion callback if provided
                    if let callback = onCompleteWorkout {
                        callback()
                    }
                    
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to discard this workout? This action cannot be undone.")
            }
            // Complete confirmation
            .confirmationDialog(
                "Complete Workout",
                isPresented: $showingCompleteConfirmation
            ) {
                Button("Complete and Save") {
                    _ = viewModel.completeWorkoutSafely()
                    
                    // Call completion callback if provided
                    if let callback = onCompleteWorkout {
                        callback()
                    }
                    
                    dismiss()
                }
                Button("Continue Workout", role: .cancel) { }
            } message: {
                Text("Would you like to complete and save this workout?")
            }
            // Delete exercise confirmation
            .confirmationDialog(
                "Delete Exercise",
                isPresented: $viewModel.showingDeleteExerciseConfirmation,
                presenting: viewModel.exerciseToDelete
            ) { exercise in
                Button("Delete \(exercise.name)", role: .destructive) {
                    _ = viewModel.deleteExerciseFromWorkoutSafely(exercise)
                    viewModel.exerciseToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    viewModel.exerciseToDelete = nil
                }
            } message: { exercise in
                Text("Are you sure you want to remove \(exercise.name) from this workout? All sets for this exercise will be deleted.")
            }
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

