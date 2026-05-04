//
//  ExerciseSelectorForTemplateView.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData

struct ExerciseSelectorForTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ExerciseLibraryViewModel()
    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var selectedMuscleGroup: MuscleGroup?

    var excludedExerciseNames: [String] = []
    var onSelectExercise: (String) -> Void

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

                List {
                    let fetchedExercises = viewModel.fetchExercises()
                    let filteredExercises = fetchedExercises.filter { exercise in
                        !excludedLookupKeys.contains(ExerciseManager.normalizedNameLookupKey(exercise.name))
                    }

                    let excludedCount = max(0, fetchedExercises.count - filteredExercises.count)

                    if let summary = viewModel.selectableResultsSummary(
                        availableCount: filteredExercises.count,
                        excludedCount: excludedCount,
                        exclusionContext: "template"
                    ) {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .listRowSeparator(.hidden)
                    }

                    if filteredExercises.isEmpty {
                        ContentUnavailableView {
                            Label(
                                emptyStateTitle(for: fetchedExercises, excludedCount: excludedCount),
                                systemImage: viewModel.hasActiveQuery ? "magnifyingglass" : "dumbbell"
                            )
                        } description: {
                            Text(emptyStateDescription(for: fetchedExercises, excludedCount: excludedCount))
                        } actions: {
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
                        ForEach(filteredExercises) { exercise in
                            Button(action: {
                                HapticFeedbackManager.shared.medium()
                                onSelectExercise(exercise.displayName)
                                dismiss()
                            }) {
                                HStack(spacing: 12) {
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

                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.blue)
                                        .imageScale(.large)
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.refreshExercises()
            }
        }
    }

    private func emptyStateTitle(for fetchedExercises: [Exercise], excludedCount: Int) -> String {
        if !fetchedExercises.isEmpty, excludedCount == fetchedExercises.count {
            return viewModel.hasActiveQuery
                ? "All Matching Exercises Already Added"
                : "All Exercises Already Added"
        }

        return viewModel.hasActiveQuery ? "No Matching Exercises" : "No Exercises Available"
    }

    private func emptyStateDescription(for fetchedExercises: [Exercise], excludedCount: Int) -> String {
        if !fetchedExercises.isEmpty, excludedCount == fetchedExercises.count {
            return viewModel.hasActiveQuery
                ? "This template already includes every exercise in your current search or filter results. Clear your filters or remove one from the template to add it again."
                : "This template already includes every exercise in your library. Remove one from the template or add a new custom exercise to keep building it out."
        }

        return viewModel.hasActiveQuery
            ? "Try changing your search or filters, or clear them to browse every exercise."
            : "Add an exercise in the library first, then come back here to use it in a template."
    }
}
