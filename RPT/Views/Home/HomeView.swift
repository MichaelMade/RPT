//
//  HomeView.swift
//  RPT
//
//  The training dashboard: a concrete next-session hero, week-at-a-glance
//  day strip, recent sessions, and quick tools.
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: WorkoutSession
    @StateObject private var viewModel = HomeViewModel()
    @AppStorage("selectedRootTab") private var selectedRootTabRawValue = RootTab.home.rawValue

    @State private var showingReplaceDialog = false
    @State private var showingRPTCalculator = false
    @State private var showingPlateCalculator = false
    @State private var workoutToDelete: Workout?
    @State private var errorMessage: String?
    @State private var pendingTemplate: WorkoutTemplate?

    // Derived dashboard data, recomputed on appear.
    @State private var weekCells: [WeekDayCell] = []
    @State private var weekDeltaPercent: Int?
    @State private var workoutsThisWeek = 0
    @State private var volumeThisWeek: Double = 0
    @State private var prCounts: [PersistentIdentifier: Int] = [:]
    @State private var nextTemplate: WorkoutTemplate?
    @State private var nextTemplateLastRun: Workout?

    private let workoutManager = WorkoutManager.shared
    private let templateManager = TemplateManager.shared

    private struct WeekDayCell: Identifiable {
        let id: Int
        let label: String
        let isToday: Bool
        let isTrained: Bool
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.sectionSpacing) {
                    pageHeader
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
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                session.restoreResumableWorkout()
                viewModel.refresh()
                refreshDerivedData()
            }
            .onChange(of: session.isPresentingWorkout) { _, presenting in
                // The Home tab stays mounted while the full-screen logger is
                // up; refresh when it comes down so a just-finished workout
                // shows immediately.
                if !presenting {
                    viewModel.refresh()
                    refreshDerivedData()
                }
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
                Button("Cancel", role: .cancel) {
                    pendingTemplate = nil
                }
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
                        if viewModel.deleteWorkout(workout) {
                            refreshDerivedData()
                        } else {
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

    // MARK: - Page Header

    private var pageHeader: some View {
        HStack {
            Text("Today")
                .font(Theme.titleFont(size: 26))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            if viewModel.workoutStreak > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.dropOne)

                    Text("\(viewModel.workoutStreak)-day streak")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.cardBackground, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 8)
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroCard: some View {
        if let workout = session.resumableWorkout {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    PillTag(text: "In progress", tint: Theme.dropOne, icon: "bolt.fill")
                    Spacer()
                    Text(workout.date, style: .date)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(WorkoutNameFormatter.displayName(for: workout))
                        .font(Theme.titleFont(size: 18))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)

                    Text(activeWorkoutSummary(workout))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }

                Button {
                    session.openCurrent()
                } label: {
                    Label("Continue Workout", systemImage: "play.fill")
                }
                .buttonStyle(BrandButtonStyle())

                Button("Start a different workout") {
                    pendingTemplate = nil
                    showingReplaceDialog = true
                }
                .buttonStyle(SecondaryCapsuleButtonStyle(fullWidth: true))
            }
            .rptCard(padding: 16)
        } else if let template = nextTemplate {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(template.name) is next")
                        .font(Theme.titleFont(size: 18))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)

                    Text(nextTemplateContextLine(for: template))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Button {
                        startTemplateWorkout(template)
                    } label: {
                        Label("Start \(template.name)", systemImage: "play.fill")
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .buttonStyle(BrandButtonStyle())

                    heroSecondaryButton("Blank") {
                        startNewWorkout()
                    }
                    .accessibilityLabel("Start blank workout")
                }
            }
            .rptCard(padding: 16)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Start a workout")
                        .font(Theme.titleFont(size: 18))
                        .foregroundStyle(Theme.textPrimary)

                    Text("Start fresh, or build a template for one-tap starts")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }

                HStack(spacing: 8) {
                    Button {
                        startNewWorkout()
                    } label: {
                        Label("Start workout", systemImage: "plus")
                    }
                    .buttonStyle(BrandButtonStyle())

                    heroSecondaryButton("Templates") {
                        selectedRootTabRawValue = RootTab.templates.rawValue
                    }
                    .accessibilityLabel("Browse templates")
                }
            }
            .rptCard(padding: 16)
        }
    }

    private func heroSecondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.vertical, 13)
                .padding(.horizontal, 16)
                .background(
                    Theme.cardBackground,
                    in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func nextTemplateContextLine(for template: WorkoutTemplate) -> String {
        guard let lastRun = nextTemplateLastRun else {
            let count = template.exercises.count
            return count == 1 ? "Not run yet · 1 exercise" : "Not run yet · \(count) exercises"
        }

        var lead = "Last time"
        if lastRun.hasPreferredWorkMetric {
            lead += ": \(workMetricText(for: lastRun))"
            if let minutes = durationMinutes(for: lastRun) {
                lead += " in \(minutes) min"
            }
        } else if let minutes = durationMinutes(for: lastRun) {
            lead += ": \(minutes) min"
        }

        return "\(lead) · \(relativeDaysText(from: lastRun.date))"
    }

    // MARK: - This Week

    private var weekCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if viewModel.weeklyGoal > 0 {
                    Text("\(workoutsThisWeek) of \(viewModel.weeklyGoal) workouts")
                        .font(.system(size: 13))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            HStack(spacing: 5) {
                ForEach(weekCells) { day in
                    dayTile(day)
                }
            }

            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)

            HStack(spacing: 16) {
                weekStat(value: volumeText(volumeThisWeek), label: "Volume this week")

                if let delta = weekDeltaPercent {
                    weekStat(value: delta >= 0 ? "+\(delta)%" : "\(delta)%", label: "vs last week")
                }
            }
        }
        .rptCard(padding: 16)
    }

    private func dayTile(_ day: WeekDayCell) -> some View {
        VStack(spacing: 5) {
            ZStack {
                if day.isTrained {
                    RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous)
                        .fill(Theme.done)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                } else if day.isToday {
                    RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous)
                        .fill(Theme.cardBackground)
                    RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous)
                        .strokeBorder(Theme.primary, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                } else {
                    RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous)
                        .fill(Theme.surfaceMuted)
                }
            }
            .frame(height: 34)

            Text(day.label)
                .font(.system(size: 11, weight: day.isToday ? .semibold : .regular))
                .foregroundStyle(day.isToday ? Theme.primary : Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayAccessibilityLabel(day))
    }

    private func dayAccessibilityLabel(_ day: WeekDayCell) -> String {
        var parts = [day.label]
        if day.isToday {
            parts.append("today")
        }
        parts.append(day.isTrained ? "trained" : "no workout")
        return parts.joined(separator: ", ")
    }

    private func weekStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.titleFont(size: 18))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Recent Workouts

    private var recentSection: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent workouts")
                    .font(Theme.titleFont(size: 16))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                NavigationLink {
                    HistoryListView()
                } label: {
                    Text("See all")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
            }
            .padding(.horizontal, 2)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.recentWorkouts.enumerated()), id: \.element.id) { index, workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        WorkoutCard(workout: workout, prCount: prCounts[workout.id] ?? 0)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            workoutToDelete = workout
                        } label: {
                            Label("Delete Workout", systemImage: "trash")
                        }
                    }

                    if index < viewModel.recentWorkouts.count - 1 {
                        Rectangle()
                            .fill(Theme.hairline)
                            .frame(height: 1)
                    }
                }
            }
            .rptCard(padding: 0)
        }
    }

    // MARK: - Tools

    private var toolsSection: some View {
        HStack(spacing: 10) {
            shortcutCard(
                title: "RPT Calculator",
                subtitle: "Plan your drops",
                icon: "arrow.up.right",
                iconTint: Theme.primary,
                tileTint: Theme.primaryTint
            ) {
                showingRPTCalculator = true
            }

            shortcutCard(
                title: "Plate Math",
                subtitle: "Load the bar",
                icon: "smallcircle.filled.circle",
                iconTint: Theme.purple,
                tileTint: Theme.purpleTint
            ) {
                showingPlateCalculator = true
            }
        }
    }

    private func shortcutCard(
        title: String,
        subtitle: String,
        icon: String,
        iconTint: Color,
        tileTint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconTint)
                    .frame(width: 32, height: 32)
                    .background(
                        tileTint,
                        in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .rptCard(padding: 12)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Derived Data

    private func refreshDerivedData() {
        let calendar = Calendar.current
        let now = Date()
        let completedAscending = workoutManager
            .getWorkouts(from: .distantPast, to: now)
            .filter(\.isCompleted)

        prCounts = WorkoutPRCounter.counts(forCompletedWorkoutsAscending: completedAscending)

        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            ?? calendar.startOfDay(for: now)
        let thisWeek = completedAscending.filter { $0.date >= weekStart }
        let trainedDays = Set(thisWeek.map { calendar.startOfDay(for: $0.date) })

        // Header count, volume, day strip, and delta all come from this one
        // full-history pass so the card can never disagree with itself.
        workoutsThisWeek = thisWeek.count
        volumeThisWeek = thisWeek.reduce(0.0) { $0 + safeVolume($1) }

        let symbols = calendar.shortWeekdaySymbols
        weekCells = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }

            let weekdayIndex = (calendar.component(.weekday, from: day) - 1 + 7) % 7
            return WeekDayCell(
                id: offset,
                label: symbols.indices.contains(weekdayIndex) ? symbols[weekdayIndex] : "",
                isToday: calendar.isDateInToday(day),
                isTrained: trainedDays.contains(calendar.startOfDay(for: day))
            )
        }

        if let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) {
            let lastWeekVolume = completedAscending
                .filter { $0.date >= lastWeekStart && $0.date < weekStart }
                .reduce(0.0) { $0 + safeVolume($1) }

            weekDeltaPercent = lastWeekVolume > 0
                ? Int((((volumeThisWeek - lastWeekVolume) / lastWeekVolume) * 100).rounded())
                : nil
        } else {
            weekDeltaPercent = nil
        }

        let templates = templateManager.fetchAllTemplates()
        var latestRunByTemplateID: [String: Workout] = [:]
        for workout in completedAscending {
            if let templateID = workout.startedFromTemplateID {
                latestRunByTemplateID[templateID] = workout
            } else if let templateName = workout.startedFromTemplate,
                      let match = templates.first(where: { TemplateManager.namesCollide($0.name, templateName) }) {
                latestRunByTemplateID[match.id] = workout
            }
        }

        var pick: WorkoutTemplate?
        var pickDate = Date.distantFuture
        for template in templates {
            // Never headline a template the Templates tab would show as
            // broken — its Start could only fail.
            guard templateManager.canStartWorkout(for: template) else { continue }

            let lastRun = latestRunByTemplateID[template.id]?.date ?? .distantPast
            // Name tiebreak keeps ties (e.g. several never-run templates)
            // deterministic and rotating in a sensible order.
            if lastRun < pickDate || (lastRun == pickDate && template.name < (pick?.name ?? "")) {
                pick = template
                pickDate = lastRun
            }
        }

        nextTemplate = pick
        nextTemplateLastRun = pick.flatMap { latestRunByTemplateID[$0.id] }
    }

    private func safeVolume(_ workout: Workout) -> Double {
        workout.totalVolume.isFinite ? max(0, workout.totalVolume) : 0
    }

    private func volumeText(_ volume: Double) -> String {
        let safeVolume = volume.isFinite ? max(0, volume) : 0
        return "\(Int(safeVolume).formatted()) lb"
    }

    private func workMetricText(for workout: Workout) -> String {
        if workout.totalVolume.isFinite, workout.totalVolume > 0 {
            return "\(Int(workout.totalVolume).formatted()) lb"
        }

        return workout.preferredWorkMetricValue
    }

    private func durationMinutes(for workout: Workout) -> Int? {
        guard workout.isCompleted, workout.duration.isFinite, workout.duration > 0 else {
            return nil
        }

        return max(1, Int((workout.duration / 60).rounded()))
    }

    private func relativeDaysText(from date: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0

        if days <= 0 {
            return "today"
        }
        if days == 1 {
            return "yesterday"
        }
        return "\(days) days ago"
    }

    // MARK: - Actions

    private var replaceDialogMessage: String {
        guard let workout = session.resumableWorkout else {
            return "You already have a workout in progress."
        }

        return "“\(WorkoutNameFormatter.displayName(for: workout))” is in progress. Save it for later or discard it before starting a new workout."
    }

    private func startTemplateWorkout(_ template: WorkoutTemplate) {
        if session.resumableWorkout != nil {
            pendingTemplate = template
            showingReplaceDialog = true
            return
        }

        launchTemplate(template)
    }

    private func launchTemplate(_ template: WorkoutTemplate) {
        guard let workout = templateManager.createWorkoutFromTemplate(template) else {
            errorMessage = "Couldn’t start this template. Make sure its exercises are still in your library."
            return
        }

        session.start(workout)
    }

    private func startNewWorkout() {
        if session.resumableWorkout != nil {
            pendingTemplate = nil
            showingReplaceDialog = true
            return
        }

        if !session.startEmptyWorkout() {
            errorMessage = "Couldn’t create a new workout. Please try again."
        }
    }

    private func startPendingWorkout() {
        if let template = pendingTemplate {
            pendingTemplate = nil
            launchTemplate(template)
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

        startPendingWorkout()
    }

    private func discardCurrentAndStartNew() {
        guard session.discardCurrent() else {
            errorMessage = "Couldn’t discard the current workout. Keep it open, then try again."
            return
        }

        startPendingWorkout()
    }

    private func activeWorkoutSummary(_ workout: Workout) -> String {
        let exerciseCount = workout.exerciseCount
        guard exerciseCount > 0 else {
            return "No exercises yet — add your first movement."
        }

        let loggedSets = workout.sets.filter(\.isCompletedLoggedSet).count
        let exercisePart = exerciseCount == 1 ? "1 exercise" : "\(exerciseCount) exercises"
        let setsPart = loggedSets == 1 ? "1 logged set" : "\(loggedSets) logged sets"
        return "\(exercisePart) · \(setsPart)"
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
