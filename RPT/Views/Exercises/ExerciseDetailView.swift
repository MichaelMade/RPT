//
//  ExerciseDetailView.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData
import UIKit

struct ExerciseDetailView: View {
    @Bindable var exercise: Exercise
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var templateViewModel = TemplateViewModel()
    @State private var showingEditSheet = false
    @State private var recentHistory: [(workout: Workout, set: ExerciseSet)] = []
    @State private var selectedSourceTemplate: WorkoutTemplate?
    @State private var copiedWorkoutName: String?
    @State private var showingCopySummaryAlert = false
    @State private var workoutToDelete: Workout?
    @State private var showingDeleteWorkoutAlert = false
    @State private var workoutToDiscardAndStartFollowUp: Workout?
    @State private var showingDiscardAndStartFollowUpConfirmation = false
    @State private var templateToDiscardAndStart: WorkoutTemplate?
    @State private var showingDiscardAndStartTemplateConfirmation = false
    @State private var localActiveWorkout: Workout?
    @State private var showingLocalActiveWorkoutSheet = false
    @State private var templateStartFailureTitle = "Workout Action Failed"
    @State private var templateStartFailureMessage: String?
    
    private let workoutManager = WorkoutManager.shared
    private let templateManager = TemplateManager.shared

    static func displayName(for exercise: Exercise) -> String {
        let collapsedName = exercise.name
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedName.isEmpty else {
            return "Exercise"
        }

        return String(collapsedName.prefix(80))
    }

    static func normalizedInstructions(for exercise: Exercise) -> String? {
        let collapsedInstructions = exercise.instructions
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsedInstructions.isEmpty else {
            return nil
        }

        return collapsedInstructions
    }

    static func recentHistoryEntries(from history: [(workout: Workout, sets: [ExerciseSet])]) -> [(workout: Workout, set: ExerciseSet)] {
        history
            .compactMap { workout, sets in
                let completedWorkingSets = sets.filter(\.isCompletedWorkingSet)

                guard let bestSet = completedWorkingSets.max(by: { lhs, rhs in
                    rhs.isBetterPerformance(than: lhs)
                }) else {
                    return nil
                }

                return (workout: workout, set: bestSet)
            }
            .sorted { lhs, rhs in
                if lhs.workout.date != rhs.workout.date {
                    return lhs.workout.date > rhs.workout.date
                }

                return lhs.set.completedAt > rhs.set.completedAt
            }
    }

    static func templateStartFailureAlertTitle(for template: WorkoutTemplate?) -> String {
        guard let template else {
            return "Couldn’t Start This Template"
        }

        return TemplateViewModel().startTemplateFailureAlertTitle(for: template)
    }

    static func templateSaveAndStartFailureAlertTitle(for template: WorkoutTemplate?) -> String {
        guard let template else {
            return "Couldn’t Save & Start This Template"
        }

        return TemplateViewModel().activeWorkoutPersistenceFailureAlertTitle(for: .saveForLater, opening: template)
    }

    static func templateDiscardAndStartFailureAlertTitle(for template: WorkoutTemplate?) -> String {
        guard let template else {
            return "Couldn’t Discard & Start This Template"
        }

        return TemplateViewModel().activeWorkoutPersistenceFailureAlertTitle(for: .discard, opening: template)
    }

    static func discardCurrentWorkoutAndStartTemplateAlertTitle(for template: WorkoutTemplate?, currentWorkout: Workout? = nil) -> String {
        guard let template else {
            return "Discard This Workout & Start This Template?"
        }

        return TemplateViewModel().discardCurrentWorkoutAndStartTemplateAlertTitle(for: template, currentWorkout: currentWorkout)
    }

    static func discardCurrentWorkoutAndStartTemplateAlertMessage(for template: WorkoutTemplate?, currentWorkout: Workout? = nil) -> String {
        guard let template else {
            return "Your in-progress workout will be lost before RPT starts the selected template. This action cannot be undone."
        }

        return TemplateViewModel().discardCurrentWorkoutAndStartTemplateAlertMessage(for: template, currentWorkout: currentWorkout)
    }

    static func discardCurrentWorkoutAndStartFollowUpAlertTitle(for workout: Workout?, currentWorkout: Workout? = nil) -> String {
        guard let workout else {
            return "Discard This Workout & Start This Follow-Up?"
        }

        return HomeViewModel().discardCurrentWorkoutAndStartFollowUpAlertTitle(for: workout, currentWorkout: currentWorkout)
    }

    static func discardCurrentWorkoutAndStartFollowUpAlertMessage(for workout: Workout?, currentWorkout: Workout? = nil) -> String {
        guard let workout else {
            return "Your in-progress workout will be lost before RPT starts the selected follow-up. This action cannot be undone."
        }

        return HomeViewModel().discardCurrentWorkoutAndStartFollowUpAlertMessage(for: workout, currentWorkout: currentWorkout)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with icon
                HStack(alignment: .center, spacing: 16) {
                    // Exercise icon
                    ExerciseIconView(category: exercise.category, size: 60)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Self.displayName(for: exercise))
                            .font(.title2)
                            .fontWeight(.bold)

                        // Category and custom badge
                        HStack {
                            ExerciseCategoryTag(category: exercise.category)
                            
                            if exercise.isCustom {
                                Text("Custom")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                        }
                        
                        // Main muscles
                        if !exercise.primaryMuscleGroups.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Primary Muscles")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 4) {
                                    ForEach(exercise.primaryMuscleGroups, id: \.self) { muscle in
                                        MuscleGroupTag(muscleGroup: muscle, isPrimary: true)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Secondary muscles
                        if !exercise.secondaryMuscleGroups.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Secondary Muscles")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 4) {
                                    ForEach(exercise.secondaryMuscleGroups, id: \.self) { muscle in
                                        MuscleGroupTag(muscleGroup: muscle, isPrimary: false)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // Instructions
                if let normalizedInstructions = Self.normalizedInstructions(for: exercise) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "list.bullet.clipboard")
                                .foregroundColor(exercise.category.style.color)
                            
                            Text("Instructions")
                                .font(.headline)
                        }
                        
                        Text(normalizedInstructions)
                            .font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                // View progress charts
                NavigationLink(destination: ExerciseProgressView(exercise: exercise)) {
                    HStack {
                        Image(systemName: "chart.xyaxis.line")
                            .foregroundColor(.white)
                        Text("View Progress")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(exercise.category.style.color)
                    .cornerRadius(12)
                }

                // Recent history
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(exercise.category.style.color)

                        Text("Exercise History")
                            .font(.headline)
                    }
                    
                    if recentHistory.isEmpty {
                        Text("No workout history for this exercise")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(Array(recentHistory.prefix(5).enumerated()), id: \.element.set.id) { _, entry in
                            let sourceTemplate = sourceTemplate(for: entry.workout)

                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(WorkoutDetailView.displayName(for: entry.workout))
                                            .font(.subheadline)

                                        Text(WorkoutRow.relativeDateText(for: entry.workout.date))
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        if let templateOriginText = WorkoutRow.templateOriginText(
                                            for: entry.workout,
                                            resolvedTemplateName: sourceTemplate?.name
                                        ) {
                                            Text(templateOriginText)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Text(entry.set.formattedWeightReps)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }

                                VStack(spacing: 8) {
                                    HStack(spacing: 12) {
                                        NavigationLink(destination: WorkoutDetailView(workout: entry.workout)) {
                                            Label(homeViewModel.reviewWorkoutButtonTitle(for: entry.workout), systemImage: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.blue)

                                        if let sourceTemplate,
                                           let sourceTemplateQuickActionTitle = homeViewModel.sourceTemplateQuickActionTitle(
                                            for: entry.workout,
                                            resolvedTemplateName: sourceTemplate.name,
                                            resolvedTemplate: sourceTemplate
                                           ) {
                                            Button {
                                                selectedSourceTemplate = sourceTemplate
                                            } label: {
                                                Label(sourceTemplateQuickActionTitle, systemImage: "square.on.square")
                                                    .font(.caption.weight(.semibold))
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .buttonStyle(.bordered)
                                            .tint(.purple)
                                        }
                                    }

                                    if let sourceTemplate {
                                        if let resumableWorkout = protectedResumableWorkout() {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text(templateViewModel.activeWorkoutBlocksTemplateStartMessage(for: resumableWorkout, opening: sourceTemplate))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)

                                                Button {
                                                    openStartedWorkout(resumableWorkout)
                                                } label: {
                                                    Label(templateViewModel.continueCurrentWorkoutButtonTitle(for: resumableWorkout), systemImage: "arrow.clockwise.circle.fill")
                                                        .font(.caption.weight(.semibold))
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                                .buttonStyle(.borderedProminent)
                                                .tint(.green)

                                                Button {
                                                    saveActiveWorkoutAndOpenTemplate(sourceTemplate)
                                                } label: {
                                                    Label(templateViewModel.saveAndStartTemplateButtonTitle(for: sourceTemplate), systemImage: "square.and.arrow.down")
                                                        .font(.caption.weight(.semibold))
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                                .buttonStyle(.bordered)

                                                Button(role: .destructive) {
                                                    templateToDiscardAndStart = sourceTemplate
                                                    showingDiscardAndStartTemplateConfirmation = true
                                                } label: {
                                                    Label(
                                                        templateViewModel.discardAndStartTemplateButtonTitle(
                                                            for: sourceTemplate,
                                                            currentWorkout: resumableWorkout
                                                        ),
                                                        systemImage: "trash"
                                                    )
                                                        .font(.caption.weight(.semibold))
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                                .buttonStyle(.bordered)
                                            }
                                        } else {
                                            Button {
                                                startWorkout(from: sourceTemplate)
                                            } label: {
                                                Label(templateViewModel.startTemplateButtonTitle(for: sourceTemplate), systemImage: "play.fill")
                                                    .font(.caption.weight(.semibold))
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.green)
                                        }
                                    }

                                    if let resumableWorkout = protectedResumableWorkout(), homeViewModel.shouldOfferFollowUpRecovery(for: entry.workout) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(homeViewModel.activeWorkoutBlocksFollowUpMessage(for: resumableWorkout, startingFrom: entry.workout))
                                                .font(.caption)
                                                .foregroundColor(.secondary)

                                            Button {
                                                openStartedWorkout(resumableWorkout)
                                            } label: {
                                                Label(homeViewModel.continueCurrentWorkoutButtonTitle(for: resumableWorkout), systemImage: "arrow.clockwise.circle.fill")
                                                    .font(.caption.weight(.semibold))
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.green)

                                            Button {
                                                saveActiveWorkoutAndStartFollowUp(from: entry.workout)
                                            } label: {
                                                Label(homeViewModel.saveAndStartFollowUpButtonTitle(for: entry.workout, currentWorkout: resumableWorkout), systemImage: "square.and.arrow.down")
                                                    .font(.caption.weight(.semibold))
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .buttonStyle(.bordered)

                                            Button(role: .destructive) {
                                                workoutToDiscardAndStartFollowUp = entry.workout
                                                showingDiscardAndStartFollowUpConfirmation = true
                                            } label: {
                                                Label(homeViewModel.discardAndStartFollowUpButtonTitle(for: entry.workout, currentWorkout: resumableWorkout), systemImage: "trash")
                                                    .font(.caption.weight(.semibold))
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    } else if homeViewModel.canStartFollowUpWorkout(from: entry.workout, activeWorkout: protectedResumableWorkout()) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(homeViewModel.followUpWorkoutHelperText(for: entry.workout))
                                                .font(.caption)
                                                .foregroundColor(.secondary)

                                            Button {
                                                startFollowUp(from: entry.workout)
                                            } label: {
                                                Label(homeViewModel.followUpWorkoutButtonTitle(for: entry.workout), systemImage: "arrow.triangle.2.circlepath")
                                                    .font(.caption.weight(.semibold))
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.green)
                                        }
                                    }

                                    Button {
                                        copyWorkoutSummary(entry.workout)
                                    } label: {
                                        Label(homeViewModel.copySummaryButtonTitle(for: entry.workout), systemImage: "doc.on.doc")
                                            .font(.caption.weight(.semibold))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.indigo)

                                    Button(role: .destructive) {
                                        workoutToDelete = entry.workout
                                        showingDeleteWorkoutAlert = true
                                    } label: {
                                        Label(homeViewModel.deleteRecentWorkoutButtonTitle(for: entry.workout), systemImage: "trash")
                                            .font(.caption.weight(.semibold))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(UIColor.tertiarySystemBackground))
                            )
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(Self.displayName(for: exercise))
        .toolbar {
            if exercise.isCustom {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(ExerciseLibraryViewModel.editScreenTitle(for: exercise)) {
                        showingEditSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditExerciseView(exercise: exercise)
        }
        .navigationDestination(item: $selectedSourceTemplate) { template in
            TemplateDetailView(
                template: template,
                onStartWorkout: { openStartedWorkout($0) },
                onEditTemplate: nil,
                onDuplicateTemplate: nil,
                onResumeActiveWorkout: protectedResumableWorkout() == nil ? nil : {
                    guard let activeWorkout = protectedResumableWorkout() else { return }
                    openStartedWorkout(activeWorkout)
                },
                onSaveActiveWorkoutAndOpenTemplate: protectedResumableWorkout() == nil ? nil : {
                    saveActiveWorkoutAndOpenTemplate(template)
                },
                onDiscardActiveWorkoutAndOpenTemplate: protectedResumableWorkout() == nil ? nil : {
                    discardActiveWorkoutAndOpenTemplate(template)
                },
                currentActiveWorkout: protectedResumableWorkout(),
                activeWorkoutBlockMessage: sourceTemplateBlockMessage(for: template)
            )
        }
        .alert("Workout Summary Copied", isPresented: $showingCopySummaryAlert) {
            Button("OK", role: .cancel) {
                copiedWorkoutName = nil
            }
        } message: {
            Text(copySummaryMessage)
        }
        .alert(
            workoutToDelete.map(homeViewModel.deleteRecentWorkoutAlertTitle(for:)) ?? "Delete Workout?",
            isPresented: $showingDeleteWorkoutAlert
        ) {
            Button(
                workoutToDelete.map(homeViewModel.deleteRecentWorkoutConfirmationButtonTitle(for:)) ?? "Delete",
                role: .destructive
            ) {
                guard let workoutToDelete else {
                    return
                }

                guard homeViewModel.deleteRecentWorkout(workoutToDelete) else {
                    return
                }

                recentHistory.removeAll { $0.workout.id == workoutToDelete.id }
                if copiedWorkoutName == WorkoutRow.displayName(for: workoutToDelete) {
                    copiedWorkoutName = nil
                }
                self.workoutToDelete = nil
            }

            Button("Cancel", role: .cancel) {
                workoutToDelete = nil
            }
        } message: {
            Text(workoutToDelete.map(homeViewModel.deleteRecentWorkoutMessage(for:)) ?? "")
        }
        .alert(
            Self.discardCurrentWorkoutAndStartFollowUpAlertTitle(
                for: workoutToDiscardAndStartFollowUp,
                currentWorkout: protectedResumableWorkout()
            ),
            isPresented: $showingDiscardAndStartFollowUpConfirmation,
            presenting: workoutToDiscardAndStartFollowUp
        ) { workout in
            Button(homeViewModel.discardAndStartFollowUpButtonTitle(for: workout, currentWorkout: protectedResumableWorkout()), role: .destructive) {
                discardActiveWorkoutAndStartFollowUp(from: workout)
                workoutToDiscardAndStartFollowUp = nil
            }

            Button(
                protectedResumableWorkout().map { homeViewModel.continueCurrentWorkoutButtonTitle(for: $0) }
                ?? "Continue Workout",
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
            Self.discardCurrentWorkoutAndStartTemplateAlertTitle(
                for: templateToDiscardAndStart,
                currentWorkout: protectedResumableWorkout()
            ),
            isPresented: $showingDiscardAndStartTemplateConfirmation,
            presenting: templateToDiscardAndStart
        ) { template in
            Button(
                templateViewModel.discardAndStartTemplateButtonTitle(
                    for: template,
                    currentWorkout: protectedResumableWorkout()
                ),
                role: .destructive
            ) {
                discardActiveWorkoutAndOpenTemplate(template)
                templateToDiscardAndStart = nil
            }

            Button(
                protectedResumableWorkout().map { templateViewModel.continueCurrentWorkoutButtonTitle(for: $0) }
                ?? "Continue Workout",
                role: .cancel
            ) {
                templateToDiscardAndStart = nil
            }
        } message: { template in
            Text(
                Self.discardCurrentWorkoutAndStartTemplateAlertMessage(
                    for: template,
                    currentWorkout: protectedResumableWorkout()
                )
            )
        }
        .alert(templateStartFailureTitle, isPresented: Binding(
            get: { templateStartFailureMessage != nil },
            set: { isPresented in
                if !isPresented {
                    clearTemplateStartFailure()
                }
            }
        )) {
            Button("OK", role: .cancel) {
                clearTemplateStartFailure()
            }
        } message: {
            Text(templateStartFailureMessage ?? "")
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
            loadRecentSets()
        }
    }
    
    // Load recent sets for this exercise
    private func loadRecentSets() {
        let history = workoutManager.getWorkoutHistory(for: exercise)
        recentHistory = Self.recentHistoryEntries(from: history)
    }

    private var copySummaryMessage: String {
        WorkoutRow.copySummaryMessage(forWorkoutNamed: copiedWorkoutName)
    }

    private func sourceTemplate(for workout: Workout) -> WorkoutTemplate? {
        templateManager.sourceTemplate(for: workout)
    }

    private func protectedResumableWorkout() -> Workout? {
        WorkoutStateManager.shared.resolvedResumableWorkout(
            currentBinding: localActiveWorkout,
            fallbackWorkouts: workoutManager.getIncompleteWorkouts()
        )
    }

    private func sourceTemplateBlockMessage(for template: WorkoutTemplate) -> String? {
        guard let activeWorkout = protectedResumableWorkout() else {
            return nil
        }

        return templateViewModel.activeWorkoutBlocksTemplateStartMessage(for: activeWorkout, opening: template)
    }

    private func openStartedWorkout(_ startedWorkout: Workout) {
        localActiveWorkout = startedWorkout
        showingLocalActiveWorkoutSheet = true
    }

    private func startWorkout(from template: WorkoutTemplate) {
        guard let startedWorkout = templateViewModel.createWorkoutFromTemplate(template) else {
            presentTemplateStartFailure(
                "Your template workout could not be started right now. Please try again.",
                title: Self.templateStartFailureAlertTitle(for: template)
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
            persist: { workoutManager.saveWorkoutSafely($0) }
        ) {
        case .success(let startedWorkout):
            openStartedWorkout(startedWorkout)
        case .failure(let message):
            presentTemplateStartFailure(
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
            persist: { workoutManager.deleteWorkoutSafely($0) }
        ) {
        case .success(let startedWorkout):
            openStartedWorkout(startedWorkout)
        case .failure(let message):
            presentTemplateStartFailure(
                message,
                title: Self.templateDiscardAndStartFailureAlertTitle(for: template)
            )
        }
    }

    private func presentTemplateStartFailure(_ message: String, title: String = "Workout Action Failed") {
        templateStartFailureTitle = title
        templateStartFailureMessage = message
    }

    private func clearTemplateStartFailure() {
        templateStartFailureTitle = "Workout Action Failed"
        templateStartFailureMessage = nil
    }

    private func startFollowUp(from workout: Workout) {
        guard homeViewModel.startFollowUpWorkout(from: workout), let startedWorkout = homeViewModel.currentWorkout else {
            return
        }

        openStartedWorkout(startedWorkout)
    }

    private func saveActiveWorkoutAndStartFollowUp(from workout: Workout) {
        guard let activeWorkout = protectedResumableWorkout() else { return }

        switch homeViewModel.startFollowUpAfterPersistingActiveWorkout(
            activeWorkout,
            action: .saveForLater,
            from: workout,
            persist: { workoutManager.saveWorkoutSafely($0) }
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
            persist: { workoutManager.deleteWorkoutSafely($0) }
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

    private func copyWorkoutSummary(_ workout: Workout) {
        UIPasteboard.general.string = workout.generateFormattedSummary()
        copiedWorkoutName = WorkoutRow.displayName(for: workout)
        showingCopySummaryAlert = true
    }
}
