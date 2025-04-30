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
                
                if filteredExercises.isEmpty {
                    ContentUnavailableView(
                        "No Exercises Found",
                        systemImage: "magnifyingglass",
                        description: Text("Try changing your search.")
                    )
                } else {
                    ForEach(filteredExercises) { exercise in
                        // Make the entire row tappable
                        Button(action: {
                            // Provide haptic feedback
                            let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
                            feedbackGenerator.impactOccurred()
                            
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
