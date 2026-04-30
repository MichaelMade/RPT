//
//  TemplatesListView.swift - Active Workout Sheet Approach
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI
import SwiftData

struct TemplatesListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TemplateViewModel()
    @State private var showingCreateSheet = false
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var currentAction: TemplateAction?
    @State private var showingConfirmationDialog = false
    @State private var templateToDelete: WorkoutTemplate?
    @State private var searchText = ""
    
    // State for active workout handling
    @State private var showingActiveWorkoutAlert = false
    @State private var templateToStartWorkout: WorkoutTemplate?
    @State private var resumableWorkoutToProtect: Workout?
    
    // Bindings for active workout
    @Binding var activeWorkoutBinding: Workout?
    @Binding var showActiveWorkoutSheet: Bool
    
    // Default initializer with empty bindings for previews
    init() {
        self._activeWorkoutBinding = .constant(nil)
        self._showActiveWorkoutSheet = .constant(false)
    }
    
    // Custom initializer with bindings
    init(activeWorkoutBinding: Binding<Workout?>, showActiveWorkoutSheet: Binding<Bool>) {
        self._activeWorkoutBinding = activeWorkoutBinding
        self._showActiveWorkoutSheet = showActiveWorkoutSheet
    }
    
    enum TemplateAction {
        case detail
        case edit
    }
    
    var body: some View {
        NavigationStack {
            List {
                let filteredTemplates = viewModel.fetchTemplates()

                if let summary = viewModel.filteredResultsSummary(filteredCount: filteredTemplates.count) {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                }

                if filteredTemplates.isEmpty {
                    ContentUnavailableView {
                        Label(
                            viewModel.hasActiveSearch ? "No Matching Templates" : "No Templates Yet",
                            systemImage: viewModel.hasActiveSearch ? "magnifyingglass" : "list.bullet.clipboard"
                        )
                    } description: {
                        Text(
                            viewModel.hasActiveSearch
                            ? "Try a different search or clear it to browse every workout template."
                            : "Create your first workout template to quickly start repeatable RPT sessions."
                        )
                    } actions: {
                        if viewModel.hasActiveSearch {
                            Button("Clear Search") {
                                searchText = ""
                                viewModel.clearSearch()
                            }
                        } else {
                            Button("Create Template") {
                                showingCreateSheet = true
                            }
                        }
                    }
                } else {
                    ForEach(filteredTemplates) { template in
                        Button(action: {
                            if let resumableWorkout = protectedResumableWorkout() {
                                resumableWorkoutToProtect = resumableWorkout
                                templateToStartWorkout = template
                                showingActiveWorkoutAlert = true
                            } else {
                                selectedTemplate = template
                                currentAction = .detail
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(WorkoutTemplate.normalizedDisplayName(template.name))
                                    .font(.headline)

                                HStack {
                                    Text("\(template.exercises.count) exercises")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    // Preview of first few exercises
                                    if !template.exercises.isEmpty {
                                        let previewExercises = template.exercises.prefix(2)
                                        Text(previewExercises.map { TemplateExercise.normalizedDisplayName($0.exerciseName) }.joined(separator: ", ") +
                                             (template.exercises.count > 2 ? "..." : ""))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions {
                            Button {
                                selectedTemplate = template
                                currentAction = .edit
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)

                            Button(role: .destructive) {
                                templateToDelete = template
                                showingConfirmationDialog = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search templates")
            .onChange(of: searchText) { _, newValue in
                viewModel.searchText = newValue
            }
            .navigationTitle("Workout Templates")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCreateSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet, onDismiss: {
                viewModel.refreshTemplates() // Refresh on dismiss
            }) {
                TemplateEditView(isNewTemplate: true, existingTemplate: nil)
            }
            .sheet(item: $selectedTemplate, onDismiss: {
                selectedTemplate = nil
                viewModel.refreshTemplates() // Refresh on dismiss
            }) { template in
                if currentAction == .edit {
                    TemplateEditView(isNewTemplate: false, existingTemplate: template)
                } else {
                    // Use the updated template detail view with callback for starting workout
                    TemplateDetailView(template: template) { workout in
                        // Set the new workout as the active workout
                        activeWorkoutBinding = workout
                        // Dismiss the template sheet
                        selectedTemplate = nil
                    }
                }
            }
            .confirmationDialog(
                "Delete Template",
                isPresented: $showingConfirmationDialog,
                presenting: templateToDelete
            ) { template in
                Button("Delete \(WorkoutTemplate.normalizedDisplayName(template.name))", role: .destructive) {
                    viewModel.deleteTemplate(template)
                }
            } message: { template in
                Text("Are you sure you want to delete this template? This action cannot be undone.")
            }
            .onAppear {
                viewModel.refreshTemplates()
            }
            // Alert shown when user taps a template while an active workout is in progress.
            .alert("Active Workout In Progress", isPresented: $showingActiveWorkoutAlert) {
                Button("Save & Continue Later") {
                    if let workout = resumableWorkoutToProtect {
                        _ = WorkoutManager.shared.saveWorkoutSafely(workout)
                        activeWorkoutBinding = nil
                        WorkoutStateManager.shared.markWorkoutAsSaved(workout.id)
                    }
                    if let template = templateToStartWorkout {
                        selectedTemplate = template
                        currentAction = .detail
                    }
                    templateToStartWorkout = nil
                    resumableWorkoutToProtect = nil
                }

                Button("Discard Workout", role: .destructive) {
                    if let workout = resumableWorkoutToProtect {
                        _ = WorkoutManager.shared.deleteWorkoutSafely(workout)
                        activeWorkoutBinding = nil
                    }
                    if let template = templateToStartWorkout {
                        selectedTemplate = template
                        currentAction = .detail
                    }
                    templateToStartWorkout = nil
                    resumableWorkoutToProtect = nil
                }

                Button("Continue Workout") {
                    if let workout = resumableWorkoutToProtect {
                        activeWorkoutBinding = workout
                    }
                    showActiveWorkoutSheet = true
                    templateToStartWorkout = nil
                    resumableWorkoutToProtect = nil
                }

                Button("Cancel", role: .cancel) {
                    templateToStartWorkout = nil
                    resumableWorkoutToProtect = nil
                }
            } message: {
                Text("You have an active workout. What would you like to do?")
            }
        }
    }

    private func protectedResumableWorkout() -> Workout? {
        WorkoutStateManager.shared.resolvedResumableWorkout(
            currentBinding: activeWorkoutBinding,
            fallbackWorkouts: WorkoutManager.shared.getIncompleteWorkouts()
        )
    }
}

#Preview {
    NavigationStack {
        TemplatesListView()
            .modelContainer(for: [Exercise.self, Workout.self, ExerciseSet.self, WorkoutTemplate.self, UserSettings.self, User.self])
    }
}
