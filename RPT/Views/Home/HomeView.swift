//
//  HomeView.swift
//  RPT
//
//  The training dashboard: resume or start a workout, week-at-a-glance
//  goal ring, recent sessions, and quick tools.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: WorkoutSession
    @StateObject private var viewModel = HomeViewModel()

    @State private var showingReplaceDialog = false
    @State private var showingRPTCalculator = false
    @State private var showingPlateCalculator = false
    @State private var workoutToDelete: Workout?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.sectionSpacing) {
                    heroCard
                    weekCard

                    if !viewModel.recentWorkouts.isEmpty {
                        recentSection
                    }

                    toolsSection
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 24)
            }
            .background(Theme.screenBackground)
            .navigationTitle("RPT")
            .onAppear {
                session.restoreResumableWorkout()
                viewModel.refresh()
            }
            .confirmationDialog(
                "Workout in Progress",
                isPresented: $showingReplaceDialog,
                titleVisibility: .visible
            ) {
                Button("Continue Current Workout") {
                    session.openCurrent()
                }
                Button("Save Current & Start New") {
                    saveCurrentAndStartNew()
                }
                Button("Discard Current & Start New", role: .destructive) {
                    discardCurrentAndStartNew()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(replaceDialogMessage)
            }
            .alert("Couldn’t Start Workout", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
            .alert(item: $workoutToDelete) { workout in
                Alert(
                    title: Text("Delete This Workout?"),
                    message: Text("This permanently removes the session and its logged sets from your history."),
                    primaryButton: .destructive(Text("Delete")) {
                        if !viewModel.deleteWorkout(workout) {
                            errorMessage = "Couldn’t delete this workout. Please try again."
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showingRPTCalculator) {
                RPTCalculatorView()
            }
            .sheet(isPresented: $showingPlateCalculator) {
                PlateCalculatorView()
            }
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroCard: some View {
        if let workout = session.resumableWorkout {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PillTag(text: "In Progress", tint: Theme.amber, icon: "bolt.fill")
                    Spacer()
                    Text(workout.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(WorkoutNameFormatter.displayName(for: workout))
                    .font(.title2.weight(.bold))
                    .lineLimit(2)

                Text(activeWorkoutSummary(workout))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    session.openCurrent()
                } label: {
                    Label("Continue Workout", systemImage: "play.fill")
                }
                .buttonStyle(BrandButtonStyle())

                Button("Start a Different Workout") {
                    showingReplaceDialog = true
                }
                .buttonStyle(SecondaryCapsuleButtonStyle(fullWidth: true))
            }
            .rptCard()
        } else {
            VStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.brandGradient)

                Text("Ready to train?")
                    .font(.title2.weight(.bold))

                Text("Start fresh or launch one of your templates.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    startNewWorkout()
                } label: {
                    Label("Start Workout", systemImage: "plus")
                }
                .buttonStyle(BrandButtonStyle())
            }
            .frame(maxWidth: .infinity)
            .rptCard()
        }
    }

    // MARK: - Week at a Glance

    private var weekCard: some View {
        HStack(spacing: 20) {
            ZStack {
                ProgressRing(progress: viewModel.weeklyGoalProgress, lineWidth: 9)
                    .frame(width: 76, height: 76)

                VStack(spacing: 0) {
                    Text("\(viewModel.workoutsThisWeek)")
                        .font(Theme.statFont(size: 24))
                    Text("of \(viewModel.weeklyGoal)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("This Week")
                    .font(.headline)

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.formattedVolume(viewModel.volumeThisWeek))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                        Text("Volume")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.amber)
                            Text("\(viewModel.workoutStreak)")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                        Text("Day Streak")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(weekEncouragement)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .rptCard()
    }

    private var weekEncouragement: String {
        let remaining = viewModel.weeklyGoal - viewModel.workoutsThisWeek
        if remaining <= 0 {
            return "Weekly goal hit — outstanding."
        }
        return remaining == 1 ? "1 workout to hit your goal." : "\(remaining) workouts to hit your goal."
    }

    // MARK: - Recent Workouts

    private var recentSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Recent Workouts")

            ForEach(viewModel.recentWorkouts) { workout in
                NavigationLink {
                    WorkoutDetailView(workout: workout)
                } label: {
                    WorkoutCard(workout: workout)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        workoutToDelete = workout
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Tools

    private var toolsSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Tools")

            HStack(spacing: 12) {
                ToolButton(
                    title: "RPT Calculator",
                    subtitle: "Plan your drops",
                    icon: "arrow.down.right.circle.fill"
                ) {
                    showingRPTCalculator = true
                }

                ToolButton(
                    title: "Plate Math",
                    subtitle: "Load the bar",
                    icon: "circle.circle.fill"
                ) {
                    showingPlateCalculator = true
                }
            }
        }
    }

    // MARK: - Actions

    private var replaceDialogMessage: String {
        guard let workout = session.resumableWorkout else {
            return "You already have a workout in progress."
        }

        return "“\(WorkoutNameFormatter.displayName(for: workout))” is in progress. Save it for later or discard it before starting a new workout."
    }

    private func startNewWorkout() {
        if session.resumableWorkout != nil {
            showingReplaceDialog = true
            return
        }

        if !session.startEmptyWorkout() {
            errorMessage = "Couldn’t create a new workout. Please try again."
        }
    }

    private func saveCurrentAndStartNew() {
        guard session.saveCurrentForLater() else {
            errorMessage = "Couldn’t save the current workout. Keep it open, then try again."
            return
        }

        if !session.startEmptyWorkout() {
            errorMessage = "Couldn’t create a new workout. Please try again."
        }
    }

    private func discardCurrentAndStartNew() {
        guard session.discardCurrent() else {
            errorMessage = "Couldn’t discard the current workout. Keep it open, then try again."
            return
        }

        if !session.startEmptyWorkout() {
            errorMessage = "Couldn’t create a new workout. Please try again."
        }
    }

    private func activeWorkoutSummary(_ workout: Workout) -> String {
        let exerciseCount = workout.exerciseCount
        guard exerciseCount > 0 else {
            return "No exercises yet — add your first movement."
        }

        let loggedSets = workout.sets.filter(\.isCompletedLoggedSet).count
        let exercisePart = exerciseCount == 1 ? "1 exercise" : "\(exerciseCount) exercises"
        let setsPart = loggedSets == 1 ? "1 logged set" : "\(loggedSets) logged sets"
        return "\(exercisePart) • \(setsPart)"
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

// MARK: - Tool Button

private struct ToolButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.brandGradient)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .rptCard(padding: 14)
        }
        .buttonStyle(.plain)
    }
}
