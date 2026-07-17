//
//  SettingsView.swift
//  RPT
//
//  Training preferences: RPT drops, rest timer, weekly goal, RPE,
//  appearance, sound, and data export.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared

    @State private var soundEnabled = SoundManager.shared.isSoundEnabled()
    @State private var showingResetConfirmation = false
    @State private var errorMessage: String?
    @State private var exportURL: URL?

    private var settings: UserSettings {
        settingsManager.settings
    }

    /// Drops beyond the always-zero top set, shown as percentages.
    private var backoffDropPercents: [Int] {
        settings.defaultRPTPercentageDrops.dropFirst().map { Int(($0 * 100).rounded()) }
    }

    var body: some View {
        NavigationStack {
            Form {
                trainingSection
                restTimerSection
                appearanceSection
                soundSection
                dataSection
                aboutSection
                resetSection
            }
            .navigationTitle("Settings")
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
        }
    }

    // MARK: - Training

    private var trainingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("RPT Weight Drops")
                    .font(.subheadline.weight(.semibold))

                ForEach(Array(backoffDropPercents.enumerated()), id: \.offset) { index, percent in
                    Stepper(
                        "Back-off \(index + 1): −\(percent)%",
                        onIncrement: { adjustDrop(at: index, by: 5) },
                        onDecrement: { adjustDrop(at: index, by: -5) }
                    )
                    .font(.subheadline)
                    // The stepper control is taller than the label-driven row,
                    // so without a min height it overflows and eats the spacing.
                    .frame(minHeight: 32)
                }

                Text("Example: 100 lb top set → \(settingsManager.calculateRPTExample(firstSetWeight: 100))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            Stepper(
                "Weekly goal: \(settings.weeklyWorkoutGoal) \(settings.weeklyWorkoutGoal == 1 ? "workout" : "workouts")",
                onIncrement: { updateWeeklyGoal(settings.weeklyWorkoutGoal + 1) },
                onDecrement: { updateWeeklyGoal(settings.weeklyWorkoutGoal - 1) }
            )

            Toggle("Track RPE", isOn: rpeBinding)
        } header: {
            Text("Training")
        } footer: {
            Text("RPE (Rate of Perceived Exertion, 6–10) appears on working sets when enabled.")
        }
    }

    // MARK: - Rest Timer

    private var restTimerSection: some View {
        Section {
            Picker("Rest duration", selection: restDurationBinding) {
                ForEach([60, 90, 120, 150, 180, 210, 240, 300], id: \.self) { seconds in
                    Text(formattedDuration(seconds)).tag(seconds)
                }
            }

            Toggle("Auto-start after logging a set", isOn: autoTimerBinding)
        } header: {
            Text("Rest Timer")
        } footer: {
            Text("RPT works best with full rest — 2–3 minutes before heavy top sets.")
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: darkModeBinding) {
                Text("System").tag(DarkModePreference.system)
                Text("Light").tag(DarkModePreference.light)
                Text("Dark").tag(DarkModePreference.dark)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Sound

    private var soundSection: some View {
        Section("Sound") {
            Toggle("Sound effects", isOn: $soundEnabled)
                .onChange(of: soundEnabled) { _, newValue in
                    SoundManager.shared.setEnabled(newValue)
                }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section {
            if let exportURL {
                ShareLink(item: exportURL) {
                    Label("Share Exported CSV", systemImage: "square.and.arrow.up")
                }
            } else {
                Button {
                    let workouts = WorkoutManager.shared.getWorkouts(from: .distantPast, to: Date())
                    exportURL = WorkoutCSVExporter.exportFile(for: workouts)
                    if exportURL == nil {
                        errorMessage = "Couldn’t create the export file. Please try again."
                    }
                } label: {
                    Label("Export History as CSV", systemImage: "tablecells")
                }
            }
        } header: {
            Text("Data")
        } footer: {
            Text("All data stays on this device. CSV export includes every logged set from completed workouts.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            NavigationLink {
                AboutView()
            } label: {
                Label("About RPT", systemImage: "info.circle")
            }
        }
    }

    private var resetSection: some View {
        Section {
            Button("Reset All Settings", role: .destructive) {
                showingResetConfirmation = true
            }
        }
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
            get: { settings.darkModePreference },
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

    private func formattedDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        if remainder == 0 {
            return "\(minutes) min"
        }
        return "\(minutes):\(String(format: "%02d", remainder)) min"
    }
}
