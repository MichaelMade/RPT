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
    let onEditTemplate: (() -> Void)?
    let onDuplicateTemplate: (() -> Void)?
    let onResumeActiveWorkout: (() -> Void)?
    let onSaveActiveWorkoutAndOpenTemplate: (() -> Void)?
    let onDiscardActiveWorkoutAndOpenTemplate: (() -> Void)?
    let currentActiveWorkout: Workout?
    let activeWorkoutBlockMessage: String?
    @Environment(\.dismiss) private var dismiss
    @State private var startWorkoutFailureTitle = "Workout Action Failed"
    @State private var startWorkoutFailureMessage: String?
    @State private var showingStartWorkoutConfirmation = false
    @State private var showingDiscardAndStartConfirmation = false
    @State private var showingRestoreExerciseSheet = false
    @State private var restoreExercisePrefillName = ""

    private let templateManager = TemplateManager.shared
    private let templateViewModel = TemplateViewModel()

    private var unavailableExerciseNames: [String] {
        templateManager.unavailableExerciseNames(in: template)
    }

    private var duplicateExerciseNames: [String] {
        templateManager.duplicateExerciseNames(in: template)
    }

    private var startableExerciseNames: [String] {
        templateManager.startableExerciseNames(in: template)
    }

    private var cannotStartWorkout: Bool {
        !templateManager.canStartWorkout(for: template)
    }

    private var startWorkoutConfirmationMessage: String? {
        templateManager.startWorkoutConfirmationMessage(for: template)
    }

    private var startWorkoutDisabledMessage: String? {
        templateManager.startWorkoutDisabledMessage(for: template)
    }

    private var isBlockedByActiveWorkout: Bool {
        activeWorkoutBlockMessage != nil && !cannotStartWorkout
    }

    private var canResumeActiveWorkout: Bool {
        activeWorkoutBlockMessage != nil && onResumeActiveWorkout != nil
    }

    private var resolvedStartWorkoutHelperMessages: [String] {
        var messages: [String] = []

        if let startWorkoutDisabledMessage {
            messages.append(startWorkoutDisabledMessage)
        }

        if let activeWorkoutBlockMessage, !messages.contains(activeWorkoutBlockMessage) {
            messages.append(activeWorkoutBlockMessage)
        }

        return messages
    }

    private var startWorkoutActionTitle: String {
        templateManager.startWorkoutActionTitle(
            for: template,
            blockedByActiveWorkout: isBlockedByActiveWorkout,
            blockingWorkout: currentActiveWorkout
        )
    }

    private var startWorkoutButtonTitle: String {
        guard !cannotStartWorkout, !isBlockedByActiveWorkout else {
            return startWorkoutActionTitle
        }

        return templateViewModel.quickStartTemplateButtonTitle(for: template)
    }

    private var templateStatusSummary: String {
        templateManager.templateDetailStatusSummary(for: template, blockedByActiveWorkout: isBlockedByActiveWorkout)
    }

    private var statusTone: TemplateManager.TemplateStatusTone {
        templateManager.templateStatusTone(for: template, blockedByActiveWorkout: isBlockedByActiveWorkout)
    }

    private var statusTint: Color {
        switch statusTone {
        case .ready:
            return .green
        case .warning, .blocked:
            return .orange
        case .blockedByActiveWorkout:
            return .gray
        }
    }

    private var statusIcon: String {
        switch statusTone {
        case .ready:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.circle.fill"
        case .blockedByActiveWorkout:
            return "pause.circle.fill"
        case .blocked:
            return "xmark.circle.fill"
        }
    }

    private var startWorkoutButtonBackgroundColor: Color {
        cannotStartWorkout || isBlockedByActiveWorkout ? .gray : .blue
    }

    private var shouldSuggestEditingTemplate: Bool {
        cannotStartWorkout || !unavailableExerciseNames.isEmpty || !duplicateExerciseNames.isEmpty
    }

    private func presentStartWorkoutFailure(_ message: String, title: String? = nil) {
        startWorkoutFailureTitle = title ?? templateViewModel.startTemplateFailureAlertTitle(for: template)
        startWorkoutFailureMessage = message
    }

    private func clearStartWorkoutFailure() {
        startWorkoutFailureTitle = "Workout Action Failed"
        startWorkoutFailureMessage = nil
    }

    private func startWorkout() {
        guard let workout = templateManager.createWorkoutFromTemplate(template) else {
            presentStartWorkoutFailure(
                startWorkoutDisabledMessage
                    ?? (cannotStartWorkout
                        ? "This template can’t start right now because none of its exercises are currently available in your library."
                        : "Your workout could not be started right now. Please try again.")
            )
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

                    Section(header: Text("Status")) {
                        Label(startWorkoutActionTitle, systemImage: statusIcon)
                            .font(.headline)
                            .foregroundColor(statusTint)

                        Text(templateStatusSummary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Section(header: Text("Exercises")) {
                        if template.exercises.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("No exercises added yet", systemImage: "list.bullet.clipboard")
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                Text("Add at least 1 exercise to this template before starting a workout.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 8)
                        } else {
                            ForEach(template.exercises.indices, id: \.self) { index in
                                let exercise = template.exercises[index]
                                let exerciseIssues = templateManager.issues(for: template, exerciseId: exercise.id)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(index + 1). \(TemplateExercise.normalizedDisplayName(exercise.exerciseName))")
                                        .font(.headline)

                                    if templateManager.isExerciseIncludedWhenStartingWorkout(for: template, exerciseId: exercise.id) {
                                        Label("Included when this workout starts", systemImage: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }

                                    if !exerciseIssues.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            ForEach(Array(exerciseIssues.enumerated()), id: \.offset) { _, issue in
                                                Label(issue.summary, systemImage: issue == .missingFromLibrary ? "exclamationmark.triangle.fill" : "square.on.square.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                    }

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
                                HStack(alignment: .center, spacing: 12) {
                                    Label(exerciseName, systemImage: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)

                                    Spacer(minLength: 12)

                                    Button("Restore") {
                                        restoreExercisePrefillName = exerciseName
                                        showingRestoreExerciseSheet = true
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
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

                    if !startableExerciseNames.isEmpty && (!unavailableExerciseNames.isEmpty || !duplicateExerciseNames.isEmpty) {
                        Section(header: Text("Ready Right Now")) {
                            Text(
                                startableExerciseNames.count == 1
                                ? "This template can currently start with 1 unique exercise."
                                : "This template can currently start with \(startableExerciseNames.count) unique exercises."
                            )
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                            ForEach(startableExerciseNames, id: \.self) { exerciseName in
                                Label(exerciseName, systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .padding(.bottom, 80) // Add padding at the bottom to make room for the button
                
                // Bottom button
                VStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: {
                            if startWorkoutConfirmationMessage != nil {
                                showingStartWorkoutConfirmation = true
                            } else {
                                startWorkout()
                            }
                        }) {
                            HStack {
                                Image(systemName: "figure.strengthtraining.traditional")
                                Text(startWorkoutButtonTitle)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(startWorkoutButtonBackgroundColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(cannotStartWorkout || isBlockedByActiveWorkout)

                        if canResumeActiveWorkout,
                           let activeWorkout,
                           let onResumeActiveWorkout {
                            Button(action: onResumeActiveWorkout) {
                                HStack {
                                    Image(systemName: "arrow.clockwise.circle")
                                    Text(templateViewModel.continueCurrentWorkoutButtonTitle(for: activeWorkout))
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }

                        if isBlockedByActiveWorkout, let onSaveActiveWorkoutAndOpenTemplate {
                            Button(action: onSaveActiveWorkoutAndOpenTemplate) {
                                HStack {
                                    Image(systemName: "tray.and.arrow.down")
                                    Text(templateViewModel.saveAndStartTemplateButtonTitle(for: template))
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                        }

                        if isBlockedByActiveWorkout, let onDiscardActiveWorkoutAndOpenTemplate {
                            Button(role: .destructive) {
                                showingDiscardAndStartConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text(
                                        templateViewModel.discardAndStartTemplateButtonTitle(
                                            for: template,
                                            currentWorkout: currentActiveWorkout
                                        )
                                    )
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }

                        if let onDuplicateTemplate {
                            Button(action: onDuplicateTemplate) {
                                HStack {
                                    Image(systemName: "plus.square.on.square")
                                    Text(templateViewModel.duplicateTemplateButtonTitle(for: template))
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }

                        if shouldSuggestEditingTemplate, let onEditTemplate {
                            Button(action: onEditTemplate) {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text(templateViewModel.editTemplateButtonTitle(for: template))
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }

                        ForEach(Array(resolvedStartWorkoutHelperMessages.enumerated()), id: \.offset) { _, helperMessage in
                            Text(helperMessage)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
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
            .navigationTitle(TemplateViewModel.templateDetailNavigationTitle(for: template.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if let onEditTemplate {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(templateViewModel.editTemplateButtonTitle(for: template), action: onEditTemplate)
                    }
                }
            }
            .sheet(isPresented: $showingRestoreExerciseSheet) {
                AddExerciseView(initialExerciseName: restoreExercisePrefillName)
            }
            .alert(startWorkoutButtonTitle, isPresented: $showingStartWorkoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button(startWorkoutButtonTitle) {
                    startWorkout()
                }
            } message: {
                Text(startWorkoutConfirmationMessage ?? "")
            }
            .alert(
                templateViewModel.discardCurrentWorkoutAndStartTemplateAlertTitle(
                    for: template,
                    currentWorkout: currentActiveWorkout
                ),
                isPresented: $showingDiscardAndStartConfirmation
            ) {
                Button("Keep Current Workout", role: .cancel) { }

                if let onDiscardActiveWorkoutAndOpenTemplate {
                    Button(
                        templateViewModel.discardAndStartTemplateButtonTitle(
                            for: template,
                            currentWorkout: currentActiveWorkout
                        ),
                        role: .destructive
                    ) {
                        onDiscardActiveWorkoutAndOpenTemplate()
                    }
                }
            } message: {
                Text(
                    templateViewModel.discardCurrentWorkoutAndStartTemplateAlertMessage(
                        for: template,
                        currentWorkout: currentActiveWorkout
                    )
                )
            }
            .alert(startWorkoutFailureTitle, isPresented: Binding(
                get: { startWorkoutFailureMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        clearStartWorkoutFailure()
                    }
                }
            )) {
                Button("OK", role: .cancel) {
                    clearStartWorkoutFailure()
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
        },
        onEditTemplate: {},
        onDuplicateTemplate: {},
        onResumeActiveWorkout: nil,
        onSaveActiveWorkoutAndOpenTemplate: nil,
        onDiscardActiveWorkoutAndOpenTemplate: nil,
        currentActiveWorkout: nil,
        activeWorkoutBlockMessage: nil
    )
}
