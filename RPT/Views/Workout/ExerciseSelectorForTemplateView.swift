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
    
    var onSelectExercise: (String) -> Void
    
    var body: some View {
        NavigationStack {
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
                            ? "Try changing your search, or clear it to browse every exercise."
                            : "Add an exercise in the library first, then come back here to use it in a template."
                        )
                    } actions: {
                        if viewModel.hasActiveSearch {
                            Button("Clear Search") {
                                searchText = ""
                                viewModel.clearSearch()
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
                            onSelectExercise(exercise.name)
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
