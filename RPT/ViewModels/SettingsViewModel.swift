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

    @Published var saveErrorMessage: String?
    
    @Published var restTimerDuration: Int {
        didSet {
            guard !isSyncingFromPersistedSettings else { return }

            if !settingsManager.updateRestTimerDurationSafely(seconds: restTimerDuration) {
                syncFromPersistedSettings()
                presentSaveError("Rest timer changes could not be saved.")
            }
        }
    }
    
    @Published var defaultRPTPercentageDrops: [Double] {
        didSet {
            guard !isSyncingFromPersistedSettings else { return }

            if !settingsManager.updateRPTPercentageDropsSafely(drops: defaultRPTPercentageDrops) {
                syncFromPersistedSettings()
                presentSaveError("RPT drop changes could not be saved.")
            }
        }
    }
    
    @Published var showRPE: Bool {
        didSet {
            guard !isSyncingFromPersistedSettings else { return }

            if !settingsManager.updateShowRPESafely(show: showRPE) {
                syncFromPersistedSettings()
                presentSaveError("RPE visibility changes could not be saved.")
            }
        }
    }
    
    @Published var darkModePreference: DarkModePreference {
        didSet {
            guard !isSyncingFromPersistedSettings else { return }

            if !settingsManager.updateDarkModePreferenceSafely(preference: darkModePreference) {
                syncFromPersistedSettings()
                presentSaveError("Appearance changes could not be saved.")
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

    func resetToDefaults() {
        if !settingsManager.resetToDefaultsSafely() {
            presentSaveError("Settings could not be reset right now.")
        }

        syncFromPersistedSettings()
    }

    func clearSaveError() {
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

    private func syncFromPersistedSettings() {
        isSyncingFromPersistedSettings = true
        restTimerDuration = settingsManager.settings.restTimerDuration
        defaultRPTPercentageDrops = settingsManager.settings.defaultRPTPercentageDrops
        showRPE = settingsManager.settings.showRPE
        darkModePreference = settingsManager.settings.darkModePreference
        isSyncingFromPersistedSettings = false
    }

    private func presentSaveError(_ message: String) {
        saveErrorMessage = message
    }
}
