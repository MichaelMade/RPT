//
//  ExerciseSelectorView.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData

struct ExerciseSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ExerciseLibraryViewModel()
    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var selectedMuscleGroup: MuscleGroup?
    @State private var showingAddExercise = false
    @State private var createExercisePrefillName = ""
    @State private var pendingSelectionExerciseName: String?

    var excludedExerciseNames: [String] = []
    var onSelectExercise: (Exercise) -> Void

    private let exerciseManager = ExerciseManager.shared

    private var excludedLookupKeys: Set<String> {
        Set(excludedExerciseNames.map(ExerciseManager.normalizedNameLookupKey))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                
                // Exercise list
                List {
                    let fetchedExercises = viewModel.fetchExercises()
                    let filteredExercises = fetchedExercises.filter { exercise in
                        !excludedLookupKeys.contains(ExerciseManager.normalizedNameLookupKey(exercise.name))
                    }
                    let excludedCount = max(0, fetchedExercises.count - filteredExercises.count)

                    if let summary = viewModel.selectableResultsSummary(
                        availableCount: filteredExercises.count,
                        excludedCount: excludedCount,
                        exclusionContext: "workout"
                    ) {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .listRowSeparator(.hidden)
                    }
                    
                    if filteredExercises.isEmpty {
                        let createRecoveryTitle = viewModel.createExerciseRecoveryTitle(filteredCount: filteredExercises.count)

                        ContentUnavailableView {
                            Label(
                                viewModel.selectionEmptyStateTitle(
                                    totalFetchedCount: fetchedExercises.count,
                                    excludedCount: excludedCount
                                ),
                                systemImage: viewModel.hasActiveQuery && !viewModel.exercises.isEmpty ? "magnifyingglass" : "dumbbell"
                            )
                        } description: {
                            Text(
                                viewModel.selectionEmptyStateDescription(
                                    totalFetchedCount: fetchedExercises.count,
                                    excludedCount: excludedCount,
                                    context: .workout
                                )
                            )
                        } actions: {
                            if let createRecoveryTitle {
                                Button(createRecoveryTitle) {
                                    createExercisePrefillName = viewModel.preferredNewExercisePrefillName()
                                    showingAddExercise = true
                                }
                            } else if viewModel.shouldShowGenericCreateExerciseAction(filteredCount: filteredExercises.count)
                                || fetchedExercises.isEmpty
                                || excludedCount == fetchedExercises.count {
                                Button("Add Custom Exercise") {
                                    createExercisePrefillName = viewModel.preferredNewExercisePrefillName()
                                    showingAddExercise = true
                                }
                            }

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
                    } else {
                        let matchedExercise = filteredExercises.count == 1 ? filteredExercises[0] : nil

                        ForEach(filteredExercises) { exercise in
                            // Make the entire row tappable
                            Button(action: {
                                // Provide haptic feedback
                                HapticFeedbackManager.shared.medium()
                                
                                // Select the exercise and dismiss
                                onSelectExercise(exercise)
                                dismiss()
                            }) {
                                // Exercise row content
                                HStack(spacing: 12) {
                                    // Exercise icon
                                    ExerciseIconView(category: exercise.category, size: 36)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.displayName)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text(exercise.primaryMuscleGroupSummary)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Add a selection indicator
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.blue)
                                        .imageScale(.large)
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle()) // Ensures the entire row is tappable
                            }
                            .buttonStyle(PlainButtonStyle()) // Remove default button styling
                        }

                        if let matchedExercise,
                           let actionTitle = viewModel.singleSelectableExerciseActionTitle(for: matchedExercise) {
                            Button(actionTitle) {
                                HapticFeedbackManager.shared.medium()
                                onSelectExercise(matchedExercise)
                                dismiss()
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                        }

                        if viewModel.shouldShowCreateExerciseFromSearchAction(filteredCount: filteredExercises.count),
                           let createRecoveryTitle = viewModel.createExerciseRecoveryTitle(filteredCount: filteredExercises.count) {
                            Button(createRecoveryTitle) {
                                createExercisePrefillName = viewModel.preferredNewExercisePrefillName()
                                showingAddExercise = true
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                        }

                        if viewModel.shouldShowResultsRecoveryActions(filteredCount: filteredExercises.count) {
                            if viewModel.hasActiveSearch {
                                Button("Clear Search") {
                                    searchText = ""
                                    viewModel.clearSearch()
                                }
                                .font(.caption)
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                            }

                            if viewModel.hasActiveFilters {
                                Button("Reset Filters") {
                                    selectedCategory = nil
                                    selectedMuscleGroup = nil
                                    viewModel.clearFilters()
                                }
                                .font(.caption)
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .onChange(of: searchText) { _, newValue in
                viewModel.searchText = newValue
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        createExercisePrefillName = viewModel.preferredNewExercisePrefillName()
                        showingAddExercise = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Custom Exercise")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise, onDismiss: handleAddExerciseDismissed) {
                AddExerciseView(
                    initialExerciseName: createExercisePrefillName,
                    initialCategory: viewModel.preferredNewExerciseCategory(),
                    initialPrimaryMuscles: viewModel.preferredNewExercisePrimaryMuscles()
                ) { savedExerciseName in
                    pendingSelectionExerciseName = savedExerciseName
                }
            }
            .onAppear {
                viewModel.includeSelectionActionSearchAliases = true
                viewModel.refreshExercises()
            }
        }
    }

    private func handleAddExerciseDismissed() {
        viewModel.refreshExercises()

        guard let pendingSelectionExerciseName else {
            return
        }

        self.pendingSelectionExerciseName = nil

        guard let exercise = exerciseManager.fetchExercise(withName: pendingSelectionExerciseName) else {
            return
        }

        HapticFeedbackManager.shared.medium()
        onSelectExercise(exercise)
        dismiss()
    }
}

#Preview {
    ExerciseSelectorView { _ in
        // This is a preview so we don't need to handle the selection
    }
    .modelContainer(for: [Exercise.self])
}
