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
    @State private var workoutToDiscardAndStartFollowUp: Workout?
    @State private var showingDiscardAndStartFollowUpConfirmation = false
    @State private var showingDiscardAndStartSourceTemplateConfirmation = false
    @State private var localActiveWorkout: Workout?
    @State private var showingLocalActiveWorkoutSheet = false

    @Binding var activeWorkoutBinding: Workout?
    @Binding var showActiveWorkoutSheet: Bool

    private let managesActiveWorkoutExternally: Bool
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

    static func discardCurrentWorkoutAndStartFollowUpAlertTitle(for workout: Workout?, currentWorkout: Workout? = nil) -> String {
        guard let workout else {
            return "Discard Current Workout & Start This Follow-Up?"
        }

        return HomeViewModel().discardCurrentWorkoutAndStartFollowUpAlertTitle(for: workout, currentWorkout: currentWorkout)
    }

    static func discardCurrentWorkoutAndStartFollowUpAlertMessage(for workout: Workout?, currentWorkout: Workout? = nil) -> String {
        guard let workout else {
            return "Your in-progress workout will be lost before RPT starts the selected follow-up. This action cannot be undone."
        }

        return HomeViewModel().discardCurrentWorkoutAndStartFollowUpAlertMessage(for: workout, currentWorkout: currentWorkout)
    }

    static func openSourceTemplateButtonTitle(for template: WorkoutTemplate?) -> String {
        guard let template else {
            return "Review Template"
        }

        return TemplateViewModel().reviewTemplateButtonTitle(for: template)
    }

    static func sourceTemplateDescription(for template: WorkoutTemplate?) -> String {
        guard let template else {
            return "This workout started from a saved template. Review the original plan or jump straight back into a fresh run from here."
        }

        let displayName = WorkoutTemplate.normalizedDisplayName(template.name)
        let startsPartially = TemplateManager.shared.startWorkoutConfirmationMessage(for: template) != nil

        if displayName == "Template" {
            return startsPartially
                ? "This workout started from a saved template. Review the original plan or jump straight back into the available part of this template from here."
                : "This workout started from a saved template. Review the original plan or jump straight back into a fresh run from here."
        }

        return startsPartially
            ? "This workout started from “\(displayName)”. Review the original plan or jump straight back into the available part of that template from here."
            : "This workout started from “\(displayName)”. Review the original plan or jump straight back into a fresh run from here."
    }

    static func unavailableSourceTemplateMessage(for templateName: String?) -> String {
        let displayName = WorkoutTemplate.normalizedDisplayName(templateName ?? "")

        guard displayName != "Template" else {
            return "This workout started from a saved template, but that template is no longer in your library."
        }

        return "This workout started from “\(displayName)”, but that template is no longer in your library."
    }

    static func templateStartFailureAlertTitle(for template: WorkoutTemplate?) -> String {
        guard let template else {
            return "Workout Action Failed"
        }

        return TemplateViewModel().startTemplateFailureAlertTitle(for: template)
    }

    static func templateSaveAndStartFailureAlertTitle(for template: WorkoutTemplate?) -> String {
        guard let template else {
            return "Workout Action Failed"
        }

        return TemplateViewModel().activeWorkoutPersistenceFailureAlertTitle(for: .saveForLater, opening: template)
    }

    static func templateDiscardAndStartFailureAlertTitle(for template: WorkoutTemplate?) -> String {
        guard let template else {
            return "Workout Action Failed"
        }

        return TemplateViewModel().activeWorkoutPersistenceFailureAlertTitle(for: .discard, opening: template)
    }

    static func sourceTemplateBlockMessage(for template: WorkoutTemplate?, activeWorkout: Workout?) -> String? {
        guard let template, let activeWorkout else {
            return nil
        }

        return TemplateViewModel().activeWorkoutBlocksTemplateStartMessage(for: activeWorkout, opening: template)
    }

    init(workout: Workout) {
        self.workout = workout
        self._activeWorkoutBinding = .constant(nil)
        self._showActiveWorkoutSheet = .constant(false)
        self.managesActiveWorkoutExternally = false
    }

    init(workout: Workout, activeWorkoutBinding: Binding<Workout?>, showActiveWorkoutSheet: Binding<Bool>) {
        self.workout = workout
        self._activeWorkoutBinding = activeWorkoutBinding
        self._showActiveWorkoutSheet = showActiveWorkoutSheet
        self.managesActiveWorkoutExternally = true
    }

    private var sourceTemplate: WorkoutTemplate? {
        templateManager.sourceTemplate(for: workout)
    }

    private var sourceTemplateName: String? {
        WorkoutRow.templateOriginName(for: workout, resolvedTemplateName: sourceTemplate?.name)
    }

    private var sourceTemplateOriginText: String? {
        WorkoutRow.templateOriginText(for: workout, resolvedTemplateName: sourceTemplate?.name)
    }

    private var discardAndStartSourceTemplateAlertTitle: String {
        guard let sourceTemplate else {
            return "Discard Current Workout & Start This Template?"
        }

        return templateViewModel.discardCurrentWorkoutAndStartTemplateAlertTitle(
            for: sourceTemplate,
            currentWorkout: protectedResumableWorkout()
        )
    }

    private var discardAndStartSourceTemplateAlertMessage: String {
        guard let sourceTemplate else {
            return "Your in-progress workout will be lost before RPT starts the selected template. This action cannot be undone."
        }

        return templateViewModel.discardCurrentWorkoutAndStartTemplateAlertMessage(
            for: sourceTemplate,
            currentWorkout: protectedResumableWorkout()
        )
    }

    private func protectedResumableWorkout() -> Workout? {
        WorkoutStateManager.shared.resolvedResumableWorkout(
            currentBinding: activeWorkoutBinding,
            fallbackWorkouts: WorkoutManager.shared.getIncompleteWorkouts()
        )
    }

    private func sourceTemplateBlockMessage(for template: WorkoutTemplate) -> String? {
        Self.sourceTemplateBlockMessage(for: template, activeWorkout: protectedResumableWorkout())
    }

    private func openStartedWorkout(_ startedWorkout: Workout) {
        if managesActiveWorkoutExternally {
            activeWorkoutBinding = startedWorkout
            showActiveWorkoutSheet = true
            return
        }

        localActiveWorkout = startedWorkout
        showingLocalActiveWorkoutSheet = true
    }

    private func startWorkout(from template: WorkoutTemplate) {
        guard let startedWorkout = templateViewModel.createWorkoutFromTemplate(template) else {
            homeViewModel.presentStartWorkoutFailure(
                "Your template workout could not be started right now. Please try again.",
                title: homeViewModel.startTemplateFailureAlertTitle(for: template)
            )
            return
        }

        openStartedWorkout(startedWorkout)
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
            openStartedWorkout(startedWorkout)
        case .failure(let message):
            homeViewModel.presentStartWorkoutFailure(
                message,
                title: Self.templateSaveAndStartFailureAlertTitle(for: template)
            )
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
            openStartedWorkout(startedWorkout)
        case .failure(let message):
            homeViewModel.presentStartWorkoutFailure(
                message,
                title: Self.templateDiscardAndStartFailureAlertTitle(for: template)
            )
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
            openStartedWorkout(startedWorkout)
        case .failure(let message):
            homeViewModel.presentStartWorkoutFailure(
                message,
                title: homeViewModel.activeWorkoutPersistenceFailureAlertTitle(
                    for: .saveForLater,
                    startingFollowUpFrom: workout
                )
            )
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
            openStartedWorkout(startedWorkout)
        case .failure(let message):
            homeViewModel.presentStartWorkoutFailure(
                message,
                title: homeViewModel.activeWorkoutPersistenceFailureAlertTitle(
                    for: .discard,
                    startingFollowUpFrom: workout
                )
            )
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

                        if let templateOriginText = sourceTemplateOriginText {
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
                            Text(Self.sourceTemplateDescription(for: sourceTemplate))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if let activeWorkout = protectedResumableWorkout() {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(templateViewModel.activeWorkoutBlocksTemplateStartMessage(for: activeWorkout, opening: sourceTemplate))
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Button {
                                        openStartedWorkout(activeWorkout)
                                    } label: {
                                        Label(templateViewModel.continueCurrentWorkoutButtonTitle(for: activeWorkout), systemImage: "arrow.clockwise.circle.fill")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.green)

                                    Button {
                                        saveActiveWorkoutAndOpenTemplate(sourceTemplate)
                                    } label: {
                                        Label(templateViewModel.saveAndStartTemplateButtonTitle(for: sourceTemplate), systemImage: "square.and.arrow.down")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.bordered)

                                    Button(role: .destructive) {
                                        showingDiscardAndStartSourceTemplateConfirmation = true
                                    } label: {
                                        Label(
                                            templateViewModel.discardAndStartTemplateButtonTitle(
                                                for: sourceTemplate,
                                                currentWorkout: activeWorkout
                                            ),
                                            systemImage: "trash"
                                        )
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            } else {
                                Button {
                                    startWorkout(from: sourceTemplate)
                                } label: {
                                    Label(templateViewModel.startTemplateButtonTitle(for: sourceTemplate), systemImage: "play.fill")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                            }

                            NavigationLink {
                                TemplateDetailView(
                                    template: sourceTemplate,
                                    onStartWorkout: { openStartedWorkout($0) },
                                    onEditTemplate: nil,
                                    onDuplicateTemplate: nil,
                                    onResumeActiveWorkout: protectedResumableWorkout() == nil ? nil : {
                                        guard let activeWorkout = protectedResumableWorkout() else { return }
                                        openStartedWorkout(activeWorkout)
                                    },
                                    onSaveActiveWorkoutAndOpenTemplate: protectedResumableWorkout() == nil ? nil : {
                                        saveActiveWorkoutAndOpenTemplate(sourceTemplate)
                                    },
                                    onDiscardActiveWorkoutAndOpenTemplate: protectedResumableWorkout() == nil ? nil : {
                                        discardActiveWorkoutAndOpenTemplate(sourceTemplate)
                                    },
                                    currentActiveWorkout: protectedResumableWorkout(),
                                    activeWorkoutBlockMessage: sourceTemplateBlockMessage(for: sourceTemplate)
                                )
                            } label: {
                                Label(WorkoutDetailView.openSourceTemplateButtonTitle(for: sourceTemplate), systemImage: "square.on.square")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Text(Self.unavailableSourceTemplateMessage(for: sourceTemplateName))
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
                            Label(homeViewModel.copySummaryButtonTitle(for: workout), systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .tint(.indigo)

                        Button(role: .destructive) {
                            showingDeleteWorkoutAlert = true
                        } label: {
                            Label(homeViewModel.deleteRecentWorkoutButtonTitle(for: workout), systemImage: "trash")
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
                            Text(homeViewModel.activeWorkoutInProgressTitle(for: resumableWorkout))
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
                                openStartedWorkout(resumableWorkout)
                            } label: {
                                Label(homeViewModel.continueCurrentWorkoutButtonTitle(for: resumableWorkout), systemImage: "arrow.clockwise.circle.fill")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)

                            if homeViewModel.shouldOfferFollowUpRecovery(for: workout) {
                                Button {
                                    saveActiveWorkoutAndStartFollowUp(from: workout)
                                } label: {
                                    Label(homeViewModel.saveAndStartFollowUpButtonTitle(for: workout), systemImage: "square.and.arrow.down")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.bordered)

                                Button(role: .destructive) {
                                    workoutToDiscardAndStartFollowUp = workout
                                    showingDiscardAndStartFollowUpConfirmation = true
                                } label: {
                                    Label(homeViewModel.discardAndStartFollowUpButtonTitle(for: workout), systemImage: "trash")
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

                                guard let startedWorkout = homeViewModel.currentWorkout else {
                                    return
                                }

                                openStartedWorkout(startedWorkout)
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
            Text(WorkoutRow.copySummaryMessage(forWorkoutNamed: Self.displayName(for: workout)))
        }
        .alert(homeViewModel.deleteRecentWorkoutAlertTitle(for: workout), isPresented: $showingDeleteWorkoutAlert) {
            Button(homeViewModel.deleteRecentWorkoutConfirmationButtonTitle(for: workout), role: .destructive) {
                guard homeViewModel.deleteRecentWorkout(workout) else {
                    return
                }

                dismiss()
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text(homeViewModel.deleteRecentWorkoutMessage(for: workout))
        }
        .alert(
            Self.discardCurrentWorkoutAndStartFollowUpAlertTitle(
                for: workoutToDiscardAndStartFollowUp,
                currentWorkout: protectedResumableWorkout()
            ),
            isPresented: $showingDiscardAndStartFollowUpConfirmation,
            presenting: workoutToDiscardAndStartFollowUp
        ) { workout in
            Button(homeViewModel.discardAndStartFollowUpButtonTitle(for: workout), role: .destructive) {
                discardActiveWorkoutAndStartFollowUp(from: workout)
                workoutToDiscardAndStartFollowUp = nil
            }

            Button(
                protectedResumableWorkout().map { homeViewModel.continueCurrentWorkoutButtonTitle(for: $0) }
                ?? "Continue Current Workout",
                role: .cancel
            ) {
                workoutToDiscardAndStartFollowUp = nil
            }
        } message: { workout in
            Text(
                Self.discardCurrentWorkoutAndStartFollowUpAlertMessage(
                    for: workout,
                    currentWorkout: protectedResumableWorkout()
                )
            )
        }
        .alert(
            discardAndStartSourceTemplateAlertTitle,
            isPresented: $showingDiscardAndStartSourceTemplateConfirmation
        ) {
            Button(
                protectedResumableWorkout().map { templateViewModel.continueCurrentWorkoutButtonTitle(for: $0) }
                ?? "Continue Current Workout",
                role: .cancel
            ) { }

            if let sourceTemplate {
                Button(
                    templateViewModel.discardAndStartTemplateButtonTitle(
                        for: sourceTemplate,
                        currentWorkout: protectedResumableWorkout()
                    ),
                    role: .destructive
                ) {
                    discardActiveWorkoutAndOpenTemplate(sourceTemplate)
                }
            }
        } message: {
            Text(discardAndStartSourceTemplateAlertMessage)
        }
        .alert(homeViewModel.startWorkoutFailureAlertTitle, isPresented: Binding(
            get: { homeViewModel.startWorkoutFailureMessage != nil },
            set: { isPresented in
                if !isPresented {
                    homeViewModel.clearStartWorkoutFailure()
                }
            }
        )) {
            Button("OK", role: .cancel) {
                homeViewModel.clearStartWorkoutFailure()
            }
        } message: {
            Text(homeViewModel.startWorkoutFailureMessage ?? "")
        }
        .sheet(isPresented: $showingLocalActiveWorkoutSheet, onDismiss: {
            if localActiveWorkout?.isCompleted == true {
                localActiveWorkout = nil
            }
        }) {
            if let localActiveWorkout {
                ActiveWorkoutView(workout: localActiveWorkout)
            }
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
