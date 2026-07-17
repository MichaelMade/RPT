//
//  ExercisePickerView.swift
//  RPT
//
//  Shared exercise selector used when adding movements to a workout or
//  template. Tap a row to add it; create a custom exercise inline.
//

import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ExerciseLibraryViewModel()

    // Concrete PersistentIdentifier rather than the nested `Exercise.ID`
    // alias: resolution of the macro-generated alias has proven
    // order-sensitive across builds.
    var excludedExerciseIDs: Set<PersistentIdentifier> = []
    var title: String = "Add Exercise"
    let onSelect: (Exercise) -> Void

    @State private var showingCreateExercise = false

    private var selectableExercises: [Exercise] {
        viewModel.filteredExercises.filter { !excludedExerciseIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryFilterBar

                if selectableExercises.isEmpty {
                    ScrollView {
                        EmptyStateCard(
                            icon: "magnifyingglass",
                            title: "No Matches",
                            message: viewModel.hasActiveFilters
                                ? viewModel.noMatchesDescription()
                                : "Every exercise is already in this workout.",
                            actionTitle: "Create Custom Exercise"
                        ) {
                            showingCreateExercise = true
                        }
                        .padding(Theme.screenPadding)
                    }
                } else {
                    List(selectableExercises) { exercise in
                        Button {
                            onSelect(exercise)
                            dismiss()
                        } label: {
                            ExerciseListRow(exercise: exercise)
                        }
                        .listRowBackground(Theme.cardBackground)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.screenBackground)
            .searchable(text: $viewModel.searchText, prompt: ExerciseLibraryViewModel.searchPrompt)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateExercise = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create custom exercise")
                }
            }
            .sheet(isPresented: $showingCreateExercise) {
                ExerciseFormView(mode: .create) {
                    viewModel.refreshExercises()
                }
            }
        }
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: viewModel.selectedCategory == nil) {
                    viewModel.selectedCategory = nil
                }

                ForEach(ExerciseCategory.allCases, id: \.self) { category in
                    FilterChip(
                        title: category.rawValue.capitalized,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectedCategory = viewModel.selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Exercise List Row

struct ExerciseListRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            ExerciseIconView(category: exercise.category, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !exercise.primaryMuscleGroups.isEmpty {
                    Text(exercise.primaryMuscleGroupSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if exercise.isCustom {
                PillTag(text: "Custom", tint: Theme.info)
            }
        }
        .contentShape(Rectangle())
    }
}
