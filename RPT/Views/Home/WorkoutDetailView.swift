//
//  WorkoutDetailView.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI
import SwiftData
import UIKit

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let workout: Workout
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var templateViewModel = TemplateViewModel()
    @State private var showingCopySummaryAlert = false
    @State private var showingDeleteWorkoutAlert = false

    @Binding var activeWorkoutBinding: Workout?
    @Binding var showActiveWorkoutSheet: Bool

    private let templateManager = TemplateManager.shared

    private let summaryColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    static func displayName(for workout: Workout) -> String {
        let collapsedName = workout.name
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedName.isEmpty else {
            return "Workout"
        }

        return String(collapsedName.prefix(80))
    }

    static func displayExerciseName(_ exercise: Exercise) -> String {
        let collapsedName = exercise.name
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedName.isEmpty else {
            return "Exercise"
        }

        return String(collapsedName.prefix(80))
    }

    static func displayExerciseCount(for workout: Workout) -> Int {
        workout.visibleExerciseCount
    }

    static func displaySetCount(for workout: Workout) -> Int {
        workout.visibleSetCount
    }

    static func workMetric(for workout: Workout) -> (title: String, value: String) {
        if workout.hasPreferredWorkMetric {
            return (title: workout.preferredWorkMetricTitle, value: workout.preferredWorkMetricValue)
        }

        if workout.hasLoggedWarmupOnly {
            return (title: "Work", value: "Warm-up sets only")
        }

        if workout.isCompleted {
            return (title: "Work", value: "No sets logged")
        }

        if workout.sets.isEmpty {
            return (title: "Work", value: "Not started")
        }

        return (title: "Work", value: "Not logged yet")
    }

    static func summaryMetrics(for workout: Workout) -> [(title: String, value: String)] {
        var metrics: [(title: String, value: String)] = [
            (title: "Exercises", value: "\(displayExerciseCount(for: workout))"),
            (title: "Sets", value: "\(displaySetCount(for: workout))"),
            workMetric(for: workout)
        ]

        if workout.totalVolume > 0, workout.totalBodyweightReps > 0 {
            metrics.append((title: "Bodyweight Reps", value: workout.formattedTotalBodyweightReps()))
        }

        let safeDuration = workout.duration.isFinite ? max(0, workout.duration) : 0
        if workout.isCompleted, safeDuration > 0 {
            metrics.append((title: "Duration", value: workout.formattedDurationForSummary()))
        }

        return metrics
    }

    static func displayedExerciseGroups(for workout: Workout) -> [(exercise: Exercise, sets: [ExerciseSet])] {
        let groups = workout.orderedExerciseGroups

        guard workout.isCompleted else {
            return groups
        }

        let completedWorkingGroups = groups.filter { group in
            group.sets.contains(where: \.isCompletedWorkingSet)
        }
        if !completedWorkingGroups.isEmpty {
            return completedWorkingGroups
        }

        let completedLoggedGroups = groups.filter { group in
            group.sets.contains(where: \.isCompletedLoggedSet)
        }
        if !completedLoggedGroups.isEmpty {
            return completedLoggedGroups
        }

        return groups
    }

    static func normalizedNotes(for workout: Workout) -> String? {
        let collapsedNotes = workout.notes
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedNotes.isEmpty else {
            return nil
        }

        return collapsedNotes
    }

    static func exerciseDetailsEmptyState(for workout: Workout) -> (title: String, subtitle: String)? {
        guard displayedExerciseGroups(for: workout).isEmpty else {
            return nil
        }

        if workout.isCompleted {
            if workout.sets.isEmpty {
                return (
                    title: "No exercise details saved",
                    subtitle: "This workout was completed without any persisted exercise sets, so there’s nothing more to review here."
                )
            }

            return (
                title: "No logged exercise details",
                subtitle: "This completed workout only saved planned or unlogged exercise placeholders, so there are no recorded sets to review here."
            )
        }

        return (
            title: "No exercises added yet",
            subtitle: "Add an exercise to start logging sets and see your workout details here."
        )
    }

    init(workout: Workout) {
        self.workout = workout
        self._activeWorkoutBinding = .constant(nil)
        self._showActiveWorkoutSheet = .constant(false)
    }

    init(workout: Workout, activeWorkoutBinding: Binding<Workout?>, showActiveWorkoutSheet: Binding<Bool>) {
        self.workout = workout
        self._activeWorkoutBinding = activeWorkoutBinding
        self._showActiveWorkoutSheet = showActiveWorkoutSheet
    }

    private var sourceTemplateName: String? {
        WorkoutRow.templateOriginName(for: workout)
    }

    private var sourceTemplate: WorkoutTemplate? {
        if let sourceTemplateID = workout.startedFromTemplateID,
           let template = templateManager.fetchTemplate(byId: sourceTemplateID) {
            return template
        }

        guard let sourceTemplateName else {
            return nil
        }

        return templateManager.fetchTemplateByName(sourceTemplateName)
    }

    private func protectedResumableWorkout() -> Workout? {
        WorkoutStateManager.shared.resolvedResumableWorkout(
            currentBinding: activeWorkoutBinding,
            fallbackWorkouts: WorkoutManager.shared.getIncompleteWorkouts()
        )
    }

    private func sourceTemplateBlockMessage(for template: WorkoutTemplate) -> String? {
        guard let activeWorkout = protectedResumableWorkout() else {
            return nil
        }

        let activeWorkoutName = WorkoutRow.displayName(for: activeWorkout)
        let templateName = WorkoutTemplate.normalizedDisplayName(template.name)
        let templateSuffix = templateName == "Template"
            ? "before starting this template."
            : "before starting \(templateName)."

        return activeWorkoutName == "Workout"
            ? "You already have a workout in progress. Continue it \(templateSuffix)"
            : "You already have \(activeWorkoutName) in progress. Continue it \(templateSuffix)"
    }

    private func openStartedWorkout(_ startedWorkout: Workout) {
        activeWorkoutBinding = startedWorkout
        showActiveWorkoutSheet = true
    }

    private func saveActiveWorkoutAndOpenTemplate(_ template: WorkoutTemplate) {
        guard let activeWorkout = protectedResumableWorkout() else { return }

        switch templateViewModel.startTemplateAfterPersistingActiveWorkout(
            activeWorkout,
            action: .saveForLater,
            opening: template,
            persist: { WorkoutManager.shared.saveWorkoutSafely($0) }
        ) {
        case .success(let startedWorkout):
            activeWorkoutBinding = startedWorkout
            showActiveWorkoutSheet = true
        case .failure(let message):
            homeViewModel.startWorkoutFailureMessage = message
        }
    }

    private func discardActiveWorkoutAndOpenTemplate(_ template: WorkoutTemplate) {
        guard let activeWorkout = protectedResumableWorkout() else { return }

        switch templateViewModel.startTemplateAfterPersistingActiveWorkout(
            activeWorkout,
            action: .discard,
            opening: template,
            persist: { WorkoutManager.shared.deleteWorkoutSafely($0) }
        ) {
        case .success(let startedWorkout):
            activeWorkoutBinding = startedWorkout
            showActiveWorkoutSheet = true
        case .failure(let message):
            homeViewModel.startWorkoutFailureMessage = message
        }
    }

    private func saveActiveWorkoutAndStartFollowUp(from workout: Workout) {
        guard let activeWorkout = protectedResumableWorkout() else { return }

        switch homeViewModel.startFollowUpAfterPersistingActiveWorkout(
            activeWorkout,
            action: .saveForLater,
            from: workout,
            persist: { WorkoutManager.shared.saveWorkoutSafely($0) }
        ) {
        case .success(let startedWorkout):
            activeWorkoutBinding = startedWorkout
            showActiveWorkoutSheet = true
        case .failure(let message):
            homeViewModel.startWorkoutFailureMessage = message
        }
    }

    private func discardActiveWorkoutAndStartFollowUp(from workout: Workout) {
        guard let activeWorkout = protectedResumableWorkout() else { return }

        switch homeViewModel.startFollowUpAfterPersistingActiveWorkout(
            activeWorkout,
            action: .discard,
            from: workout,
            persist: { WorkoutManager.shared.deleteWorkoutSafely($0) }
        ) {
        case .success(let startedWorkout):
            activeWorkoutBinding = startedWorkout
            showActiveWorkoutSheet = true
        case .failure(let message):
            homeViewModel.startWorkoutFailureMessage = message
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Workout summary card
                VStack(alignment: .leading, spacing: 8) {
                    // Date
                    VStack(alignment: .leading, spacing: 4) {
                        Text(WorkoutRow.relativeDateText(for: workout.date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let templateOriginText = WorkoutRow.templateOriginText(for: workout) {
                            Text(templateOriginText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Workout stats
                    LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 12) {
                        ForEach(Self.summaryMetrics(for: workout), id: \.title) { metric in
                            StatBox(
                                title: metric.title,
                                value: metric.value
                            )
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Notes
                    if let normalizedNotes = Self.normalizedNotes(for: workout) {
                        Text("Notes")
                            .font(.headline)
                            .padding(.top, 4)
                        
                        Text(normalizedNotes)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                if let sourceTemplateName {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Source Template")
                            .font(.headline)

                        if let sourceTemplate {
                            Text("This workout started from \(WorkoutTemplate.normalizedDisplayName(sourceTemplate.name)). Open it to review the original plan, notes, and current start state.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            NavigationLink {
                                TemplateDetailView(
                                    template: sourceTemplate,
                                    onStartWorkout: { openStartedWorkout($0) },
                                    onEditTemplate: nil,
                                    onDuplicateTemplate: nil,
                                    onResumeActiveWorkout: protectedResumableWorkout() == nil ? nil : {
                                        guard let activeWorkout = protectedResumableWorkout() else { return }
                                        activeWorkoutBinding = activeWorkout
                                        showActiveWorkoutSheet = true
                                    },
                                    onSaveActiveWorkoutAndOpenTemplate: protectedResumableWorkout() == nil ? nil : {
                                        saveActiveWorkoutAndOpenTemplate(sourceTemplate)
                                    },
                                    onDiscardActiveWorkoutAndOpenTemplate: protectedResumableWorkout() == nil ? nil : {
                                        discardActiveWorkoutAndOpenTemplate(sourceTemplate)
                                    },
                                    activeWorkoutBlockMessage: sourceTemplateBlockMessage(for: sourceTemplate)
                                )
                            } label: {
                                Label("Open Template “\(WorkoutTemplate.normalizedDisplayName(sourceTemplate.name))”", systemImage: "square.on.square")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Text("This workout started from \(sourceTemplateName), but that template is no longer in your library.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                if workout.isCompleted {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("History Actions")
                            .font(.headline)

                        Text("Copy a ready-to-paste recap or remove this saved workout without backing out to Home first.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button {
                            UIPasteboard.general.string = workout.generateFormattedSummary()
                            showingCopySummaryAlert = true
                        } label: {
                            Label("Copy Summary", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .tint(.indigo)

                        Button(role: .destructive) {
                            showingDeleteWorkoutAlert = true
                        } label: {
                            Label("Delete from History", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                if workout.isCompleted {
                    if let resumableWorkout = homeViewModel.resumableWorkout(activeWorkout: activeWorkoutBinding) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Current Workout In Progress")
                                .font(.headline)

                            if homeViewModel.shouldOfferFollowUpRecovery(for: workout) {
                                Text(homeViewModel.activeWorkoutBlocksFollowUpMessage(for: resumableWorkout, startingFrom: workout))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(homeViewModel.startFreshWorkoutMessage(for: resumableWorkout))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Button {
                                activeWorkoutBinding = resumableWorkout
                                showActiveWorkoutSheet = true
                            } label: {
                                Label("Continue Current Workout", systemImage: "arrow.clockwise.circle.fill")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)

                            if homeViewModel.shouldOfferFollowUpRecovery(for: workout) {
                                Button {
                                    saveActiveWorkoutAndStartFollowUp(from: workout)
                                } label: {
                                    Label("Save & Start Follow-Up", systemImage: "square.and.arrow.down")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.bordered)

                                Button(role: .destructive) {
                                    discardActiveWorkoutAndStartFollowUp(from: workout)
                                } label: {
                                    Label("Discard & Start Follow-Up", systemImage: "trash")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else if homeViewModel.canStartFollowUpWorkout(from: workout, activeWorkout: activeWorkoutBinding) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Follow-Up")
                                .font(.headline)

                            Text(homeViewModel.followUpWorkoutHelperText(for: workout))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Button {
                                guard homeViewModel.startFollowUpWorkout(from: workout) else {
                                    return
                                }

                                activeWorkoutBinding = homeViewModel.currentWorkout
                                showActiveWorkoutSheet = true
                            } label: {
                                Label(homeViewModel.followUpWorkoutButtonTitle(for: workout), systemImage: "arrow.triangle.2.circlepath")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }

                // Exercise sections
                if let emptyState = Self.exerciseDetailsEmptyState(for: workout) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(emptyState.title)
                            .font(.headline)

                        Text(emptyState.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else {
                    ForEach(Self.displayedExerciseGroups(for: workout), id: \.exercise) { group in
                        NavigationLink(destination: ExerciseDetailView(exercise: group.exercise)) {
                            ExerciseSection(
                                exercise: group.exercise,
                                sets: group.sets
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(Self.displayName(for: workout))
        .navigationBarTitleDisplayMode(.inline)
        .alert("Workout Summary Copied", isPresented: $showingCopySummaryAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Copied the summary for \(Self.displayName(for: workout)) so it’s ready to paste anywhere you need it.")
        }
        .alert("Delete Workout?", isPresented: $showingDeleteWorkoutAlert) {
            Button("Delete", role: .destructive) {
                guard homeViewModel.deleteRecentWorkout(workout) else {
                    return
                }

                dismiss()
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text(homeViewModel.deleteRecentWorkoutMessage(for: workout))
        }
        .alert("Workout Action Failed", isPresented: Binding(
            get: { homeViewModel.startWorkoutFailureMessage != nil },
            set: { isPresented in
                if !isPresented {
                    homeViewModel.startWorkoutFailureMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                homeViewModel.startWorkoutFailureMessage = nil
            }
        } message: {
            Text(homeViewModel.startWorkoutFailureMessage ?? "")
        }
        .onAppear {
            homeViewModel.loadRecentWorkouts()
        }
    }
}

#Preview {
    let modelContainer = try! ModelContainer(for: Workout.self, ExerciseSet.self, Exercise.self)
    
    // Create a sample workout for the preview
    let workout = Workout(date: Date(), name: "Chest Day")
    let benchPress = Exercise(
        name: "Bench Press",
        category: .compound,
        primaryMuscleGroups: [.chest],
        secondaryMuscleGroups: [.triceps, .shoulders]
    )
    
    // Add some sets
    let set1 = ExerciseSet(weight: 225, reps: 5, exercise: benchPress, workout: workout)
    let set2 = ExerciseSet(weight: 205, reps: 7, exercise: benchPress, workout: workout)
    let set3 = ExerciseSet(weight: 185, reps: 9, exercise: benchPress, workout: workout)
    workout.sets.append(contentsOf: [set1, set2, set3])
    
    // Complete the workout
    workout.complete()
    
    return NavigationStack {
        WorkoutDetailView(workout: workout)
    }
    .modelContainer(modelContainer)
}

// Stats box for summary
struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

// Exercise section component
struct ExerciseSection: View {
    let exercise: Exercise
    let sets: [ExerciseSet]

    static func setDisplayText(for set: ExerciseSet) -> String {
        let formattedSet = set.formattedWeightReps

        guard !set.isCompletedLoggedSet else {
            return formattedSet
        }

        if set.isWarmup {
            if set.hasCompletedValues {
                return "Warm-up • \(formattedSet)"
            }

            return "Warm-up not logged"
        }

        if set.hasCompletedValues {
            return "Planned • \(formattedSet)"
        }

        return "Not logged"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(WorkoutDetailView.displayExerciseName(exercise))
                    .font(.headline)

                Spacer(minLength: 0)

                Label("View Exercise", systemImage: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundColor(.blue)
            }
            .padding(.leading, 8)

            // Sets
            VStack(spacing: 6) {
                ForEach(sets.indices, id: \.self) { index in
                    let set = sets[index]
                    
                    HStack {
                        Text("Set \(index + 1)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(Self.setDisplayText(for: set))
                            .font(.subheadline)
                        
                        if let rpe = set.displayRPE {
                            Text("RPE: \(rpe)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(set.isWarmup ? Color.yellow.opacity(0.1) : Color.clear)
                    .cornerRadius(6)
                }
            }
            .padding(12)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(8)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}
