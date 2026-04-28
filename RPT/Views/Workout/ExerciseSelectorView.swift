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
    
    var onSelectExercise: (Exercise) -> Void
    
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
                    let filteredExercises = viewModel.fetchExercises()

                    if let summary = viewModel.filteredResultsSummary(filteredCount: filteredExercises.count) {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .listRowSeparator(.hidden)
                    }
                    
                    if filteredExercises.isEmpty {
                        ContentUnavailableView {
                            Label(
                                viewModel.hasActiveQuery ? "No Matching Exercises" : "No Exercises Available",
                                systemImage: viewModel.hasActiveQuery ? "magnifyingglass" : "dumbbell"
                            )
                        } description: {
                            Text(
                                viewModel.hasActiveQuery
                                ? "Try changing your search or filters, or clear them to browse every exercise."
                                : "Add an exercise in the library first, then come back here to use it in a workout."
                            )
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
}

#Preview {
    ExerciseSelectorView { _ in
        // This is a preview so we don't need to handle the selection
    }
    .modelContainer(for: [Exercise.self])
}
