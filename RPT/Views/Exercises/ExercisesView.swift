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
    @State private var exerciseToDelete: Exercise?
    @State private var showingDeleteConfirmation = false
    
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
                                title: muscleGroup.rawValue.capitalized,
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
                    
                    if exercises.isEmpty {
                        ContentUnavailableView(
                            "No Exercises Found",
                            systemImage: "magnifyingglass",
                            description: Text("Try changing your search or filters.")
                        )
                    } else {
                        ForEach(exercises) { exercise in
                            NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                                ExerciseRowView(exercise: exercise)
                            }
                            .swipeActions(edge: .trailing) {
                                if exercise.isCustom {
                                    Button(role: .destructive) {
                                        exerciseToDelete = exercise
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
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
            .navigationTitle("Exercise Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
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
                AddExerciseView()
            }
            .confirmationDialog(
                "Delete Exercise",
                isPresented: $showingDeleteConfirmation,
                presenting: exerciseToDelete
            ) { exercise in
                Button("Delete \(exercise.name)", role: .destructive) {
                    viewModel.deleteExercise(exercise)
                }
            } message: { exercise in
                Text("Are you sure you want to delete this exercise? This action cannot be undone.")
            }
            .onAppear {
                viewModel.refreshExercises()
            }
        }
    }
}
