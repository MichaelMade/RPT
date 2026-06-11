//
//  ExercisesView.swift
//  RPT
//
//  Browsable exercise library with search, category filters, and
//  custom exercise creation.
//

import SwiftUI

struct ExercisesView: View {
    @StateObject private var viewModel = ExerciseLibraryViewModel()
    @State private var showingCreateExercise = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar

                if viewModel.filteredExercises.isEmpty {
                    ScrollView {
                        EmptyStateCard(
                            icon: "magnifyingglass",
                            title: "No Matches",
                            message: viewModel.noMatchesDescription(),
                            actionTitle: "Create Custom Exercise"
                        ) {
                            showingCreateExercise = true
                        }
                        .padding(Theme.screenPadding)
                    }
                } else {
                    List(viewModel.filteredExercises) { exercise in
                        NavigationLink {
                            ExerciseDetailView(exercise: exercise) {
                                viewModel.refreshExercises()
                            }
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
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateExercise = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateExercise) {
                ExerciseFormView(mode: .create) {
                    viewModel.refreshExercises()
                }
            }
            .onAppear {
                viewModel.refreshExercises()
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: viewModel.selectedCategory == nil && viewModel.selectedMuscleGroup == nil) {
                    viewModel.selectedCategory = nil
                    viewModel.selectedMuscleGroup = nil
                }

                ForEach(ExerciseCategory.allCases, id: \.self) { category in
                    FilterChip(
                        title: category.rawValue.capitalized,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectedCategory = viewModel.selectedCategory == category ? nil : category
                    }
                }

                Divider()
                    .frame(height: 20)

                ForEach(MuscleGroup.allCases.filter { $0 != .other }, id: \.self) { muscle in
                    FilterChip(
                        title: muscle.displayName,
                        isSelected: viewModel.selectedMuscleGroup == muscle
                    ) {
                        viewModel.selectedMuscleGroup = viewModel.selectedMuscleGroup == muscle ? nil : muscle
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.vertical, 10)
        }
    }
}
