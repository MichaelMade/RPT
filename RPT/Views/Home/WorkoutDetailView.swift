//
//  WorkoutDetailView.swift
//  RPT
//
//  Read-only review of a saved workout with per-exercise breakdown,
//  follow-up creation, share, and delete.
//

import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject private var session: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var purchaseManager = StoreKitPurchaseManager.shared

    let workout: Workout

    @State private var showingDeleteConfirmation = false
    @State private var showingFollowUpBlockedDialog = false
    @State private var showingUpgrade = false
    @State private var errorMessage: String?
    @State private var savedTemplateName: String?

    private let workoutManager = WorkoutManager.shared
    private let templateManager = TemplateManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.sectionSpacing) {
                summaryCard
                exerciseBreakdown

                if !workout.notes.isEmpty {
                    notesCard
                }

                if workout.isCompleted {
                    followUpCard
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 24)
        }
        .background(Theme.screenBackground)
        .navigationTitle(WorkoutNameFormatter.displayName(for: workout))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(item: workout.generateFormattedSummary()) {
                        Label("Share Summary", systemImage: "square.and.arrow.up")
                    }

                    if !WorkoutTemplateBuilder.templateExercises(from: workout).isEmpty {
                        Button {
                            saveAsTemplate()
                        } label: {
                            Label("Save as Template", systemImage: "square.grid.2x2")
                        }
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Workout options")
            }
        }
        .confirmationDialog(
            "Delete This Workout?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Workout", role: .destructive) {
                deleteWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the session and its logged sets from your history.")
        }
        .confirmationDialog(
            "Workout in Progress",
            isPresented: $showingFollowUpBlockedDialog,
            titleVisibility: .visible
        ) {
            Button("Save Current & Start Follow-Up") {
                if session.saveCurrentForLater() {
                    startFollowUp()
                } else {
                    errorMessage = "Couldn’t save the current workout. Keep it open, then try again."
                }
            }
            Button("Discard Current & Start Follow-Up", role: .destructive) {
                if session.discardCurrent() {
                    startFollowUp()
                } else {
                    errorMessage = "Couldn’t discard the current workout. Keep it open, then try again."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Finish, save, or discard your current workout before starting a follow-up.")
        }
        .alert("Something Went Wrong", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
        .alert("Template Saved", isPresented: savedTemplateBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("“\(savedTemplateName ?? "Template")” is in your Templates tab, seeded with this session's sets and reps.")
        }
        .sheet(isPresented: $showingUpgrade) {
            NavigationStack {
                UpgradeView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showingUpgrade = false }
                        }
                    }
            }
        }
        .task {
            await purchaseManager.start()
        }
    }

    // MARK: - Save as Template

    private func saveAsTemplate() {
        let exercises = WorkoutTemplateBuilder.templateExercises(from: workout)
        guard !exercises.isEmpty else {
            errorMessage = "This workout has no sets to turn into a template."
            return
        }

        guard MonetizationPlan.canCreateTemplate(
            existingCount: templateManager.fetchAllTemplates().count,
            isUnlocked: purchaseManager.isUnlocked
        ) else {
            showingUpgrade = true
            return
        }

        let templateName = templateManager.availableTemplateName(
            basedOn: WorkoutNameFormatter.displayName(for: workout)
        )

        let result = templateManager.createTemplate(
            name: templateName,
            exercises: exercises,
            notes: workout.notes
        )

        if result == .success {
            savedTemplateName = templateName
        } else {
            errorMessage = result.alertMessage
        }
    }

    private var savedTemplateBinding: Binding<Bool> {
        Binding(
            get: { savedTemplateName != nil },
            set: { if !$0 { savedTemplateName = nil } }
        )
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.date, format: .dateTime.weekday(.wide).month().day().year())
                        .font(.subheadline.weight(.semibold))

                    if let templateName = templateOriginName {
                        PillTag(text: templateName, tint: Theme.info, icon: "square.grid.2x2")
                    }
                }

                Spacer()

                if workout.isCompleted {
                    PillTag(text: "Completed", tint: Theme.success, icon: "checkmark")
                } else {
                    PillTag(text: "Draft", tint: Theme.amber, icon: "pencil")
                }
            }

            HStack(spacing: 10) {
                summaryMetric(
                    value: "\(workout.visibleExerciseCount)",
                    label: "Exercises"
                )
                summaryMetric(
                    value: "\(workout.visibleSetCount)",
                    label: "Sets"
                )
                summaryMetric(
                    value: workout.hasPreferredWorkMetric ? workout.preferredWorkMetricValue : "—",
                    label: workout.preferredWorkMetricTitle
                )
                if workout.isCompleted, workout.duration > 0 {
                    summaryMetric(
                        value: workout.formattedDurationForSummary(),
                        label: "Duration"
                    )
                }
            }
        }
        .rptCard()
    }

    private func summaryMetric(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var templateOriginName: String? {
        guard let raw = workout.startedFromTemplate else { return nil }
        let collapsed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.isEmpty ? nil : String(collapsed.prefix(80))
    }

    // MARK: - Exercise Breakdown

    private var exerciseBreakdown: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Exercises")

            if workout.orderedExerciseGroups.isEmpty {
                EmptyStateCard(
                    icon: "dumbbell",
                    title: "No Exercises",
                    message: "This session doesn’t contain any exercises."
                )
            } else {
                ForEach(workout.orderedExerciseGroups, id: \.exercise.id) { group in
                    exerciseCard(exercise: group.exercise, sets: group.sets)
                }
            }
        }
    }

    private func exerciseCard(exercise: Exercise, sets: [ExerciseSet]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ExerciseIconView(category: exercise.category, size: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.displayName)
                        .font(.subheadline.weight(.semibold))

                    let best = OneRepMax.bestEstimate(in: sets)
                    if best > 0 {
                        Text("Best e1RM: \(OneRepMax.formatted(best))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            VStack(spacing: 6) {
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                    HStack {
                        Text(set.isWarmup ? "W" : "\(workingSetNumber(for: index, in: sets))")
                            .font(.caption.weight(.bold))
                            .frame(width: 24, height: 24)
                            .background(
                                set.isWarmup ? Theme.amber.opacity(0.15) : Theme.accent.opacity(0.12),
                                in: Circle()
                            )
                            .foregroundStyle(set.isWarmup ? Theme.amber : Theme.accent)

                        Text(set.formattedWeightReps)
                            .font(.subheadline)
                            .monospacedDigit()

                        Spacer()

                        if let rpe = set.displayRPE {
                            PillTag(text: "RPE \(rpe)", tint: .secondary)
                        }

                        if set.isCompletedLoggedSet {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(Theme.success)
                        }
                    }
                }
            }
        }
        .rptCard(padding: 14)
    }

    private func workingSetNumber(for index: Int, in sets: [ExerciseSet]) -> Int {
        var count = 0
        for (currentIndex, set) in sets.enumerated() {
            if !set.isWarmup {
                count += 1
            }
            if currentIndex == index {
                break
            }
        }
        return max(1, count)
    }

    // MARK: - Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Notes")
            Text(workout.notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .rptCard()
        }
    }

    // MARK: - Follow-Up

    private var followUpCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Progress From Here", systemImage: "arrow.up.right")
                .font(.headline)

            Text("Start a follow-up session with the same exercises at roughly 2.5% more weight — classic RPT progression.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                requestFollowUp()
            } label: {
                Label("Start Follow-Up Workout", systemImage: "play.fill")
            }
            .buttonStyle(BrandButtonStyle())
        }
        .rptCard()
    }

    private func requestFollowUp() {
        session.restoreResumableWorkout()
        if session.resumableWorkout != nil {
            showingFollowUpBlockedDialog = true
        } else {
            startFollowUp()
        }
    }

    private func startFollowUp() {
        guard let followUp = workoutManager.createFollowUpWorkoutSafely(from: workout) else {
            errorMessage = "Couldn’t create a follow-up. The source workout needs at least one completed working set."
            return
        }

        session.start(followUp)
    }

    private func deleteWorkout() {
        if workoutManager.deleteWorkoutSafely(workout) {
            dismiss()
        } else {
            errorMessage = "Couldn’t delete this workout. Please try again."
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
