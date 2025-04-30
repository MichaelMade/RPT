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
    
    // State for active workout handling
    @State private var showingActiveWorkoutAlert = false
    @State private var templateToStartWorkout: WorkoutTemplate?
    
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
                ForEach(viewModel.templates) { template in
                    Button(action: {
                        // Check if there's an active workout before proceeding
                        if activeWorkoutBinding != nil {
                            // Store the template we want to use
                            templateToStartWorkout = template
                            // Show active workout confirmation
                            showingActiveWorkoutAlert = true
                        } else {
                            // Proceed normally if no active workout
                            selectedTemplate = template
                            currentAction = .detail
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(template.name)
                                .font(.headline)
                            
                            HStack {
                                Text("\(template.exercises.count) exercises")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                // Preview of first few exercises
                                if !template.exercises.isEmpty {
                                    let previewExercises = template.exercises.prefix(2)
                                    Text(previewExercises.map { $0.exerciseName }.joined(separator: ", ") +
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
                            // Check if there's an active workout before proceeding
                            if activeWorkoutBinding != nil {
                                // Show active workout confirmation
                                showingActiveWorkoutAlert = true
                            } else {
                                // Proceed normally if no active workout
                                selectedTemplate = template
                                currentAction = .edit
                            }
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                        
                        Button(role: .destructive) {
                            // Check if there's an active workout before proceeding
                            if activeWorkoutBinding != nil {
                                // Show active workout confirmation
                                showingActiveWorkoutAlert = true
                            } else {
                                // Proceed normally if no active workout
                                templateToDelete = template
                                showingConfirmationDialog = true
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Workout Templates")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Check if there's an active workout before proceeding
                        if activeWorkoutBinding != nil {
                            // Show active workout confirmation
                            showingActiveWorkoutAlert = true
                        } else {
                            // Proceed normally if no active workout
                            showingCreateSheet = true
                        }
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
                Button("Delete \(template.name)", role: .destructive) {
                    viewModel.deleteTemplate(template)
                }
            } message: { template in
                Text("Are you sure you want to delete this template? This action cannot be undone.")
            }
            .onAppear {
                viewModel.refreshTemplates()
            }
            // Alert for active workout
            .alert("Active Workout In Progress", isPresented: $showingActiveWorkoutAlert) {
                Button("Save & Continue Later", role: .none) {
                    // Save the active workout
                    if let workout = activeWorkoutBinding {
                        WorkoutManager.shared.saveWorkout(workout)
                        
                        // Clear active workout
                        activeWorkoutBinding = nil
                        
                        // Continue with the intended action
                        if let template = templateToStartWorkout {
                            selectedTemplate = template
                            currentAction = .detail
                            templateToStartWorkout = nil
                        } else {
                            // Fallback for other actions
                            showingCreateSheet = true
                        }
                    }
                }
                
                Button("Discard Workout", role: .destructive) {
                    // Discard the active workout
                    if let workout = activeWorkoutBinding {
                        WorkoutManager.shared.deleteWorkout(workout)
                        
                        // Clear active workout
                        activeWorkoutBinding = nil
                        
                        // Continue with the intended action
                        if let template = templateToStartWorkout {
                            selectedTemplate = template
                            currentAction = .detail
                            templateToStartWorkout = nil
                        } else {
                            // Fallback for other actions
                            showingCreateSheet = true
                        }
                    }
                }
                
                Button("Continue Workout", role: .none) {
                    // Show the active workout
                    showActiveWorkoutSheet = true
                    // Reset states
                    templateToStartWorkout = nil
                }
                
                Button("Cancel", role: .cancel) {
                    // Reset states
                    templateToStartWorkout = nil
                }
            } message: {
                Text("You have an active workout. What would you like to do?")
            }
        }
    }
}

#Preview {
    NavigationStack {
        TemplatesListView()
            .modelContainer(for: [Exercise.self, Workout.self, ExerciseSet.self, WorkoutTemplate.self, UserSettings.self, User.self])
    }
}
