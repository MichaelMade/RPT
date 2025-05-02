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
    
    @Published var restTimerDuration: Int {
        didSet {
            _ = settingsManager.updateRestTimerDurationSafely(seconds: restTimerDuration)
        }
    }
    
    @Published var defaultRPTPercentageDrops: [Double] {
        didSet {
            _ = settingsManager.updateRPTPercentageDropsSafely(drops: defaultRPTPercentageDrops)
        }
    }
    
    @Published var showRPE: Bool {
        didSet {
            _ = settingsManager.updateShowRPESafely(show: showRPE)
        }
    }
    
    @Published var darkModePreference: DarkModePreference {
        didSet {
            _ = settingsManager.updateDarkModePreferenceSafely(preference: darkModePreference)
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
        
        // Update local properties
        self.restTimerDuration = settingsManager.settings.restTimerDuration
        self.defaultRPTPercentageDrops = settingsManager.settings.defaultRPTPercentageDrops
        self.showRPE = settingsManager.settings.showRPE
        self.darkModePreference = settingsManager.settings.darkModePreference
    }
    
    func calculateExample(firstWeight: Int = 225) -> String {
        return settingsManager.calculateRPTExample(firstSetWeight: firstWeight)
    }
    
    func getAppVersion() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(appVersion) (\(buildNumber))"
    }
}
