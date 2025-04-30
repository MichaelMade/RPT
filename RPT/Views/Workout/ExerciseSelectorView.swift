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
                
                // Exercise list
                List {
                    let filteredExercises = viewModel.fetchExercises()
                    
                    if filteredExercises.isEmpty {
                        ContentUnavailableView(
                            "No Exercises Found",
                            systemImage: "magnifyingglass",
                            description: Text("Try changing your search or filters.")
                        )
                    } else {
                        ForEach(filteredExercises) { exercise in
                            // Make the entire row tappable
                            Button(action: {
                                // Provide haptic feedback
                                let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
                                feedbackGenerator.impactOccurred()
                                
                                // Select the exercise and dismiss
                                onSelectExercise(exercise)
                                dismiss()
                            }) {
                                // Exercise row content
                                HStack(spacing: 12) {
                                    // Exercise icon
                                    ExerciseIconView(category: exercise.category, size: 36)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text(exercise.primaryMuscleGroups.map { $0.rawValue.capitalized }.joined(separator: ", "))
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
