//
//  SettingsManager.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class SettingsManager: ObservableObject {
    private let modelContext: ModelContext
    static let shared = SettingsManager()
    
    @Published var settings: UserSettings
    
    private init() {
        let dataManager = DataManager.shared
        self.modelContext = dataManager.getModelContext()
        
        // Fetch or create settings
        let descriptor = FetchDescriptor<UserSettings>()
        if let existingSettings = try? modelContext.fetch(descriptor).first {
            self.settings = existingSettings
        } else {
            let newSettings = UserSettings()
            modelContext.insert(newSettings)
            try? modelContext.save()
            self.settings = newSettings
        }
    }
    
    // MARK: - Settings Operations
    
    func updateSettings() {
        try? modelContext.save()
        objectWillChange.send()
    }
    
    func updateRestTimerDuration(seconds: Int) {
        settings.restTimerDuration = seconds
        updateSettings()
    }
    
    func updateRPTPercentageDrops(drops: [Double]) {
        settings.defaultRPTPercentageDrops = drops
        updateSettings()
    }
    
    func updateShowRPE(show: Bool) {
        settings.showRPE = show
        updateSettings()
    }
    
    func updateDarkModePreference(preference: DarkModePreference) {
        settings.darkModePreference = preference
        updateSettings()
    }
    
    func resetToDefaults() {
        settings.restTimerDuration = 90
        settings.defaultRPTPercentageDrops = [0.0, 0.10, 0.15]
        settings.showRPE = true
        settings.darkModePreference = .system
        
        updateSettings()
    }
    
    // MARK: - Helper Methods
    
    func calculateRPTExample(firstSetWeight: Double = 100.0) -> String {
        let drops = settings.defaultRPTPercentageDrops
        let weights = drops.map { firstSetWeight * (1 - $0) }
        return weights.dropFirst().map { String(format: "%.1f", $0) }.joined(separator: " → ") + " lb"
    }
    
    // Format weight with lb unit
    func formatWeight(_ weight: Double, useUnit: Bool = true) -> String {
        let formatted = String(format: "%.1f", weight)
        return useUnit ? "\(formatted) lb" : formatted
    }
}
