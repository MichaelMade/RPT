//
//  ExerciseDetailView.swift
//  RPT
//
//  Everything about one movement: muscles, instructions, e1RM trend,
//  progression target, and complete set history.
//

import SwiftUI
import Charts

struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise
    var onLibraryChanged: (() -> Void)? = nil

    @State private var history: [(workout: Workout, sets: [ExerciseSet])] = []
    @State private var showingEdit = false
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?

    private let workoutManager = WorkoutManager.shared
    private let exerciseManager = ExerciseManager.shared

    /// Completed workouts containing logged working sets of this exercise, newest first.
    private var completedHistory: [(workout: Workout, sets: [ExerciseSet])] {
        history
            .filter { $0.workout.isCompleted }
            .map { (workout: $0.workout, sets: $0.sets.filter(\.isCompletedWorkingSet)) }
            .filter { !$0.sets.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.sectionSpacing) {
                headerCard

                if let progression = progressionNote {
                    progressionCard(progression)
                }

                if e1rmPoints.count >= 2 {
                    trendSection
                }

                historySection
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 24)
        }
        .background(Theme.screenBackground)
        .navigationTitle(exercise.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if exercise.isCustom {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingEdit = true
                        } label: {
                            Label("Edit Exercise", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Exercise", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            ExerciseFormView(mode: .edit(exercise)) {
                onLibraryChanged?()
            }
        }
        .confirmationDialog(
            "Delete \(exercise.displayName)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Exercise", role: .destructive) {
                deleteExercise()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deletionImpactMessage)
        }
        .alert("Couldn’t Delete Exercise", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
        .onAppear {
            history = workoutManager.getWorkoutHistory(for: exercise)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ExerciseIconView(category: exercise.category, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    ExerciseCategoryTag(category: exercise.category)

                    if exercise.isCustom {
                        PillTag(text: "Custom Exercise", tint: Theme.info)
                    }
                }

                Spacer()

                let best = bestE1RM
                if best > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(OneRepMax.formatted(best))
                            .font(Theme.statFont(size: 22))
                        Text("Best e1RM")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !exercise.primaryMuscleGroups.isEmpty || !exercise.secondaryMuscleGroups.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if !exercise.primaryMuscleGroups.isEmpty {
                        muscleRow(title: "Primary", muscles: exercise.primaryMuscleGroups, isPrimary: true)
                    }
                    if !exercise.secondaryMuscleGroups.isEmpty {
                        muscleRow(title: "Secondary", muscles: exercise.secondaryMuscleGroups, isPrimary: false)
                    }
                }
            }

            if !exercise.instructions.isEmpty {
                Text(exercise.instructions)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .rptCard()
    }

    private func muscleRow(title: String, muscles: [MuscleGroup], isPrimary: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            FlowingTags(muscles: muscles, isPrimary: isPrimary)
        }
    }

    // MARK: - Progression

    private var progressionNote: ProgressionSuggestion? {
        guard let lastSession = completedHistory.first,
              let topSet = lastSession.sets.first,
              topSet.weight > 0
        else {
            return nil
        }

        return ProgressionAdvisor.suggestion(lastWeight: topSet.weight, lastReps: topSet.reps)
    }

    private func progressionCard(_ suggestion: ProgressionSuggestion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.title3)
                .foregroundStyle(Theme.amber)

            VStack(alignment: .leading, spacing: 2) {
                Text("Next Session Target")
                    .font(.subheadline.weight(.semibold))
                Text(suggestion.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .rptCard(padding: 14)
    }

    // MARK: - e1RM Trend

    private struct E1RMPoint: Identifiable {
        let date: Date
        let value: Double
        var id: Date { date }
    }

    private var e1rmPoints: [E1RMPoint] {
        completedHistory
            .compactMap { session -> E1RMPoint? in
                let best = OneRepMax.bestEstimate(in: session.sets)
                guard best > 0 else { return nil }
                return E1RMPoint(date: session.workout.date, value: best)
            }
            .sorted { $0.date < $1.date }
    }

    private var bestE1RM: Double {
        e1rmPoints.map(\.value).max() ?? 0
    }

    private var trendSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Strength Trend")

            VStack(alignment: .leading, spacing: 8) {
                Chart(e1rmPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("e1RM", point.value)
                    )
                    .foregroundStyle(Theme.accent)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("e1RM", point.value)
                    )
                    .foregroundStyle(Theme.accentDeep)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 180)

                Text("Estimated one-rep max from your best working set each session.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .rptCard()
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "History")

            if completedHistory.isEmpty {
                EmptyStateCard(
                    icon: "clock",
                    title: "No Sessions Yet",
                    message: "Log this exercise in a workout and your set history will appear here."
                )
            } else {
                ForEach(completedHistory, id: \.workout.id) { session in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(session.workout.date, format: .dateTime.month().day().year())
                                .font(.subheadline.weight(.semibold))

                            Spacer()

                            let best = OneRepMax.bestEstimate(in: session.sets)
                            if best > 0 {
                                Text("e1RM \(OneRepMax.formatted(best))")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ForEach(session.sets) { set in
                            HStack {
                                Text(set.formattedWeightReps)
                                    .font(.subheadline)
                                    .monospacedDigit()

                                Spacer()

                                if let rpe = set.displayRPE {
                                    PillTag(text: "RPE \(rpe)", tint: .secondary)
                                }
                            }
                        }
                    }
                    .rptCard(padding: 14)
                }
            }
        }
    }

    // MARK: - Deletion

    private var deletionImpactMessage: String {
        let impact = exerciseManager.deletionImpact(for: exercise)

        var parts: [String] = []
        if impact.loggedSetCount > 0 {
            parts.append("\(impact.loggedSetCount) logged \(impact.loggedSetCount == 1 ? "set" : "sets") will be removed from your history")
        }
        if impact.draftSetCount > 0 {
            parts.append("\(impact.draftSetCount) draft \(impact.draftSetCount == 1 ? "set" : "sets") will be removed from in-progress workouts")
        }
        if impact.templateCount > 0 {
            parts.append("\(impact.templateCount) \(impact.templateCount == 1 ? "template references" : "templates reference") this exercise")
        }

        guard !parts.isEmpty else {
            return "This custom exercise has no logged history. This cannot be undone."
        }

        return parts.joined(separator: ". ") + ". This cannot be undone."
    }

    private func deleteExercise() {
        let result = exerciseManager.deleteExercise(exercise)
        if result == .success {
            onLibraryChanged?()
            dismiss()
        } else {
            errorMessage = "This exercise could not be deleted right now. Please try again."
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

// MARK: - Flowing Muscle Tags

private struct FlowingTags: View {
    let muscles: [MuscleGroup]
    let isPrimary: Bool

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 6) {
            ForEach(muscles, id: \.self) { muscle in
                PillTag(text: muscle.displayName, tint: isPrimary ? Theme.accent : .secondary)
            }
        }
    }
}
