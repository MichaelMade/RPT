//
//  HomeView.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI
import SwiftData
import UIKit

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var templateViewModel = TemplateViewModel()
    @State private var showingRPTCalculator = false
    @State private var showingPlateCalculator = false
    @State private var selectedWorkout: Workout?
    @State private var selectedSourceTemplate: WorkoutTemplate?
    @State private var showingStartFreshAlert = false
    @State private var showingDeleteWorkoutAlert = false
    @State private var showingCopySummaryAlert = false
    @State private var showingFollowUpRecoveryAlert = false
    @State private var showingDiscardAndStartFollowUpConfirmation = false
    @State private var showingTemplateStartRecoveryAlert = false
    @State private var showingDiscardAndStartTemplateConfirmation = false
    @State private var resumableWorkoutToReplace: Workout?
    @State private var workoutToDelete: Workout?
    @State private var workoutToStartFollowUp: Workout?
    @State private var workoutToDiscardAndStartFollowUp: Workout?
    @State private var templateToStartFromHistory: WorkoutTemplate?
    @State private var templateToDiscardAndStart: WorkoutTemplate?
    @State private var copiedWorkoutName: String?
    @State private var startFreshFailureTitle: String?
    @State private var startFreshFailureMessage: String?
    @StateObject private var workoutStateManager = WorkoutStateManager.shared
    private let templateManager = TemplateManager.shared
    
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

    private var deleteWorkoutAlertTitle: String {
        guard let workoutToDelete else {
            return "Delete Workout?"
        }

        return viewModel.deleteRecentWorkoutAlertTitle(for: workoutToDelete)
    }

    private var deleteWorkoutButtonTitle: String {
        guard let workoutToDelete else {
            return "Delete"
        }

        return viewModel.deleteRecentWorkoutConfirmationButtonTitle(for: workoutToDelete)
    }

    private var startFreshAlertTitle: String {
        guard let resumableWorkoutToReplace else {
            return "Replace Current Workout?"
        }

        return viewModel.replaceCurrentWorkoutAlertTitle(for: resumableWorkoutToReplace)
    }

    private var startFreshSaveButtonTitle: String {
        guard let resumableWorkoutToReplace else {
            return "Save Current Workout & Start New Workout"
        }

        return viewModel.saveAndStartFreshButtonTitle(for: resumableWorkoutToReplace)
    }

    private var startFreshDiscardButtonTitle: String {
        guard let resumableWorkoutToReplace else {
            return "Discard Current Workout & Start New Workout"
        }

        return viewModel.discardAndStartFreshButtonTitle(for: resumableWorkoutToReplace)
    }

    private var followUpRecoveryAlertTitle: String {
        viewModel.activeWorkoutInProgressTitle(for: protectedResumableWorkout())
    }

    private var templateStartRecoveryAlertTitle: String {
        viewModel.activeWorkoutInProgressTitle(for: protectedResumableWorkout())
    }

    static func discardCurrentWorkoutAndStartTemplateAlertTitle(for template: WorkoutTemplate?) -> String {
        guard let template else {
            return "Discard Current Workout & Start This Template?"
        }

        return TemplateViewModel().discardCurrentWorkoutAndStartTemplateAlertTitle(for: template)
    }

    static func discardCurrentWorkoutAndStartTemplateAlertMessage(for template: WorkoutTemplate?) -> String {
        guard let template else {
            return "Your in-progress workout will be lost before RPT starts the selected template. This action cannot be undone."
        }

        return TemplateViewModel().discardCurrentWorkoutAndStartTemplateAlertMessage(for: template)
    }

    static func discardCurrentWorkoutAndStartFollowUpAlertTitle(for workout: Workout?) -> String {
        guard let workout else {
            return "Discard Current Workout & Start This Follow-Up?"
        }

        return HomeViewModel().discardCurrentWorkoutAndStartFollowUpAlertTitle(for: workout)
    }

    static func discardCurrentWorkoutAndStartFollowUpAlertMessage(for workout: Workout?) -> String {
        guard let workout else {
            return "Your in-progress workout will be lost before RPT starts the selected follow-up. This action cannot be undone."
        }

        return HomeViewModel().discardCurrentWorkoutAndStartFollowUpAlertMessage(for: workout)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with welcome message
                    VStack(alignment: .leading) {
                        Text("RPT Trainer")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Start your reverse pyramid training session")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Start/Continue workout button
                    VStack(alignment: .leading, spacing: 10) {
                        let resumableWorkout = viewModel.resumableWorkout(activeWorkout: activeWorkoutBinding)
                        let canContinueWorkout = resumableWorkout != nil

                        Button(action: {
                            if let resumableWorkout {
                                activeWorkoutBinding = resumableWorkout
                                showActiveWorkoutSheet = true
                            } else if viewModel.startNewWorkout() {
                                workoutStateManager.clearDiscardedState()
                                activeWorkoutBinding = viewModel.currentWorkout
                                showActiveWorkoutSheet = true
                            }
                        }) {
                            HStack {
                                Image(systemName: canContinueWorkout ? "arrow.clockwise.circle.fill" : "plus.circle.fill")
                                    .font(.title2)

                                Text(
                                    resumableWorkout.map { viewModel.continueCurrentWorkoutButtonTitle(for: $0) }
                                    ?? "Start New Workout"
                                )
                                    .font(.headline)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(canContinueWorkout ? Color.green : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        if let resumableWorkout {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.green)
                                    .font(.subheadline)
                                    .padding(.top, 1)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(WorkoutRow.displayName(for: resumableWorkout))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    Text(viewModel.resumableWorkoutSummary(for: resumableWorkout))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)

                            Button {
                                resumableWorkoutToReplace = resumableWorkout
                                showingStartFreshAlert = true
                            } label: {
                                Label("Start Fresh Instead", systemImage: "plus.circle")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        Button(action: { showingRPTCalculator = true }) {
                            VStack(spacing: 6) {
                                Image(systemName: "function")
                                    .font(.title2)
                                Text("RPT Calculator")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        Button(action: { showingPlateCalculator = true }) {
                            VStack(spacing: 6) {
                                Image(systemName: "scalemass")
                                    .font(.title2)
                                Text("Plate Calculator")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.indigo)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    if let stats = viewModel.userStats {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Progress Snapshot")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)

                            if stats.totalWorkouts > 0 {
                                let weeklyWorkoutCount = viewModel.weeklyWorkoutCount()
                                let weeklyProgress = viewModel.weeklyProgress(forWorkoutCount: weeklyWorkoutCount)

                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 12) {
                                        HomeStatTile(
                                            icon: "figure.strengthtraining.traditional",
                                            title: "Workouts",
                                            value: "\(stats.totalWorkouts)",
                                            subtitle: "logged",
                                            tint: .blue
                                        )

                                        HomeStatTile(
                                            icon: "scalemass",
                                            title: viewModel.lifetimeWorkMetricTitle,
                                            value: viewModel.lifetimeWorkMetricValue,
                                            subtitle: viewModel.lifetimeWorkMetricSubtitle,
                                            tint: .purple
                                        )

                                        HomeStatTile(
                                            icon: "flame.fill",
                                            title: "Streak",
                                            value: "\(stats.workoutStreak)",
                                            subtitle: stats.workoutStreak == 1 ? "day" : "days",
                                            tint: .orange
                                        )
                                    }

                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(alignment: .firstTextBaseline) {
                                            Text("Last 7 Days")
                                                .font(.headline)

                                            Spacer()

                                            Text(viewModel.weeklyProgressSummary(forWorkoutCount: weeklyWorkoutCount))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.secondary)
                                        }

                                        ProgressView(value: weeklyProgress)
                                            .tint(.green)

                                        Text(viewModel.weeklyProgressSubtitle(forWorkoutCount: weeklyWorkoutCount))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal)
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.title3)
                                            .foregroundColor(.blue)

                                        Text("No workouts logged yet")
                                            .font(.headline)
                                    }

                                    Text("Finish your first workout to start a streak and unlock lifetime progress on Home.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Recent workouts section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Workouts")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)

                        if viewModel.recentWorkouts.isEmpty {
                            let emptyState = viewModel.recentWorkoutsEmptyState(activeWorkout: activeWorkoutBinding)

                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Image(systemName: "clock.badge.exclamationmark")
                                        .font(.title3)
                                        .foregroundColor(.orange)

                                    Text(emptyState.title)
                                        .font(.headline)
                                }

                                Text(emptyState.subtitle)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        } else {
                            ForEach(viewModel.recentWorkouts) { workout in
                                Button(action: {
                                    selectedWorkout = workout
                                }) {
                                    WorkoutRow(
                                        workout: workout,
                                        resolvedTemplateName: sourceTemplate(for: workout)?.name
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                                .swipeActions(edge: .trailing) {
                                    if protectedResumableWorkout() != nil,
                                       viewModel.shouldOfferFollowUpRecovery(for: workout) {
                                        Button {
                                            workoutToStartFollowUp = workout
                                            showingFollowUpRecoveryAlert = true
                                        } label: {
                                            Label(viewModel.followUpWorkoutButtonTitle(for: workout), systemImage: "arrow.triangle.2.circlepath")
                                        }
                                        .tint(.green)
                                    } else if viewModel.canStartFollowUpWorkout(from: workout, activeWorkout: activeWorkoutBinding) {
                                        Button {
                                            startFollowUpWorkout(from: workout)
                                        } label: {
                                            Label(viewModel.followUpWorkoutButtonTitle(for: workout), systemImage: "arrow.triangle.2.circlepath")
                                        }
                                        .tint(.green)
                                    }

                                    Button {
                                        copyWorkoutSummary(workout)
                                    } label: {
                                        Label(viewModel.copySummaryButtonTitle(for: workout), systemImage: "doc.on.doc")
                                    }
                                    .tint(.indigo)

                                    if let sourceTemplate = sourceTemplate(for: workout) {
                                        Button {
                                            if protectedResumableWorkout() != nil {
                                                templateToStartFromHistory = sourceTemplate
                                                showingTemplateStartRecoveryAlert = true
                                            } else {
                                                startWorkout(from: sourceTemplate)
                                            }
                                        } label: {
                                            Label(templateViewModel.startTemplateButtonTitle(for: sourceTemplate), systemImage: "play.fill")
                                        }
                                        .tint(.green)

                                        if let sourceTemplateQuickActionTitle = viewModel.sourceTemplateQuickActionTitle(
                                            for: workout,
                                            resolvedTemplateName: sourceTemplate.name
                                        ) {
                                            Button {
                                                selectedSourceTemplate = sourceTemplate
                                            } label: {
                                                Label(sourceTemplateQuickActionTitle, systemImage: "square.on.square")
                                            }
                                            .tint(.purple)
                                        }
                                    }

                                    Button {
                                        selectedWorkout = workout
                                    } label: {
                                        Label(viewModel.reviewWorkoutButtonTitle(for: workout), systemImage: "info.circle")
                                    }
                                    .tint(.blue)

                                    Button(role: .destructive) {
                                        workoutToDelete = workout
                                        showingDeleteWorkoutAlert = true
                                    } label: {
                                        Label(viewModel.deleteRecentWorkoutButtonTitle(for: workout), systemImage: "trash")
                                    }
                                }
                            }

                            if viewModel.shouldShowSingleRecentWorkoutQuickActions(recentWorkoutCount: viewModel.recentWorkouts.count),
                               let matchedWorkout = viewModel.recentWorkouts.first {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Quick Actions")
                                        .font(.headline)

                                    if let resumableWorkout = protectedResumableWorkout(),
                                       viewModel.shouldOfferFollowUpRecovery(for: matchedWorkout) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(viewModel.activeWorkoutBlocksFollowUpMessage(for: resumableWorkout, startingFrom: matchedWorkout))
                                                .font(.caption)
                                                .foregroundColor(.secondary)

                                            Button {
                                                openStartedWorkout(resumableWorkout)
                                            } label: {
                                                Label(viewModel.continueCurrentWorkoutButtonTitle(for: resumableWorkout), systemImage: "arrow.clockwise.circle.fill")
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.green)

                                            Button {
                                                saveActiveWorkoutAndStartFollowUp(from: matchedWorkout)
                                            } label: {
                                                Label(viewModel.saveAndStartFollowUpButtonTitle(for: matchedWorkout), systemImage: "square.and.arrow.down")
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .buttonStyle(.bordered)

                                            Button(role: .destructive) {
                                                workoutToDiscardAndStartFollowUp = matchedWorkout
                                                showingDiscardAndStartFollowUpConfirmation = true
                                            } label: {
                                                Label(viewModel.discardAndStartFollowUpButtonTitle(for: matchedWorkout), systemImage: "trash")
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    } else if viewModel.canStartFollowUpWorkout(from: matchedWorkout, activeWorkout: activeWorkoutBinding) {
                                        Button {
                                            startFollowUpWorkout(from: matchedWorkout)
                                        } label: {
                                            Label("Start Follow-Up from “\(WorkoutRow.displayName(for: matchedWorkout))”", systemImage: "arrow.triangle.2.circlepath")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.green)
                                    }

                                    Button {
                                        copyWorkoutSummary(matchedWorkout)
                                    } label: {
                                        Label(viewModel.copySummaryButtonTitle(for: matchedWorkout), systemImage: "doc.on.doc")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.indigo)

                                    if let sourceTemplate = sourceTemplate(for: matchedWorkout) {
                                        Button {
                                            if protectedResumableWorkout() != nil {
                                                templateToStartFromHistory = sourceTemplate
                                                showingTemplateStartRecoveryAlert = true
                                            } else {
                                                startWorkout(from: sourceTemplate)
                                            }
                                        } label: {
                                            Label(templateViewModel.startTemplateButtonTitle(for: sourceTemplate), systemImage: "play.fill")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.green)

                                        if let sourceTemplateQuickActionTitle = viewModel.sourceTemplateQuickActionTitle(
                                            for: matchedWorkout,
                                            resolvedTemplateName: sourceTemplate.name
                                        ) {
                                            Button {
                                                selectedSourceTemplate = sourceTemplate
                                            } label: {
                                                Label(sourceTemplateQuickActionTitle, systemImage: "square.on.square")
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }

                                    Button {
                                        selectedWorkout = matchedWorkout
                                    } label: {
                                        Label(viewModel.reviewWorkoutButtonTitle(for: matchedWorkout), systemImage: "info.circle")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.blue)

                                    Button(role: .destructive) {
                                        workoutToDelete = matchedWorkout
                                        showingDeleteWorkoutAlert = true
                                    } label: {
                                        Label(viewModel.deleteRecentWorkoutButtonTitle(for: matchedWorkout), systemImage: "trash")
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
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .sheet(isPresented: $showingRPTCalculator) {
                RPTCalculatorView()
            }
            .sheet(isPresented: $showingPlateCalculator) {
                PlateCalculatorView()
            }
            .navigationDestination(item: $selectedWorkout) { workout in
                WorkoutDetailView(
                    workout: workout,
                    activeWorkoutBinding: $activeWorkoutBinding,
                    showActiveWorkoutSheet: $showActiveWorkoutSheet
                )
            }
            .navigationDestination(item: $selectedSourceTemplate) { template in
                TemplateDetailView(
                    template: template,
                    onStartWorkout: { openStartedWorkout($0) },
                    onEditTemplate: nil,
                    onDuplicateTemplate: nil,
                    onResumeActiveWorkout: protectedResumableWorkout() == nil ? nil : {
                        guard let activeWorkout = protectedResumableWorkout() else { return }
                        activeWorkoutBinding = activeWorkout
                        showActiveWorkoutSheet = true
                    },
                    onSaveActiveWorkoutAndOpenTemplate: protectedResumableWorkout() == nil ? nil : {
                        saveActiveWorkoutAndOpenTemplate(template)
                    },
                    onDiscardActiveWorkoutAndOpenTemplate: protectedResumableWorkout() == nil ? nil : {
                        discardActiveWorkoutAndOpenTemplate(template)
                    },
                    activeWorkoutBlockMessage: sourceTemplateBlockMessage(for: template)
                )
            }
            .alert(startFreshAlertTitle, isPresented: $showingStartFreshAlert) {
                Button(startFreshSaveButtonTitle) {
                    saveCurrentWorkoutAndStartFresh()
                }

                Button(startFreshDiscardButtonTitle, role: .destructive) {
                    discardCurrentWorkoutAndStartFresh()
                }

                Button(
                    resumableWorkoutToReplace.map { viewModel.continueCurrentWorkoutButtonTitle(for: $0) }
                    ?? "Continue Current Workout"
                ) {
                    if let resumableWorkoutToReplace {
                        activeWorkoutBinding = resumableWorkoutToReplace
                        showActiveWorkoutSheet = true
                    }
                    resumableWorkoutToReplace = nil
                }

                Button("Cancel", role: .cancel) {
                    resumableWorkoutToReplace = nil
                }
            } message: {
                if let resumableWorkoutToReplace {
                    Text(viewModel.startFreshWorkoutMessage(for: resumableWorkoutToReplace))
                }
            }
            .alert(deleteWorkoutAlertTitle, isPresented: $showingDeleteWorkoutAlert) {
                Button(deleteWorkoutButtonTitle, role: .destructive) {
                    deleteSelectedWorkout()
                }

                Button("Cancel", role: .cancel) {
                    workoutToDelete = nil
                }
            } message: {
                if let workoutToDelete {
                    Text(viewModel.deleteRecentWorkoutMessage(for: workoutToDelete))
                }
            }
            .alert(followUpRecoveryAlertTitle, isPresented: $showingFollowUpRecoveryAlert) {
                Button(
                    protectedResumableWorkout().map { viewModel.continueCurrentWorkoutButtonTitle(for: $0) }
                    ?? "Continue Current Workout"
                ) {
                    if let resumableWorkout = protectedResumableWorkout() {
                        openStartedWorkout(resumableWorkout)
                    }
                    workoutToStartFollowUp = nil
                }

                if let workoutToStartFollowUp {
                    Button(viewModel.saveAndStartFollowUpButtonTitle(for: workoutToStartFollowUp)) {
                        saveActiveWorkoutAndStartFollowUp(from: workoutToStartFollowUp)
                        self.workoutToStartFollowUp = nil
                    }

                    Button(viewModel.discardAndStartFollowUpButtonTitle(for: workoutToStartFollowUp), role: .destructive) {
                        workoutToDiscardAndStartFollowUp = workoutToStartFollowUp
                        showingDiscardAndStartFollowUpConfirmation = true
                    }
                }

                Button("Cancel", role: .cancel) {
                    workoutToStartFollowUp = nil
                }
            } message: {
                if let workoutToStartFollowUp,
                   let resumableWorkout = protectedResumableWorkout() {
                    Text(viewModel.activeWorkoutBlocksFollowUpMessage(for: resumableWorkout, startingFrom: workoutToStartFollowUp))
                }
            }
            .alert(
                Self.discardCurrentWorkoutAndStartFollowUpAlertTitle(for: workoutToDiscardAndStartFollowUp),
                isPresented: $showingDiscardAndStartFollowUpConfirmation,
                presenting: workoutToDiscardAndStartFollowUp
            ) { workout in
                Button(viewModel.discardAndStartFollowUpButtonTitle(for: workout), role: .destructive) {
                    discardActiveWorkoutAndStartFollowUp(from: workout)
                    workoutToDiscardAndStartFollowUp = nil
                    workoutToStartFollowUp = nil
                }

                Button("Keep Current Workout", role: .cancel) {
                    workoutToDiscardAndStartFollowUp = nil
                    workoutToStartFollowUp = nil
                }
            } message: { workout in
                Text(Self.discardCurrentWorkoutAndStartFollowUpAlertMessage(for: workout))
            }
            .alert(templateStartRecoveryAlertTitle, isPresented: $showingTemplateStartRecoveryAlert) {
                Button(
                    protectedResumableWorkout().map { viewModel.continueCurrentWorkoutButtonTitle(for: $0) }
                    ?? "Continue Current Workout"
                ) {
                    if let resumableWorkout = protectedResumableWorkout() {
                        openStartedWorkout(resumableWorkout)
                    }
                    templateToStartFromHistory = nil
                }

                if let templateToStartFromHistory {
                    Button(templateViewModel.saveAndStartTemplateButtonTitle(for: templateToStartFromHistory)) {
                        saveActiveWorkoutAndOpenTemplate(templateToStartFromHistory)
                        self.templateToStartFromHistory = nil
                    }

                    Button(templateViewModel.discardAndStartTemplateButtonTitle(for: templateToStartFromHistory), role: .destructive) {
                        templateToDiscardAndStart = templateToStartFromHistory
                        showingDiscardAndStartTemplateConfirmation = true
                    }
                }

                Button("Cancel", role: .cancel) {
                    templateToStartFromHistory = nil
                }
            } message: {
                if let templateToStartFromHistory {
                    Text(sourceTemplateBlockMessage(for: templateToStartFromHistory) ?? "You already have a workout in progress. Continue it, save it for later, or discard it before starting this template.")
                }
            }
            .alert("Workout Summary Copied", isPresented: $showingCopySummaryAlert) {
                Button("OK", role: .cancel) {
                    copiedWorkoutName = nil
                }
            } message: {
                Text(copySummaryMessage)
            }
            .alert(
                Self.discardCurrentWorkoutAndStartTemplateAlertTitle(for: templateToDiscardAndStart),
                isPresented: $showingDiscardAndStartTemplateConfirmation,
                presenting: templateToDiscardAndStart
            ) { template in
                Button(templateViewModel.discardAndStartTemplateButtonTitle(for: template), role: .destructive) {
                    discardActiveWorkoutAndOpenTemplate(template)
                    templateToDiscardAndStart = nil
                    templateToStartFromHistory = nil
                }

                Button("Keep Current Workout", role: .cancel) {
                    templateToDiscardAndStart = nil
                    templateToStartFromHistory = nil
                }
            } message: { template in
                Text(Self.discardCurrentWorkoutAndStartTemplateAlertMessage(for: template))
            }
            .alert(currentFailureTitle, isPresented: Binding(
                get: { currentFailureMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        clearFailureMessages()
                    }
                }
            )) {
                Button("OK", role: .cancel) {
                    clearFailureMessages()
                }
            } message: {
                Text(currentFailureMessage ?? "")
            }
            .onAppear {
                reloadHomeState()
            }
            .onChange(of: showActiveWorkoutSheet) { oldValue, newValue in
                guard viewModel.shouldReloadAfterWorkoutSheetPresentationChange(from: oldValue, to: newValue) else {
                    return
                }

                reloadHomeState()
            }
        }
    }

    private func reloadHomeState() {
        viewModel.loadRecentWorkouts()
        activeWorkoutBinding = viewModel.resolvedActiveWorkoutBinding(
            currentBinding: activeWorkoutBinding,
            storedWorkout: viewModel.currentWorkout
        )
    }

    private var currentFailureTitle: String {
        startFreshFailureTitle ?? viewModel.startWorkoutFailureAlertTitle
    }

    private var currentFailureMessage: String? {
        startFreshFailureMessage ?? viewModel.startWorkoutFailureMessage
    }

    private func sourceTemplate(for workout: Workout) -> WorkoutTemplate? {
        templateManager.sourceTemplate(for: workout)
    }

    private func protectedResumableWorkout() -> Workout? {
        workoutStateManager.resolvedResumableWorkout(
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

    private var copySummaryMessage: String {
        let workoutName = copiedWorkoutName ?? "Workout"
        return "Copied the summary for \(workoutName) so it’s ready to paste anywhere you need it."
    }

    private func clearFailureMessages() {
        startFreshFailureTitle = nil
        startFreshFailureMessage = nil
        viewModel.clearStartWorkoutFailure()
    }

    private func startFreshWorkout() {
        guard viewModel.startNewWorkout() else {
            resumableWorkoutToReplace = nil
            return
        }

        workoutStateManager.clearDiscardedState()
        activeWorkoutBinding = viewModel.currentWorkout
        showActiveWorkoutSheet = true
        resumableWorkoutToReplace = nil
    }

    private func startFollowUpWorkout(from workout: Workout) {
        guard viewModel.startFollowUpWorkout(from: workout) else {
            return
        }

        workoutStateManager.clearDiscardedState()
        activeWorkoutBinding = viewModel.currentWorkout
        showActiveWorkoutSheet = true
    }

    private func saveCurrentWorkoutAndStartFresh() {
        guard let resumableWorkoutToReplace else { return }

        guard viewModel.persistWorkoutForFreshStart(
            resumableWorkoutToReplace,
            action: .saveForLater,
            persist: { WorkoutManager.shared.saveWorkoutSafely($0) }
        ) else {
            startFreshFailureTitle = viewModel.startFreshFailureAlertTitle(for: .saveForLater)
            startFreshFailureMessage = viewModel.startFreshFailureMessage(for: .saveForLater)
            return
        }

        activeWorkoutBinding = nil
        startFreshWorkout()
    }

    private func discardCurrentWorkoutAndStartFresh() {
        guard let resumableWorkoutToReplace else { return }

        guard viewModel.persistWorkoutForFreshStart(
            resumableWorkoutToReplace,
            action: .discard,
            persist: { WorkoutManager.shared.deleteWorkoutSafely($0) }
        ) else {
            startFreshFailureTitle = viewModel.startFreshFailureAlertTitle(for: .discard)
            startFreshFailureMessage = viewModel.startFreshFailureMessage(for: .discard)
            return
        }

        activeWorkoutBinding = nil
        startFreshWorkout()
    }

    private func saveActiveWorkoutAndStartFollowUp(from workout: Workout) {
        guard let activeWorkout = protectedResumableWorkout() else { return }

        switch viewModel.startFollowUpAfterPersistingActiveWorkout(
            activeWorkout,
            action: .saveForLater,
            from: workout,
            persist: { WorkoutManager.shared.saveWorkoutSafely($0) }
        ) {
        case .success(let startedWorkout):
            openStartedWorkout(startedWorkout)
        case .failure(let message):
            viewModel.presentStartWorkoutFailure(
                message,
                title: viewModel.activeWorkoutPersistenceFailureAlertTitle(
                    for: .saveForLater,
                    startingFollowUpFrom: workout
                )
            )
        }
    }

    private func discardActiveWorkoutAndStartFollowUp(from workout: Workout) {
        guard let activeWorkout = protectedResumableWorkout() else { return }

        switch viewModel.startFollowUpAfterPersistingActiveWorkout(
            activeWorkout,
            action: .discard,
            from: workout,
            persist: { WorkoutManager.shared.deleteWorkoutSafely($0) }
        ) {
        case .success(let startedWorkout):
            openStartedWorkout(startedWorkout)
        case .failure(let message):
            viewModel.presentStartWorkoutFailure(
                message,
                title: viewModel.activeWorkoutPersistenceFailureAlertTitle(
                    for: .discard,
                    startingFollowUpFrom: workout
                )
            )
        }
    }

    private func startWorkout(from template: WorkoutTemplate) {
        guard let startedWorkout = templateViewModel.createWorkoutFromTemplate(template) else {
            viewModel.presentStartWorkoutFailure(
                "Your template workout could not be started right now. Please try again.",
                title: viewModel.startTemplateFailureAlertTitle(for: template)
            )
            return
        }

        openStartedWorkout(startedWorkout)
    }

    private func copyWorkoutSummary(_ workout: Workout) {
        UIPasteboard.general.string = workout.generateFormattedSummary()
        copiedWorkoutName = WorkoutRow.displayName(for: workout)
        showingCopySummaryAlert = true
    }

    private func deleteSelectedWorkout() {
        guard let workoutToDelete else { return }

        guard viewModel.deleteRecentWorkout(workoutToDelete) else {
            self.workoutToDelete = nil
            return
        }

        if selectedWorkout?.id == workoutToDelete.id {
            selectedWorkout = nil
        }

        self.workoutToDelete = nil
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
            selectedSourceTemplate = nil
            activeWorkoutBinding = startedWorkout
            showActiveWorkoutSheet = true
        case .failure(let message):
            startFreshFailureTitle = templateViewModel.activeWorkoutPersistenceFailureAlertTitle(
                for: .saveForLater,
                opening: template
            )
            startFreshFailureMessage = message
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
            selectedSourceTemplate = nil
            activeWorkoutBinding = startedWorkout
            showActiveWorkoutSheet = true
        case .failure(let message):
            startFreshFailureTitle = templateViewModel.activeWorkoutPersistenceFailureAlertTitle(
                for: .discard,
                opening: template
            )
            startFreshFailureMessage = message
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .modelContainer(for: [Exercise.self, Workout.self, ExerciseSet.self, WorkoutTemplate.self, UserSettings.self, User.self])
    }
}

// Preview with active workout
private struct HomeStatTile: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(tint)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
            }

            Text(value)
                .font(.title3.monospacedDigit())
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview("With Active Workout") {
    let workout = Workout(date: Date(), name: "Active Workout")
    return NavigationStack {
        HomeView(
            activeWorkoutBinding: .constant(workout),
            showActiveWorkoutSheet: .constant(false)
        )
        .modelContainer(for: [Workout.self, ExerciseSet.self, Exercise.self])
    }
}
