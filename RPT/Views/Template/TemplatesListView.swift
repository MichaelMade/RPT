//
//  TemplatesListView.swift
//  RPT
//
//  Saved routines: search, start, duplicate, edit, and delete.
//  Each routine card carries the same template key color used on
//  Home's recent-workout rows.
//

import SwiftUI

struct TemplatesListView: View {
    @EnvironmentObject private var session: WorkoutSession
    @AppStorage("showCreateTemplateAfterOnboarding") private var showCreateTemplateAfterOnboarding = false
    @StateObject private var viewModel = TemplateViewModel()
    @ObservedObject private var purchaseManager = StoreKitPurchaseManager.shared

    @State private var showingCreateTemplate = false
    @State private var showingUpgrade = false
    @State private var templateToDelete: WorkoutTemplate?
    @State private var templateToEdit: WorkoutTemplate?
    @State private var pendingStartTemplate: WorkoutTemplate?
    @State private var errorMessage: String?
    @State private var lastRunDatesByTemplateID: [String: Date] = [:]

    private let workoutManager = WorkoutManager.shared

    /// Route every new-template entry point through the free-tier limit.
    private func requestCreateTemplate() {
        guard purchaseManager.hasPreparedEntitlements else {
            Task { @MainActor in
                await purchaseManager.prepareEntitlements()
                requestCreateTemplate()
            }
            return
        }

        if MonetizationPlan.canCreateTemplate(
            existingCount: viewModel.templates.count,
            isUnlocked: purchaseManager.isUnlocked
        ) {
            showingCreateTemplate = true
        } else {
            showingUpgrade = true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    pageHeader

                    if !viewModel.templates.isEmpty {
                        searchField
                            .padding(.bottom, 4)
                    }

                    if viewModel.templates.isEmpty {
                        EmptyStateCard(
                            icon: "square.grid.2x2",
                            title: "No Templates Yet",
                            message: "Save your favorite routines as templates and start them with one tap.",
                            actionTitle: "Create Template"
                        ) {
                            requestCreateTemplate()
                        }
                    } else if viewModel.filteredTemplates.isEmpty {
                        EmptyStateCard(
                            icon: "magnifyingglass",
                            title: "No Matches",
                            message: viewModel.noMatchesDescription()
                        )
                    } else {
                        ForEach(viewModel.filteredTemplates) { template in
                            templateCard(template)
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 24)
                .frame(maxWidth: Theme.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.screenBackground)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingCreateTemplate) {
                TemplateEditView(mode: .create) {
                    viewModel.refreshTemplates()
                }
            }
            .sheet(item: $templateToEdit) { template in
                TemplateEditView(mode: .edit(template)) {
                    viewModel.refreshTemplates()
                }
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
            .onAppear {
                viewModel.refreshTemplates()
                session.restoreResumableWorkout()
                refreshLastRunDates()

                if showCreateTemplateAfterOnboarding {
                    showCreateTemplateAfterOnboarding = false
                    requestCreateTemplate()
                }
            }
            .task {
                await purchaseManager.prepareEntitlements()
            }
            .alert(item: $templateToDelete) { template in
                Alert(
                    title: Text("Delete “\(template.name)”?"),
                    message: Text("This removes the template. Your workout history is not affected."),
                    primaryButton: .destructive(Text("Delete")) {
                        if !viewModel.deleteTemplate(template) {
                            errorMessage = "Couldn’t delete this template. Please try again."
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .confirmationDialog(
                "Workout in Progress",
                isPresented: pendingStartBinding,
                titleVisibility: .visible
            ) {
                Button("Save Current & Start Template") {
                    resolveBlockedStart(discard: false)
                }
                Button("Discard Current & Start Template", role: .destructive) {
                    resolveBlockedStart(discard: true)
                }
                Button("Cancel", role: .cancel) {
                    pendingStartTemplate = nil
                }
            } message: {
                Text("Save your current workout for later or discard it before starting this template.")
            }
            .alert("Couldn’t Start Template", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    // MARK: - Header & Search

    private var pageHeader: some View {
        HStack {
            Text("Templates")
                .font(Theme.titleFont(size: 26))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Button {
                requestCreateTemplate()
            } label: {
                Label("New", systemImage: "plus")
            }
            .buttonStyle(CompactBrandButtonStyle())
            .accessibilityLabel("Create template")
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)

            TextField("Search templates", text: $viewModel.searchText)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Search templates")
                .accessibilityHint(TemplateViewModel.searchPrompt)

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

    // MARK: - Card

    private func templateCard(_ template: WorkoutTemplate) -> some View {
        let missingCount = viewModel.missingExerciseNames(in: template).count
        let isBroken = !viewModel.canStart(template)

        return VStack(spacing: 0) {
            Rectangle()
                .fill(isBroken ? Theme.textTertiary : TemplateKeyColor.color(forKey: template.id))
                .frame(height: 5)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                NavigationLink {
                    TemplateDetailView(template: template) {
                        viewModel.refreshTemplates()
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(template.name)
                                .font(Theme.titleFont(size: 15))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            if missingCount > 0 {
                                missingChip(count: missingCount)
                            } else if let lastRun = lastRunText(for: template) {
                                Text(lastRun)
                                    .font(.system(size: 11))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }

                        if !isBroken, !template.exercises.isEmpty {
                            exerciseChips(for: template)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Shows template details")

                HStack(spacing: 8) {
                    if isBroken {
                        Button("Fix template") {
                            templateToEdit = template
                        }
                        .buttonStyle(SecondaryCapsuleButtonStyle())
                    } else {
                        Button {
                            requestStart(template)
                        } label: {
                            Label("Start", systemImage: "play.fill")
                        }
                        .buttonStyle(CompactBrandButtonStyle())
                    }

                    Spacer(minLength: 8)

                    if !isBroken, let estimate = sessionEstimate(for: template) {
                        Text("\(estimate.sets) \(estimate.sets == 1 ? "set" : "sets") · ~\(estimate.minutes) min")
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textSecondary)
                            .accessibilityLabel("\(estimate.sets) \(estimate.sets == 1 ? "set" : "sets"), about \(estimate.minutes) minutes")
                    }

                    Menu {
                        Button {
                            templateToEdit = template
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button {
                            duplicateTemplate(template)
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }

                        Button(role: .destructive) {
                            templateToDelete = template
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Template options")
                }
            }
            .padding(Theme.cardPadding)
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        .opacity(isBroken ? 0.85 : 1)
    }

    private func missingChip(count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9, weight: .semibold))

            Text(count == 1 ? "1 exercise missing" : "\(count) exercises missing")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(Theme.dropOneForeground)
    }

    private func exerciseChips(for template: WorkoutTemplate) -> some View {
        let names = template.exercises.map(\.exerciseName)
        let visible = names.prefix(3)
        let overflow = names.count - visible.count

        return HStack(spacing: 5) {
            ForEach(Array(visible.enumerated()), id: \.offset) { _, name in
                Text(name)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Theme.surfaceMuted,
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                    )
            }

            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 11.5))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Theme.surfaceMuted,
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                    )
                    .accessibilityLabel("\(overflow) more \(overflow == 1 ? "exercise" : "exercises")")
            }
        }
    }

    // MARK: - Derived Data

    /// Latest completed run per template, matched by stored template id first
    /// and by colliding name for older history rows (same rule as Home).
    private func refreshLastRunDates() {
        let completedAscending = workoutManager
            .getWorkouts(from: .distantPast, to: Date())
            .filter(\.isCompleted)

        var latest: [String: Date] = [:]
        for workout in completedAscending {
            if let templateID = workout.startedFromTemplateID {
                latest[templateID] = max(latest[templateID] ?? .distantPast, workout.date)
            } else if let templateName = workout.startedFromTemplate,
                      let match = viewModel.templates.first(where: { TemplateManager.namesCollide($0.name, templateName) }) {
                latest[match.id] = max(latest[match.id] ?? .distantPast, workout.date)
            }
        }

        lastRunDatesByTemplateID = latest
    }

    private func lastRunText(for template: WorkoutTemplate) -> String? {
        guard let date = lastRunDatesByTemplateID[template.id] else {
            return nil
        }

        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0

        if days <= 0 {
            return "Last run today"
        }
        if days == 1 {
            return "Last run yesterday"
        }
        return "Last run \(days) days ago"
    }

    /// Rough session length: ~5 min per prescribed set (RPT rests are long),
    /// rounded to the nearest 5 minutes.
    private func sessionEstimate(for template: WorkoutTemplate) -> (sets: Int, minutes: Int)? {
        let sets = template.exercises.reduce(0) { $0 + max(0, $1.suggestedSets) }
        guard sets > 0 else {
            return nil
        }

        let rawMinutes = Double(sets) * 5
        let minutes = max(5, Int((rawMinutes / 5).rounded()) * 5)
        return (sets, minutes)
    }

    // MARK: - Duplicate Flow

    private func duplicateTemplate(_ template: WorkoutTemplate) {
        guard purchaseManager.hasPreparedEntitlements else {
            Task { @MainActor in
                await purchaseManager.prepareEntitlements()
                duplicateTemplate(template)
            }
            return
        }

        guard MonetizationPlan.canCreateTemplate(
            existingCount: viewModel.templates.count,
            isUnlocked: purchaseManager.isUnlocked
        ) else {
            showingUpgrade = true
            return
        }

        if !viewModel.duplicateTemplate(template) {
            errorMessage = "Couldn’t duplicate this template. Please try again."
        }
    }

    // MARK: - Start Flow

    private func requestStart(_ template: WorkoutTemplate) {
        session.restoreResumableWorkout()

        if session.resumableWorkout != nil {
            pendingStartTemplate = template
        } else {
            startTemplate(template)
        }
    }

    private func resolveBlockedStart(discard: Bool) {
        guard let template = pendingStartTemplate else { return }
        pendingStartTemplate = nil

        let cleared = discard ? session.discardCurrent() : session.saveCurrentForLater()
        guard cleared else {
            errorMessage = discard
                ? "Couldn’t discard the current workout. Keep it open, then try again."
                : "Couldn’t save the current workout. Keep it open, then try again."
            return
        }

        startTemplate(template)
    }

    private func startTemplate(_ template: WorkoutTemplate) {
        guard let workout = viewModel.createWorkout(from: template) else {
            errorMessage = "Couldn’t start this template. Make sure its exercises are still in your library."
            return
        }

        session.start(workout)
    }

    // MARK: - Bindings

    private var pendingStartBinding: Binding<Bool> {
        Binding(
            get: { pendingStartTemplate != nil },
            set: { if !$0 { pendingStartTemplate = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

// MARK: - Compact Brand Button

/// Inline-sized solid blue button for card footers and the page header,
/// matching `BrandButtonStyle` at a smaller scale.
private struct CompactBrandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                Theme.primaryAction,
                in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
