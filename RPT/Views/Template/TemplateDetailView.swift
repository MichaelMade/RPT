//
//  TemplateDetailView.swift
//  RPT
//
//  Review a saved routine: exercises with set/rep prescriptions, notes,
//  and the start action.
//

import SwiftUI

struct TemplateDetailView: View {
    @EnvironmentObject private var session: WorkoutSession
    @Environment(\.dismiss) private var dismiss

    let template: WorkoutTemplate
    var onChanged: (() -> Void)? = nil

    @State private var showingEdit = false
    @State private var showingDeleteConfirmation = false
    @State private var showingBlockedStartDialog = false
    @State private var errorMessage: String?

    private let templateManager = TemplateManager.shared

    private var missingExercises: [String] {
        templateManager.unavailableExerciseNames(in: template)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.sectionSpacing) {
                if !missingExercises.isEmpty {
                    missingExercisesCard
                }

                exercisesSection

                if !template.notes.isEmpty {
                    notesCard
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 100)
        }
        .background(Theme.screenBackground)
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEdit = true
                    } label: {
                        Label("Edit Template", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Template", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Template options")
            }
        }
        .safeAreaInset(edge: .bottom) {
            startBar
        }
        .sheet(isPresented: $showingEdit) {
            TemplateEditView(mode: .edit(template)) {
                onChanged?()
            }
        }
        .confirmationDialog(
            "Delete “\(template.name)”?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Template", role: .destructive) {
                deleteTemplate()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the template. Your workout history is not affected.")
        }
        .confirmationDialog(
            "Workout in Progress",
            isPresented: $showingBlockedStartDialog,
            titleVisibility: .visible
        ) {
            Button("Save Current & Start Template") {
                resolveBlockedStart(discard: false)
            }
            Button("Discard Current & Start Template", role: .destructive) {
                resolveBlockedStart(discard: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save your current workout for later or discard it before starting “\(template.name)”.")
        }
        .alert("Couldn’t Complete Action", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    // MARK: - Sections

    private var missingExercisesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Some exercises are missing", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.dropOne)

            Text("Not in your library: \(missingExercises.joined(separator: ", ")). Starting this template will skip them.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rptCard(padding: 14)
        .accessibilityElement(children: .combine)
    }

    private var exercisesSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Exercises")

            if template.exercises.isEmpty {
                EmptyStateCard(
                    icon: "dumbbell",
                    title: "No Exercises",
                    message: "Edit this template to add at least one exercise before starting it."
                )
            } else {
                ForEach(template.exercises) { templateExercise in
                    exerciseCard(templateExercise)
                }
            }
        }
    }

    private func exerciseCard(_ templateExercise: TemplateExercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(templateExercise.exerciseName)
                    .font(Theme.titleFont(size: 15))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                Text("\(templateExercise.suggestedSets) \(templateExercise.suggestedSets == 1 ? "set" : "sets")")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(spacing: 6) {
                ForEach(templateExercise.repRanges.sorted(by: { $0.setNumber < $1.setNumber }), id: \.setNumber) { range in
                    HStack {
                        Text(range.setNumber == 1 ? "Top set" : "Back-off \(range.setNumber - 1)")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)

                        Spacer()

                        if range.setNumber > 1, let percentage = range.percentageOfFirstSet {
                            Text("\(Int(percentage * 100))% of top")
                                .font(.system(size: 11))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textTertiary)
                        }

                        Text("\(range.minReps)–\(range.maxReps) reps")
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            if !templateExercise.notes.isEmpty {
                Text(templateExercise.notes)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .italic()
            }
        }
        .rptCard(padding: 14)
    }

    private var notesCard: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Notes")

            Text(template.notes)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .rptCard()
        }
    }

    private var startBar: some View {
        Button {
            requestStart()
        } label: {
            Label(
                missingExercises.isEmpty ? "Start This Template" : "Start Available Exercises",
                systemImage: "play.fill"
            )
        }
        .buttonStyle(BrandButtonStyle())
        .disabled(!templateManager.canStartWorkout(for: template))
        .padding(.horizontal, Theme.screenPadding)
        .padding(.vertical, 10)
        .background(Theme.cardBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
        }
    }

    // MARK: - Actions

    private func requestStart() {
        session.restoreResumableWorkout()

        if session.resumableWorkout != nil {
            showingBlockedStartDialog = true
        } else {
            startTemplate()
        }
    }

    private func resolveBlockedStart(discard: Bool) {
        let cleared = discard ? session.discardCurrent() : session.saveCurrentForLater()
        guard cleared else {
            errorMessage = discard
                ? "Couldn’t discard the current workout. Keep it open, then try again."
                : "Couldn’t save the current workout. Keep it open, then try again."
            return
        }

        startTemplate()
    }

    private func startTemplate() {
        guard let workout = templateManager.createWorkoutFromTemplate(template) else {
            errorMessage = "Couldn’t start this template. Make sure its exercises are still in your library."
            return
        }

        session.start(workout)
    }

    private func deleteTemplate() {
        let result = templateManager.deleteTemplate(template)
        if result == .success {
            onChanged?()
            dismiss()
        } else {
            errorMessage = "Couldn’t delete this template. Please try again."
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
