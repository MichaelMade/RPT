//
//  SettingsViewModel.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class SettingsViewModel: ObservableObject {
    private let settingsManager: SettingsManaging
    private var isSyncingFromPersistedSettings = false

    @Published var saveErrorTitle: String = "Unable to Save Settings"
    @Published var saveErrorMessage: String?
    
    @Published var restTimerDuration: Int {
        didSet {
            guard !isSyncingFromPersistedSettings else { return }

            if !settingsManager.updateRestTimerDurationSafely(seconds: restTimerDuration) {
                syncFromPersistedSettings()
                presentSaveError(
                    title: "Couldn’t Save Rest Timer",
                    message: "Rest timer changes could not be saved."
                )
            }
        }
    }
    
    @Published var defaultRPTPercentageDrops: [Double] {
        didSet {
            guard !isSyncingFromPersistedSettings else { return }

            if !settingsManager.updateRPTPercentageDropsSafely(drops: defaultRPTPercentageDrops) {
                syncFromPersistedSettings()
                presentSaveError(
                    title: "Couldn’t Save Weight Drops",
                    message: "RPT drop changes could not be saved."
                )
            }
        }
    }
    
    @Published var showRPE: Bool {
        didSet {
            guard !isSyncingFromPersistedSettings else { return }

            if !settingsManager.updateShowRPESafely(show: showRPE) {
                syncFromPersistedSettings()
                presentSaveError(
                    title: "Couldn’t Save RPE Settings",
                    message: "RPE visibility changes could not be saved."
                )
            }
        }
    }
    
    @Published var darkModePreference: DarkModePreference {
        didSet {
            guard !isSyncingFromPersistedSettings else { return }

            if !settingsManager.updateDarkModePreferenceSafely(preference: darkModePreference) {
                syncFromPersistedSettings()
                presentSaveError(
                    title: "Couldn’t Save Appearance",
                    message: "Appearance changes could not be saved."
                )
            }
        }
    }

    init(settingsManager: SettingsManaging? = nil) {
        self.settingsManager = settingsManager ?? SettingsManager.shared
                
        // Initialize published properties from settings
        self.restTimerDuration = self.settingsManager.settings.restTimerDuration
        self.defaultRPTPercentageDrops = self.settingsManager.settings.defaultRPTPercentageDrops
        self.showRPE = self.settingsManager.settings.showRPE
        self.darkModePreference = self.settingsManager.settings.darkModePreference
    }

    var canResetToDefaults: Bool {
        restTimerDuration != UserSettings.defaultRestTimerDuration ||
        defaultRPTPercentageDrops != UserSettings.defaultRPTPercentageDrops ||
        showRPE != true ||
        darkModePreference != .system
    }

    var resetSettingsFooterText: String {
        canResetToDefaults
            ? "This restores display, timer, and RPT defaults without affecting your saved workouts, templates, or exercise library."
            : "You’re already using the default display, timer, and RPT settings."
    }

    var resetButtonTitle: String {
        switch customizedSettingLabels.count {
        case 0:
            return "Reset All Settings"
        case 1:
            return "Reset \(customizedSettingLabels[0])"
        default:
            return "Reset Customized Settings"
        }
    }

    var resetConfirmationTitle: String {
        let customizedSettings = customizedSettingsSummaryParts

        switch customizedSettings.count {
        case 0:
            return "Reset All Settings?"
        case 1:
            return "Reset \(customizedSettings[0])?"
        default:
            return "Reset \(customizedSettings.count) Customized Settings?"
        }
    }

    var resetConfirmationButtonTitle: String {
        let customizedSettingLabels = customizedSettingLabels

        switch customizedSettingLabels.count {
        case 0:
            return "Reset Settings"
        case 1:
            return "Reset \(customizedSettingLabels[0])"
        default:
            return "Reset \(customizedSettingLabels.count) Settings"
        }
    }

    var resetConfirmationMessage: String {
        let customizedSettings = customizedSettingsSummaryParts

        guard !customizedSettings.isEmpty else {
            return "This will restore your display, timer, and RPT defaults. Your saved workouts, templates, and exercises will stay untouched."
        }

        let subject = Self.humanReadableList(customizedSettings)
        let target = customizedSettings.count == 1 ? "its default value" : "their default values"

        return "This will reset \(subject) to \(target). Your saved workouts, templates, and exercises will stay untouched."
    }

    func resetToDefaults() {
        if !settingsManager.resetToDefaultsSafely() {
            presentSaveError(
                title: "Couldn’t Reset Settings",
                message: "Settings could not be reset right now."
            )
        }

        syncFromPersistedSettings()
    }

    func clearSaveError() {
        saveErrorTitle = "Unable to Save Settings"
        saveErrorMessage = nil
    }
    
    func calculateExample(firstWeight: Int = 225) -> String {
        return settingsManager.calculateRPTExample(firstSetWeight: firstWeight)
    }
    
    func getAppVersion() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(appVersion) (\(buildNumber))"
    }

    func allowedDropPercentageRange(for index: Int) -> ClosedRange<Double> {
        guard defaultRPTPercentageDrops.indices.contains(index), index > 0 else {
            return 0...0
        }

        let minimum = index > 1
            ? defaultRPTPercentageDrops[index - 1] * 100
            : 0

        let maximum = index < defaultRPTPercentageDrops.count - 1
            ? defaultRPTPercentageDrops[index + 1] * 100
            : 30

        let clampedMinimum = min(max(minimum, 0), 30)
        let clampedMaximum = min(max(maximum, clampedMinimum), 30)
        return clampedMinimum...clampedMaximum
    }

    func updateDropPercentage(at index: Int, to newValue: Double) {
        guard defaultRPTPercentageDrops.indices.contains(index), index > 0 else {
            return
        }

        let allowedRange = allowedDropPercentageRange(for: index)
        let clampedValue = min(max(newValue, allowedRange.lowerBound), allowedRange.upperBound)

        var newDrops = defaultRPTPercentageDrops
        newDrops[index] = clampedValue / 100
        defaultRPTPercentageDrops = newDrops
    }

    private var customizedSettingLabels: [String] {
        var labels: [String] = []

        if darkModePreference != .system {
            labels.append("Dark Mode")
        }

        if restTimerDuration != UserSettings.defaultRestTimerDuration {
            labels.append("Rest Timer")
        }

        if showRPE != true {
            labels.append("Show RPE Input")
        }

        if defaultRPTPercentageDrops != UserSettings.defaultRPTPercentageDrops {
            labels.append("RPT Weight Drops")
        }

        return labels
    }

    private var customizedSettingsSummaryParts: [String] {
        var parts: [String] = []

        if darkModePreference != .system {
            parts.append("Dark Mode (\(darkModePreference.resetSummaryValue))")
        }

        if restTimerDuration != UserSettings.defaultRestTimerDuration {
            parts.append("Rest Timer (\(restTimerDuration) sec)")
        }

        if showRPE != true {
            parts.append("Show RPE Input (Off)")
        }

        if defaultRPTPercentageDrops != UserSettings.defaultRPTPercentageDrops {
            parts.append("RPT weight drops (\(Self.formattedRPTDropSummary(defaultRPTPercentageDrops)))")
        }

        return parts
    }

    private func syncFromPersistedSettings() {
        isSyncingFromPersistedSettings = true
        restTimerDuration = settingsManager.settings.restTimerDuration
        defaultRPTPercentageDrops = settingsManager.settings.defaultRPTPercentageDrops
        showRPE = settingsManager.settings.showRPE
        darkModePreference = settingsManager.settings.darkModePreference
        isSyncingFromPersistedSettings = false
    }

    private func presentSaveError(title: String, message: String) {
        saveErrorTitle = title
        saveErrorMessage = message
    }

    private static func formattedRPTDropSummary(_ drops: [Double]) -> String {
        drops
            .map { "\(Int(($0 == 0 ? 1 : 1 - $0) * 100))%" }
            .joined(separator: ", ")
    }

    private static func humanReadableList(_ items: [String]) -> String {
        switch items.count {
        case 0:
            return ""
        case 1:
            return items[0]
        case 2:
            return "\(items[0]) and \(items[1])"
        default:
            let head = items.dropLast().joined(separator: ", ")
            return "\(head), and \(items.last!)"
        }
    }
}

private extension DarkModePreference {
    var resetSummaryValue: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .system:
            return "System"
        }
    }
}
