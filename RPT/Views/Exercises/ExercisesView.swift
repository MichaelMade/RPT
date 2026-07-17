//
//  ExercisesView.swift
//  RPT
//
//  Browsable exercise library: faceted search and filter chips, a
//  "Recently used" shortcut card with last top set + e1RM, and the
//  full movement list as a bordered monogram list.
//

import SwiftData
import SwiftUI

struct ExercisesView: View {
    @EnvironmentObject private var session: WorkoutSession
    @StateObject private var viewModel = ExerciseLibraryViewModel()
    @State private var showingCreateExercise = false
    @State private var recentEntries: [RecentExerciseEntry] = []

    private let workoutManager = WorkoutManager.shared

    var body: some View {
        let filtered = viewModel.filteredExercises

        return NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    pageHeader
                    searchField
                }
                .padding(.horizontal, Theme.screenPadding)

                filterBar(filteredCount: filtered.count)

                if filtered.isEmpty {
                    ScrollView {
                        EmptyStateCard(
                            icon: "magnifyingglass",
                            title: "No Matches",
                            message: viewModel.noMatchesDescription(),
                            actionTitle: "Create Custom Exercise"
                        ) {
                            showingCreateExercise = true
                        }
                        .padding(.horizontal, Theme.screenPadding)
                        .padding(.bottom, 24)
                    }
                    .scrollDismissesKeyboard(.interactively)
                } else {
                    ScrollView {
                        librarySections(filtered)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .background(Theme.screenBackground)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingCreateExercise) {
                ExerciseFormView(mode: .create) {
                    refreshLibrary()
                }
            }
            .onAppear {
                refreshLibrary()
            }
            .onChange(of: session.isPresentingWorkout) { _, presenting in
                // Refresh when the full-screen logger comes down so a
                // just-finished workout shows in "Recently used" immediately.
                if !presenting {
                    refreshLibrary()
                }
            }
        }
    }

    // MARK: - Header & Search

    private var pageHeader: some View {
        HStack {
            Text("Exercises")
                .font(Theme.titleFont(size: 26))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Button {
                showingCreateExercise = true
            } label: {
                Label("Custom", systemImage: "plus")
            }
            .buttonStyle(CompactBrandButtonStyle())
            .accessibilityLabel("Create exercise")
        }
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)

            TextField("Search name, muscle, or \"push\"", text: $viewModel.searchText)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Search exercises")
                .accessibilityHint(ExerciseLibraryViewModel.searchPrompt)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textTertiary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(
            Theme.cardBackground,
            in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    // MARK: - Filter Chips

    private func filterBar(filteredCount: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                let isAllSelected = viewModel.selectedCategory == nil && viewModel.selectedMuscleGroup == nil
                FilterChip(
                    title: chipTitle("All", isSelected: isAllSelected, count: filteredCount),
                    isSelected: isAllSelected
                ) {
                    viewModel.selectedCategory = nil
                    viewModel.selectedMuscleGroup = nil
                }

                ForEach(ExerciseCategory.allCases, id: \.self) { category in
                    let isSelected = viewModel.selectedCategory == category
                    FilterChip(
                        title: chipTitle(category.rawValue.capitalized, isSelected: isSelected, count: filteredCount),
                        isSelected: isSelected
                    ) {
                        viewModel.selectedCategory = isSelected ? nil : category
                    }
                }

                ForEach(MuscleGroup.allCases.filter { $0 != .other }, id: \.self) { muscle in
                    let isSelected = viewModel.selectedMuscleGroup == muscle
                    FilterChip(
                        title: chipTitle(muscle.displayName, isSelected: isSelected, count: filteredCount),
                        isSelected: isSelected
                    ) {
                        viewModel.selectedMuscleGroup = isSelected ? nil : muscle
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.vertical, 10)
        }
    }

    /// The selected facet carries the match count ("All · 48").
    private func chipTitle(_ base: String, isSelected: Bool, count: Int) -> String {
        isSelected ? "\(base) · \(count)" : base
    }

    // MARK: - Sections

    private func librarySections(_ filtered: [Exercise]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !recentEntries.isEmpty && !viewModel.hasActiveFilters {
                Theme.sectionLabel("Recently used")
                    .padding(.horizontal, 2)
                    .padding(.bottom, 6)

                recentlyUsedCard
                    .padding(.bottom, Theme.sectionSpacing)
            }

            Theme.sectionLabel("All exercises")
                .padding(.horizontal, 2)
                .padding(.bottom, 6)

            allExercisesCard(filtered)
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.bottom, 24)
    }

    private var recentlyUsedCard: some View {
        ExerciseListCard(items: recentEntries) { entry in
            NavigationLink {
                ExerciseDetailView(exercise: entry.exercise) {
                    refreshLibrary()
                }
            } label: {
                RecentExerciseRowLabel(entry: entry)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("exercise-row")
        }
    }

    private func allExercisesCard(_ exercises: [Exercise]) -> some View {
        ExerciseListCard(items: exercises) { exercise in
            NavigationLink {
                ExerciseDetailView(exercise: exercise) {
                    refreshLibrary()
                }
            } label: {
                ExerciseListRow(exercise: exercise)
                    .accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("exercise-row")
        }
    }

    // MARK: - Data

    private func refreshLibrary() {
        viewModel.refreshExercises()
        refreshRecentlyUsed()
    }

    /// Distinct exercises from the most recent completed workouts, capped
    /// at three, each carrying its last top set and e1RM when available.
    private func refreshRecentlyUsed() {
        let completedWorkouts = workoutManager.getRecentWorkouts(limit: 20).filter(\.isCompleted)

        var seen: Set<PersistentIdentifier> = []
        var entries: [RecentExerciseEntry] = []

        outer: for workout in completedWorkouts {
            for group in workout.orderedExerciseGroups
            where group.sets.contains(where: \.isCompletedWorkingSet) {
                guard seen.insert(group.exercise.id).inserted else { continue }

                entries.append(recentEntry(for: group.exercise))

                if entries.count == 3 { break outer }
            }
        }

        recentEntries = entries
    }

    private func recentEntry(for exercise: Exercise) -> RecentExerciseEntry {
        let sessions = workoutManager.getWorkoutHistory(for: exercise)
            .filter { $0.workout.isCompleted }
            .map { (workout: $0.workout, sets: $0.sets.filter(\.isCompletedWorkingSet)) }
            .filter { !$0.sets.isEmpty }

        guard let lastSession = sessions.first,
              let topSet = lastSession.sets.max(by: { ($0.weight, $0.reps) < ($1.weight, $1.reps) }) else {
            return RecentExerciseEntry(exercise: exercise, topSetText: nil, e1RMValue: nil, isPR: false)
        }

        let topSetText: String
        if topSet.weight == 0 && exercise.category == .bodyweight {
            topSetText = "BW×\(topSet.reps)"
        } else {
            topSetText = "\(topSet.weight)×\(topSet.reps)"
        }

        let lastBest = OneRepMax.bestEstimate(in: lastSession.sets)
        // A PR means strictly beating the prior best — a first-ever session
        // sets the baseline, and ties don't count (same rule as Home's PR
        // counter).
        let priorBest = sessions.dropFirst().map { OneRepMax.bestEstimate(in: $0.sets) }.max() ?? 0

        guard lastBest > 0 else {
            return RecentExerciseEntry(exercise: exercise, topSetText: topSetText, e1RMValue: nil, isPR: false)
        }

        return RecentExerciseEntry(
            exercise: exercise,
            topSetText: topSetText,
            e1RMValue: Int(lastBest.rounded()),
            isPR: priorBest > 0 && lastBest > priorBest
        )
    }
}

// MARK: - Recently Used Row

private struct RecentExerciseEntry: Identifiable {
    let exercise: Exercise
    let topSetText: String?
    let e1RMValue: Int?
    let isPR: Bool

    var id: PersistentIdentifier { exercise.id }

    var e1RMText: String? {
        guard let e1RMValue else { return nil }
        return isPR ? "PR e1RM \(e1RMValue)" : "e1RM \(e1RMValue)"
    }

    var performanceAccessibilityLabel: String {
        var parts: [String] = []

        if let topSetText {
            parts.append("Last top set \(topSetText.replacingOccurrences(of: "×", with: " by "))")
        }

        if let e1RMValue {
            parts.append("estimated one-rep max \(e1RMValue)\(isPR ? ", personal record" : "")")
        }

        return parts.joined(separator: ", ")
    }
}

private struct RecentExerciseRowLabel: View {
    let entry: RecentExerciseEntry

    var body: some View {
        HStack(spacing: 11) {
            ExerciseMonogramTile(name: entry.exercise.displayName)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.exercise.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                if let caption = ExerciseListRow.caption(for: entry.exercise) {
                    Text(caption)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let topSetText = entry.topSetText {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(topSetText)
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)

                    if let e1RMText = entry.e1RMText {
                        Text(e1RMText)
                            .font(.system(size: 10.5, weight: entry.isPR ? .semibold : .regular))
                            .monospacedDigit()
                            .foregroundStyle(entry.isPR ? Theme.done : Theme.textSecondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(entry.performanceAccessibilityLabel)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Compact Brand Button

/// Inline-sized solid blue button for the page header, matching
/// `BrandButtonStyle` at a smaller scale.
private struct CompactBrandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                Theme.primary,
                in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
