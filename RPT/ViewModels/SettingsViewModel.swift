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
    private let settingsManager: SettingsManager
    private var isSyncingFromPersistedSettings = false
    
    @Published var restTimerDuration: Int {
        didSet {
            guard !isSyncingFromPersistedSettings else { return }

            if !settingsManager.updateRestTimerDurationSafely(seconds: restTimerDuration) {
                syncFromPersistedSettings()
            }
        }
    }
    
    @Published var defaultRPTPercentageDrops: [Double] {
        didSet {
            guard !isSyncingFromPersistedSettings else { return }

            if !settingsManager.updateRPTPercentageDropsSafely(drops: defaultRPTPercentageDrops) {
                syncFromPersistedSettings()
            }
        }
    }
    
    @Published var showRPE: Bool {
        didSet {
            guard !isSyncingFromPersistedSettings else { return }

            if !settingsManager.updateShowRPESafely(show: showRPE) {
                syncFromPersistedSettings()
            }
        }
    }
    
    @Published var darkModePreference: DarkModePreference {
        didSet {
            guard !isSyncingFromPersistedSettings else { return }

            if !settingsManager.updateDarkModePreferenceSafely(preference: darkModePreference) {
                syncFromPersistedSettings()
            }
        }
    }
    
    init(settingsManager: SettingsManager? = nil) {
        self.settingsManager = settingsManager ?? SettingsManager.shared
                
        // Initialize published properties from settings
        self.restTimerDuration = self.settingsManager.settings.restTimerDuration
        self.defaultRPTPercentageDrops = self.settingsManager.settings.defaultRPTPercentageDrops
        self.showRPE = self.settingsManager.settings.showRPE
        self.darkModePreference = self.settingsManager.settings.darkModePreference
    }
    
    func resetToDefaults() {
        _ = settingsManager.resetToDefaultsSafely()

        syncFromPersistedSettings()
    }
    
    func calculateExample(firstWeight: Int = 225) -> String {
        return settingsManager.calculateRPTExample(firstSetWeight: firstWeight)
    }
    
    func getAppVersion() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(appVersion) (\(buildNumber))"
    }

    private func syncFromPersistedSettings() {
        isSyncingFromPersistedSettings = true
        restTimerDuration = settingsManager.settings.restTimerDuration
        defaultRPTPercentageDrops = settingsManager.settings.defaultRPTPercentageDrops
        showRPE = settingsManager.settings.showRPE
        darkModePreference = settingsManager.settings.darkModePreference
        isSyncingFromPersistedSettings = false
    }
}
