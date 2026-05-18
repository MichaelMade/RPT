//
//  ExercisesView.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData

struct ExercisesView: View {
    @StateObject private var viewModel = ExerciseLibraryViewModel()
    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var selectedMuscleGroup: MuscleGroup?
    @State private var showingAddExercise = false
    @State private var createExercisePrefillName = ""
    @State private var exerciseToEdit: Exercise?
    @State private var exerciseToDelete: Exercise?
    @State private var exerciseDeletionImpact = ExerciseManager.DeletionImpact(loggedSetCount: 0, workoutCount: 0, templateCount: 0)
    @State private var showingDeleteConfirmation = false
    @State private var deleteResult: ExerciseManager.DeletionResult?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryFilterButton(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            action: {
                                selectedCategory = nil
                                viewModel.selectedCategory = nil
                            }
                        )
                        
                        ForEach(ExerciseCategory.allCases, id: \.self) { category in
                            CategoryFilterButton(
                                title: category.rawValue.capitalized,
                                isSelected: selectedCategory == category,
                                action: {
                                    if selectedCategory == category {
                                        selectedCategory = nil
                                        viewModel.selectedCategory = nil
                                    } else {
                                        selectedCategory = category
                                        viewModel.selectedCategory = category
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                
                // Muscle group filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryFilterButton(
                            title: "All Muscles",
                            isSelected: selectedMuscleGroup == nil,
                            action: {
                                selectedMuscleGroup = nil
                                viewModel.selectedMuscleGroup = nil
                            }
                        )
                        
                        ForEach(MuscleGroup.allCases, id: \.self) { muscleGroup in
                            CategoryFilterButton(
                                title: muscleGroup.displayName,
                                isSelected: selectedMuscleGroup == muscleGroup,
                                action: {
                                    if selectedMuscleGroup == muscleGroup {
                                        selectedMuscleGroup = nil
                                        viewModel.selectedMuscleGroup = nil
                                    } else {
                                        selectedMuscleGroup = muscleGroup
                                        viewModel.selectedMuscleGroup = muscleGroup
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                
                // Exercise List
                List {
                    let exercises = viewModel.fetchExercises()
                    let emptyStateKind = viewModel.emptyStateKind(filteredCount: exercises.count)

                    if let summary = viewModel.filteredResultsSummary(filteredCount: exercises.count) {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .listRowSeparator(.hidden)
                    }
                    
                    if let emptyStateKind {
                        let createRecoveryTitle = viewModel.createExerciseRecoveryTitle(filteredCount: exercises.count)

                        ContentUnavailableView {
                            Label(
                                viewModel.emptyStateTitle(filteredCount: exercises.count) ?? "No Exercises Yet",
                                systemImage: emptyStateKind == .emptyLibrary ? "dumbbell" : "magnifyingglass"
                            )
                        } description: {
                            Text(viewModel.emptyStateDescription(filteredCount: exercises.count) ?? "")
                        } actions: {
                            if let createRecoveryTitle {
                                Button(createRecoveryTitle) {
                                    createExercisePrefillName = viewModel.preferredNewExercisePrefillName()
                                    showingAddExercise = true
                                }
                            } else if viewModel.shouldShowGenericCreateExerciseAction(filteredCount: exercises.count) {
                                Button("Add Custom Exercise") {
                                    createExercisePrefillName = viewModel.preferredNewExercisePrefillName()
                                    showingAddExercise = true
                                }
                            }

                            if emptyStateKind != .emptyLibrary {
                                if viewModel.hasActiveSearch {
                                    Button("Clear Search") {
                                        searchText = ""
                                        viewModel.clearSearch()
                                    }
                                }

                                if viewModel.hasActiveFilters {
                                    Button("Reset Filters") {
                                        selectedCategory = nil
                                        selectedMuscleGroup = nil
                                        viewModel.clearFilters()
                                    }
                                }
                            }
                        }
                    } else {
                        ForEach(exercises) { exercise in
                            NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                                ExerciseRowView(exercise: exercise)
                            }
                            .swipeActions(edge: .trailing) {
                                if exercise.isCustom {
                                    Button {
                                        exerciseToEdit = exercise
                                    } label: {
                                        Label(
                                            viewModel.editActionTitle(for: exercise) ?? "Edit",
                                            systemImage: "pencil"
                                        )
                                    }
                                    .tint(.blue)

                                    Button(role: .destructive) {
                                        exerciseToDelete = exercise
                                        exerciseDeletionImpact = viewModel.deletionImpact(for: exercise)
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label(
                                            viewModel.deleteActionTitle(for: exercise) ?? "Delete",
                                            systemImage: "trash"
                                        )
                                    }
                                }
                            }
                        }

                        if viewModel.shouldShowSingleResultQuickActions(filteredCount: exercises.count),
                           let matchedExercise = exercises.first {
                            Section("Quick Actions") {
                                NavigationLink {
                                    ExerciseDetailView(exercise: matchedExercise)
                                } label: {
                                    Label(
                                        viewModel.reviewActionTitle(for: matchedExercise) ?? "Review",
                                        systemImage: "info.circle"
                                    )
                                }

                                if matchedExercise.isCustom {
                                    Button(viewModel.editActionTitle(for: matchedExercise) ?? "Edit") {
                                        exerciseToEdit = matchedExercise
                                    }

                                    Button(role: .destructive) {
                                        exerciseToDelete = matchedExercise
                                        exerciseDeletionImpact = viewModel.deletionImpact(for: matchedExercise)
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label(
                                            viewModel.deleteActionTitle(for: matchedExercise) ?? "Delete",
                                            systemImage: "trash"
                                        )
                                    }
                                }
                            }
                        }

                        if viewModel.shouldShowCreateExerciseFromSearchAction(filteredCount: exercises.count),
                           let createRecoveryTitle = viewModel.createExerciseRecoveryTitle(filteredCount: exercises.count) {
                            Button(createRecoveryTitle) {
                                createExercisePrefillName = viewModel.preferredNewExercisePrefillName()
                                showingAddExercise = true
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                        }

                        if viewModel.shouldShowResultsRecoveryActions(filteredCount: exercises.count) {
                            HStack {
                                if viewModel.hasActiveSearch {
                                    Button("Clear Search") {
                                        searchText = ""
                                        viewModel.clearSearch()
                                    }
                                }

                                if viewModel.hasActiveSearch && viewModel.hasActiveFilters {
                                    Spacer(minLength: 12)
                                }

                                if viewModel.hasActiveFilters {
                                    Button("Reset Filters") {
                                        selectedCategory = nil
                                        selectedMuscleGroup = nil
                                        viewModel.clearFilters()
                                    }
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .onChange(of: searchText) { _, newValue in
                viewModel.searchText = newValue
            }
            .navigationTitle("Exercise Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        createExercisePrefillName = viewModel.preferredNewExercisePrefillName()
                        showingAddExercise = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise, onDismiss: {
                // Refresh the exercise list when the add sheet is dismissed
                viewModel.refreshExercises()
            }) {
                AddExerciseView(
                    initialExerciseName: createExercisePrefillName,
                    initialCategory: viewModel.preferredNewExerciseCategory(),
                    initialPrimaryMuscles: viewModel.preferredNewExercisePrimaryMuscles()
                )
            }
            .sheet(item: $exerciseToEdit, onDismiss: {
                viewModel.refreshExercises()
            }) { exercise in
                EditExerciseView(exercise: exercise)
            }
            .confirmationDialog(
                viewModel.deleteAlertTitle(for: exerciseToDelete),
                isPresented: $showingDeleteConfirmation,
                presenting: exerciseToDelete
            ) { exercise in
                Button(viewModel.deleteActionTitle(for: exercise) ?? "Delete", role: .destructive) {
                    let result = viewModel.deleteExercise(exercise)
                    if result != .success {
                        deleteResult = result
                    }
                }
            } message: { exercise in
                Text(ExerciseLibraryViewModel.deletionConfirmationMessage(for: exerciseDeletionImpact))
            }
            .alert(
                deleteResult?.alertTitle ?? "Unable to Delete Exercise",
                isPresented: Binding(
                    get: { deleteResult != nil },
                    set: { isPresented in
                        if !isPresented {
                            deleteResult = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    deleteResult = nil
                }
            } message: {
                Text(deleteResult?.alertMessage ?? "This exercise could not be deleted right now. Please try again.")
            }
            .onAppear {
                viewModel.refreshExercises()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExercisesView()
            .modelContainer(for: [Exercise.self])
    }
}
