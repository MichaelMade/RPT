//
//  SettingsView.swift
//  RPT
//
//  Training preferences: RPT drops, rest timer, weekly goal, RPE,
//  appearance, sound, and data export — grouped Vibe cards with a
//  live drop-ladder preview.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var purchaseManager = StoreKitPurchaseManager.shared

    @State private var soundEnabled = SoundManager.shared.isSoundEnabled()
    @State private var showingResetConfirmation = false
    @State private var errorMessage: String?
    @State private var exportURL: URL?
    @State private var showingDropEditors = false

    /// One-tap rest presets shown as chips (seconds).
    private let restDurationChips = [90, 120, 150, 180]

    /// Full duration list kept reachable behind the overflow menu.
    private let allRestDurations = [60, 90, 120, 150, 180, 210, 240, 300]

    private var settings: UserSettings {
        settingsManager.settings
    }

    /// Drops beyond the always-zero top set, shown as percentages.
    private var backoffDropPercents: [Int] {
        settings.defaultRPTPercentageDrops.dropFirst().map { Int(($0 * 100).rounded()) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                    pageHeader
                    premiumSection
                    trainingSection
                    restTimerSection
                    appSection
                    aboutSection
                    resetSection
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 24)
                .frame(maxWidth: Theme.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.screenBackground)
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(
                "Reset All Settings?",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset to Defaults", role: .destructive) {
                    if !settingsManager.resetToDefaultsSafely() {
                        errorMessage = "Couldn’t reset settings. Please try again."
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Restores RPT drops, rest timer, weekly goal, RPE, and appearance to their defaults.")
            }
            .alert("Couldn’t Save Setting", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
            .onDisappear {
                // Drop any generated CSV so the next visit exports fresh data
                // instead of re-sharing a stale file.
                exportURL = nil
            }
            .task {
                await purchaseManager.start()
            }
        }
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        Text("Settings")
            .font(Theme.titleFont(size: 26))
            .foregroundStyle(Theme.textPrimary)
            .padding(.top, 8)
            .padding(.horizontal, 2)
    }

    // MARK: - RPT Pro

    private var premiumSection: some View {
        Section {
            NavigationLink {
                UpgradeView()
            } label: {
                proBanner
            }
            .buttonStyle(.plain)
        } header: {
            Text("RPT Pro")
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.6)
                .textCase(.uppercase)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 2)
        } footer: {
            Text(purchaseManager.state.displayMessage)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 2)
        }
    }

    /// One pitch per state: locked users see the offer and price; unlocked
    /// users get a quiet thanks with no second sell.
    private var proBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(purchaseManager.isUnlocked ? "RPT Pro unlocked" : "RPT Pro · Lifetime")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text(purchaseManager.isUnlocked
                     ? "Thanks for supporting RPT — everything is unlocked"
                     : "Advanced analytics, unlimited templates, CSV export")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if purchaseManager.isUnlocked {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            } else if let displayPrice = purchaseManager.displayPrice {
                Text(displayPrice)
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        .white,
                        in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
                    )
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(16)
        .background(
            Theme.proGradient,
            in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(purchaseManager.isUnlocked ? "Shows RPT Pro details" : "Opens the RPT Pro upgrade")
    }

    // MARK: - Training

    private var trainingSection: some View {
        settingsGroup("Training") {
            rptDropsRow
            hairline
            weeklyGoalRow
            hairline
            rpeRow
        }
    }

    /// "−10% / −15%" from the currently configured back-off drops.
    private var dropsSummary: String {
        backoffDropPercents.map { "−\($0)%" }.joined(separator: " / ")
    }

    /// The configured ladder applied to a 100 lb top set, e.g. [100, 90, 85].
    private var ladderWeights: [Int] {
        let topSetWeight = 100
        let workoutManager = WorkoutManager.shared
        let backoffs = settings.defaultRPTPercentageDrops.dropFirst().map { drop in
            workoutManager.roundToNearest5(Double(topSetWeight) * (1.0 - drop))
        }
        return [topSetWeight] + backoffs
    }

    private var ladderColors: [Color] {
        [Theme.topSet, Theme.dropOne, Theme.dropTwo]
    }

    private var rptDropsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    showingDropEditors.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("RPT weight drops")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()

                    Text(dropsSummary)
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.primary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .rotationEffect(.degrees(showingDropEditors ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("RPT weight drops")
            .accessibilityValue(dropsSummary)
            .accessibilityHint(showingDropEditors ? "Collapses the drop editors" : "Expands the drop editors")

            ladderPreview

            if showingDropEditors {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(backoffDropPercents.enumerated()), id: \.offset) { index, percent in
                        Stepper(
                            "Back-off \(index + 1): −\(percent)%",
                            onIncrement: { adjustDrop(at: index, by: 5) },
                            onDecrement: { adjustDrop(at: index, by: -5) }
                        )
                        .font(.system(size: 14))
                        // The stepper control is taller than the label-driven
                        // row, so without a min height it overflows.
                        .frame(minHeight: 32)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.vertical, 12)
    }

    private var ladderPreview: some View {
        HStack(spacing: 6) {
            ForEach(Array(ladderWeights.enumerated()), id: \.offset) { index, weight in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                }

                Text("\(weight)")
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(index == 0 ? Color.white : Theme.inverted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        ladderColors[min(index, ladderColors.count - 1)],
                        in: RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous)
                    )
            }

            Text("from a 100 lb top set")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
                .padding(.leading, 4)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Example from a 100 pound top set: \(ladderWeights.map(String.init).joined(separator: ", ")) pounds"
        )
    }

    /// 3–6 one-tap tiles; the full 1–14 range stays reachable behind the
    /// overflow menu, which shows and highlights an off-tile stored goal.
    private var weeklyGoalOptions: [Int] { [3, 4, 5, 6] }

    private var weeklyGoalBinding: Binding<Int> {
        Binding(
            get: { settings.weeklyWorkoutGoal },
            set: { updateWeeklyGoal($0) }
        )
    }

    private var moreGoalsMenu: some View {
        Menu {
            Picker("Weekly goal", selection: weeklyGoalBinding) {
                ForEach(1...14, id: \.self) { goal in
                    Text("\(goal) per week").tag(goal)
                }
            }
        } label: {
            let isCustom = !weeklyGoalOptions.contains(settings.weeklyWorkoutGoal)

            Group {
                if isCustom {
                    Text("\(settings.weeklyWorkoutGoal)")
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                } else {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .foregroundStyle(isCustom ? .white : Theme.textSecondary)
            .frame(width: 26, height: 26)
            .background(
                isCustom ? Theme.primaryAction : Theme.surfaceMuted,
                in: RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous)
            )
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("More weekly goal choices")
    }

    private var weeklyGoalRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly goal")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 2) {
                ForEach(weeklyGoalOptions, id: \.self) { goal in
                    let isSelected = goal == settings.weeklyWorkoutGoal

                    Button {
                        updateWeeklyGoal(goal)
                    } label: {
                        Text("\(goal)")
                            .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                            .monospacedDigit()
                            .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                            .frame(width: 26, height: 26)
                            .background(
                                isSelected ? Theme.primaryAction : Theme.surfaceMuted,
                                in: RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous)
                            )
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(goal) \(goal == 1 ? "workout" : "workouts") per week")
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }

                moreGoalsMenu

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.vertical, 12)
    }

    private var rpeRow: some View {
        Toggle(isOn: rpeBinding) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Track RPE")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)

                Text("Rate of Perceived Exertion on working sets")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .tint(Theme.primary)
        .padding(.horizontal, Theme.cardPadding)
        .padding(.vertical, 12)
    }

    // MARK: - Rest Timer

    private var restTimerSection: some View {
        settingsGroup("Rest timer") {
            restDurationRow
            hairline
            autoStartRow
        }
    }

    private var restDurationRow: some View {
        // Label above the chips: five 44pt hit targets plus the label can't
        // share one row on a 375-402pt phone without compressing the chip
        // text into "2:…".
        VStack(alignment: .leading, spacing: 10) {
            Text("Rest duration")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)

            // Distinct 10pt gaps keep the chips from reading like one
            // segmented control while still fitting the narrowest phone.
            HStack(spacing: 10) {
                ForEach(restDurationChips, id: \.self) { seconds in
                    let isSelected = seconds == settings.restTimerDuration

                    Button {
                        setRestDuration(seconds)
                    } label: {
                        Text(chipDuration(seconds))
                            .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                            .monospacedDigit()
                            .fixedSize()
                            .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                            .padding(.horizontal, 9)
                            .frame(height: 26)
                            .background(
                                isSelected ? Theme.primaryAction : Theme.surfaceMuted,
                                in: RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous)
                            )
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rest \(formattedDuration(seconds))")
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }

                moreDurationsMenu

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.vertical, 12)
    }

    /// Keeps the full duration list reachable; when the stored value isn't
    /// one of the chips the menu chip shows it, highlighted.
    private var moreDurationsMenu: some View {
        Menu {
            Picker("Rest duration", selection: restDurationBinding) {
                ForEach(allRestDurations, id: \.self) { seconds in
                    Text(formattedDuration(seconds)).tag(seconds)
                }
            }
        } label: {
            let isCustom = !restDurationChips.contains(settings.restTimerDuration)

            Group {
                if isCustom {
                    Text(chipDuration(settings.restTimerDuration))
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                        .fixedSize()
                } else {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .foregroundStyle(isCustom ? .white : Theme.textSecondary)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(
                isCustom ? Theme.primaryAction : Theme.surfaceMuted,
                in: RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous)
            )
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("More rest durations")
        .accessibilityValue(formattedDuration(settings.restTimerDuration))
    }

    private var autoStartRow: some View {
        Toggle(isOn: autoTimerBinding) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Auto-start after logging")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)

                Text("RPT works best with full rest before top sets")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .tint(Theme.primary)
        .padding(.horizontal, Theme.cardPadding)
        .padding(.vertical, 12)
    }

    // MARK: - App

    private var appSection: some View {
        settingsGroup("App") {
            appearanceRow
            hairline
            soundRow
            hairline
            exportRow
        }
    }

    private var appearanceRow: some View {
        HStack(spacing: 12) {
            Text("Appearance")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            // Native segmented control: the DesignTour UI test taps
            // app.buttons["Dark"], which segments expose by title.
            Picker("Theme", selection: darkModeBinding) {
                Text("System").tag(DarkModePreference.system)
                Text("Light").tag(DarkModePreference.light)
                Text("Dark").tag(DarkModePreference.dark)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.vertical, 12)
    }

    private var soundRow: some View {
        Toggle(isOn: $soundEnabled) {
            Text("Sound effects")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
        }
        .tint(Theme.primary)
        .onChange(of: soundEnabled) { _, newValue in
            SoundManager.shared.setEnabled(newValue)
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var exportRow: some View {
        if !purchaseManager.hasPreparedEntitlements {
            HStack(spacing: 10) {
                Text("Checking RPT Pro access…")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                ProgressView()
                    .controlSize(.small)
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
        } else if purchaseManager.isUnlocked {
            if let exportURL {
                ShareLink(item: exportURL) {
                    exportRowLabel(title: "Share exported CSV", icon: "square.and.arrow.up", showsProTag: false)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    let workouts = WorkoutManager.shared.getWorkouts(from: .distantPast, to: Date())
                    exportURL = WorkoutCSVExporter.exportFile(for: workouts)
                    if exportURL == nil {
                        errorMessage = "Couldn’t create the export file. Please try again."
                    }
                } label: {
                    exportRowLabel(title: "Export data as CSV", icon: "tablecells", showsProTag: false)
                }
                .buttonStyle(.plain)
            }
        } else {
            NavigationLink {
                UpgradeView()
            } label: {
                exportRowLabel(title: "Export data as CSV", icon: nil, showsProTag: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Export data as CSV")
            .accessibilityValue("RPT Pro feature")
            .accessibilityHint("Opens the RPT Pro upgrade")
        }
    }

    private func exportRowLabel(title: String, icon: String?, showsProTag: Bool) -> some View {
        HStack(spacing: 7) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)

            if showsProTag {
                Text("PRO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.purpleForeground)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Theme.purpleTint,
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                    )
            }

            Spacer()

            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - About & Reset

    private var aboutSection: some View {
        settingsGroup("About") {
            NavigationLink {
                AboutView()
            } label: {
                HStack {
                    Text("About RPT")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, Theme.cardPadding)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var resetSection: some View {
        Button("Reset all settings", role: .destructive) {
            showingResetConfirmation = true
        }
        .font(.system(size: 14, weight: .semibold))
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .rptCard(padding: 0)
    }

    // MARK: - Group Scaffolding

    /// Eyebrow label plus a bordered white card whose rows the caller
    /// separates with `hairline`.
    private func settingsGroup<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Theme.sectionLabel(label)
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                content()
            }
            .rptCard(padding: 0)
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
    }

    // MARK: - Mutations

    private func adjustDrop(at backoffIndex: Int, by delta: Int) {
        var percents = backoffDropPercents
        guard backoffIndex < percents.count else { return }

        percents[backoffIndex] = min(max(percents[backoffIndex] + delta, 5), 50)

        // Keep drops monotonically increasing so back-off sets never get heavier.
        for index in 1..<percents.count where percents[index] < percents[index - 1] {
            percents[index] = percents[index - 1]
        }

        let drops = [0.0] + percents.map { Double($0) / 100.0 }
        if !settingsManager.updateRPTPercentageDropsSafely(drops: UserSettings.normalizedRPTPercentageDrops(drops)) {
            errorMessage = "Couldn’t save the RPT drops. Please try again."
        }
    }

    private func updateWeeklyGoal(_ goal: Int) {
        let clamped = UserSettings.normalizedWeeklyWorkoutGoal(goal)
        guard clamped != settings.weeklyWorkoutGoal else { return }

        if !settingsManager.updateWeeklyWorkoutGoalSafely(clamped) {
            errorMessage = "Couldn’t save the weekly goal. Please try again."
        }
    }

    private func setRestDuration(_ seconds: Int) {
        guard seconds != settings.restTimerDuration else { return }

        if !settingsManager.updateRestTimerDurationSafely(seconds: seconds) {
            errorMessage = "Couldn’t save the rest duration. Please try again."
        }
    }

    // MARK: - Bindings

    private var restDurationBinding: Binding<Int> {
        Binding(
            get: { settings.restTimerDuration },
            set: { newValue in
                if !settingsManager.updateRestTimerDurationSafely(seconds: newValue) {
                    errorMessage = "Couldn’t save the rest duration. Please try again."
                }
            }
        )
    }

    private var rpeBinding: Binding<Bool> {
        Binding(
            get: { settings.showRPE },
            set: { newValue in
                if !settingsManager.updateShowRPESafely(show: newValue) {
                    errorMessage = "Couldn’t save the RPE setting. Please try again."
                }
            }
        )
    }

    private var autoTimerBinding: Binding<Bool> {
        Binding(
            get: { settings.autoStartRestTimerEnabled },
            set: { newValue in
                if !settingsManager.updateAutoStartRestTimerSafely(enabled: newValue) {
                    errorMessage = "Couldn’t save the timer setting. Please try again."
                }
            }
        )
    }

    private var darkModeBinding: Binding<DarkModePreference> {
        Binding(
            get: { settingsManager.darkModePreference },
            set: { newValue in
                if !settingsManager.updateDarkModePreferenceSafely(preference: newValue) {
                    errorMessage = "Couldn’t save the theme. Please try again."
                }
            }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    // MARK: - Formatting

    /// Compact chip form, e.g. "1:30", "2:00".
    private func chipDuration(_ seconds: Int) -> String {
        "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        if remainder == 0 {
            return "\(minutes) min"
        }
        return "\(minutes):\(String(format: "%02d", remainder)) min"
    }
}
