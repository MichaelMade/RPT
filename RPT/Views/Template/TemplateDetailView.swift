//
//  TemplateDetailView.swift - Updated for Back Confirmation
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI
import SwiftData

struct TemplateDetailView: View {
    let template: WorkoutTemplate
    let onStartWorkout: (Workout) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var startWorkoutFailureMessage: String?
    @State private var showingPartialStartConfirmation = false

    private let templateManager = TemplateManager.shared

    private var unavailableExerciseNames: [String] {
        templateManager.unavailableExerciseNames(in: template)
    }

    private var duplicateExerciseNames: [String] {
        templateManager.duplicateExerciseNames(in: template)
    }

    private var allTemplateExercisesUnavailable: Bool {
        !template.exercises.isEmpty && templateManager.availableExerciseCount(in: template) == 0
    }

    private var partialStartConfirmationMessage: String? {
        templateManager.partialStartConfirmationMessage(for: template)
    }

    private func startWorkout() {
        guard let workout = templateManager.createWorkoutFromTemplate(template) else {
            startWorkoutFailureMessage = allTemplateExercisesUnavailable
                ? "This template can’t start right now because none of its exercises are currently available in your library."
                : "Your workout could not be started right now. Please try again."
            return
        }

        onStartWorkout(workout)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                List {
                    Section(header: Text("Template Information")) {
                        Text(WorkoutTemplate.normalizedDisplayName(template.name))
                            .font(.headline)

                        if let normalizedNotes = WorkoutTemplate.normalizedDisplayNotes(template.notes) {
                            Text("Notes:")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(normalizedNotes)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section(header: Text("Exercises")) {
                        ForEach(template.exercises.indices, id: \.self) { index in
                            let exercise = template.exercises[index]
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(index + 1). \(TemplateExercise.normalizedDisplayName(exercise.exerciseName))")
                                    .font(.headline)
                                
                                Text("\(exercise.suggestedSets) sets")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                // Rep ranges
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(exercise.repRanges.sorted(by: { $0.setNumber < $1.setNumber }), id: \.setNumber) { repRange in
                                        HStack {
                                            Text("Set \(repRange.setNumber):")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                            
                                            Text("\(repRange.minReps)-\(repRange.maxReps) reps")
                                                .font(.caption)
                                            
                                            if repRange.percentageOfFirstSet != nil && repRange.setNumber > 1 {
                                                Text("(\(Int((repRange.percentageOfFirstSet ?? 1.0) * 100))% of first set)")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                }
                                
                                if let normalizedNotes = TemplateExercise.normalizedDisplayNotes(exercise.notes) {
                                    Text(normalizedNotes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if !unavailableExerciseNames.isEmpty {
                        Section(header: Text("Unavailable Right Now")) {
                            Text(
                                unavailableExerciseNames.count == 1
                                ? "1 template exercise is missing from your library and will be skipped until you restore or replace it."
                                : "\(unavailableExerciseNames.count) template exercises are missing from your library and will be skipped until you restore or replace them."
                            )
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                            ForEach(unavailableExerciseNames, id: \.self) { exerciseName in
                                Label(exerciseName, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                            }
                        }
                    }

                    if !duplicateExerciseNames.isEmpty {
                        Section(header: Text("Repeated Entries")) {
                            Text(
                                duplicateExerciseNames.count == 1
                                ? "1 repeated template exercise will only be added once when this workout starts. Edit the template to remove or replace the duplicate entry."
                                : "\(duplicateExerciseNames.count) repeated template exercises will only be added once when this workout starts. Edit the template to remove or replace the duplicate entries."
                            )
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                            ForEach(duplicateExerciseNames, id: \.self) { exerciseName in
                                Label(exerciseName, systemImage: "square.on.square.fill")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .padding(.bottom, 80) // Add padding at the bottom to make room for the button
                
                // Bottom button
                VStack {
                    Spacer()
                    
                    Button(action: {
                        if partialStartConfirmationMessage != nil {
                            showingPartialStartConfirmation = true
                        } else {
                            startWorkout()
                        }
                    }) {
                        HStack {
                            Image(systemName: "figure.strengthtraining.traditional")
                            Text(templateManager.startWorkoutActionTitle(for: template))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(allTemplateExercisesUnavailable)
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    .background(
                        Rectangle()
                            .fill(Color(UIColor.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
                            .edgesIgnoringSafeArea(.bottom)
                    )
                }
            }
            .navigationTitle("Template Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Start Partial Workout?", isPresented: $showingPartialStartConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Start Partial Workout") {
                    startWorkout()
                }
            } message: {
                Text(partialStartConfirmationMessage ?? "")
            }
            .alert("Workout Action Failed", isPresented: Binding(
                get: { startWorkoutFailureMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        startWorkoutFailureMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {
                    startWorkoutFailureMessage = nil
                }
            } message: {
                Text(startWorkoutFailureMessage ?? "")
            }
        }
    }
}

#Preview {
    let _ = try! ModelContainer(for: WorkoutTemplate.self, Exercise.self)
    
    // Create sample template with RPT style rep ranges
    let template = WorkoutTemplate(
        name: "Upper Body RPT",
        exercises: [
            TemplateExercise(
                exerciseName: "Bench Press",
                suggestedSets: 3,
                repRanges: [
                    TemplateRepRange(setNumber: 1, minReps: 4, maxReps: 6, percentageOfFirstSet: 1.0),
                    TemplateRepRange(setNumber: 2, minReps: 6, maxReps: 8, percentageOfFirstSet: 0.9),
                    TemplateRepRange(setNumber: 3, minReps: 8, maxReps: 10, percentageOfFirstSet: 0.8)
                ],
                notes: "Focus on chest contraction"
            ),
            TemplateExercise(
                exerciseName: "Pull-Up",
                suggestedSets: 3,
                repRanges: [
                    TemplateRepRange(setNumber: 1, minReps: 6, maxReps: 8, percentageOfFirstSet: 1.0),
                    TemplateRepRange(setNumber: 2, minReps: 8, maxReps: 10, percentageOfFirstSet: 0.9),
                    TemplateRepRange(setNumber: 3, minReps: 10, maxReps: 12, percentageOfFirstSet: 0.8)
                ],
                notes: "Add weight if needed"
            )
        ],
        notes: "Rest 2-3 minutes between sets"
    )
    
    return TemplateDetailView(
        template: template,
        onStartWorkout: { _ in
            // Preview doesn't need to handle the workout callback
        }
    )
}
