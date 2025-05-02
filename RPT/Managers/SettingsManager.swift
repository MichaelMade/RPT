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
    enum SettingsError: Error {
        case fetchFailed
        case saveFailed
        case settingsNotFound
        case invalidValue
        
        var description: String {
            switch self {
            case .fetchFailed: return "Failed to fetch settings"
            case .saveFailed: return "Failed to save settings"
            case .settingsNotFound: return "Settings not found"
            case .invalidValue: return "Invalid setting value"
            }
        }
    }
    
    private let modelContext: ModelContext
    private let dataManager: DataManager
    static let shared = SettingsManager()
    
    @Published var settings: UserSettings
    
    private init() {
        self.dataManager = DataManager.shared
        self.modelContext = dataManager.getModelContext()
        
        // Initialize with default settings (will be replaced if we can fetch from database)
        self.settings = UserSettings()
        
        // Fetch or create settings
        do {
            if let existingSettings = try fetchSettings() {
                self.settings = existingSettings
            } else {
                // Create new settings if none found
                let newSettings = UserSettings()
                modelContext.insert(newSettings)
                try dataManager.saveChanges()
                self.settings = newSettings
            }
        } catch {
            print("Error initializing settings: \(error)")
            // Keep using the default settings created above
        }
    }
    
    // MARK: - Settings Operations
    
    private func fetchSettings() throws -> UserSettings? {
        let descriptor = FetchDescriptor<UserSettings>()
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("Error fetching settings: \(error)")
            throw SettingsError.fetchFailed
        }
    }
    
    func updateSettings() throws {
        do {
            try dataManager.saveChanges()
            objectWillChange.send()
        } catch {
            print("Error updating settings: \(error)")
            throw SettingsError.saveFailed
        }
    }
    
    // Safe version that doesn't throw (for backward compatibility)
    func updateSettingsSafely() -> Bool {
        do {
            try updateSettings()
            return true
        } catch {
            return false
        }
    }
    
    func updateRestTimerDuration(seconds: Int) throws {
        guard seconds > 0 && seconds <= 3600 else { throw SettingsError.invalidValue }
        
        settings.restTimerDuration = seconds
        try updateSettings()
    }
    
    // Safe version that doesn't throw
    func updateRestTimerDurationSafely(seconds: Int) -> Bool {
        do {
            try updateRestTimerDuration(seconds: seconds)
            return true
        } catch {
            return false
        }
    }
    
    func updateRPTPercentageDrops(drops: [Double]) throws {
        // Validate that drops are between 0.0 and 1.0 and at least the first element is 0.0
        guard !drops.isEmpty, 
              drops.first == 0.0,
              drops.allSatisfy({ $0 >= 0.0 && $0 <= 1.0 }) else {
            throw SettingsError.invalidValue
        }
        
        settings.defaultRPTPercentageDrops = drops
        try updateSettings()
    }
    
    // Safe version that doesn't throw
    func updateRPTPercentageDropsSafely(drops: [Double]) -> Bool {
        do {
            try updateRPTPercentageDrops(drops: drops)
            return true
        } catch {
            return false
        }
    }
    
    func updateShowRPE(show: Bool) throws {
        settings.showRPE = show
        try updateSettings()
    }
    
    // Safe version that doesn't throw
    func updateShowRPESafely(show: Bool) -> Bool {
        do {
            try updateShowRPE(show: show)
            return true
        } catch {
            return false
        }
    }
    
    func updateDarkModePreference(preference: DarkModePreference) throws {
        settings.darkModePreference = preference
        try updateSettings()
    }
    
    // Safe version that doesn't throw
    func updateDarkModePreferenceSafely(preference: DarkModePreference) -> Bool {
        do {
            try updateDarkModePreference(preference: preference)
            return true
        } catch {
            return false
        }
    }
    
    func resetToDefaults() throws {
        settings.restTimerDuration = 180
        settings.defaultRPTPercentageDrops = [0.0, 0.10, 0.15]
        settings.showRPE = true
        settings.darkModePreference = .system
        
        try updateSettings()
    }
    
    // Safe version that doesn't throw
    func resetToDefaultsSafely() -> Bool {
        do {
            try resetToDefaults()
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    func calculateRPTExample(firstSetWeight: Int = 100) -> String {
        let drops = settings.defaultRPTPercentageDrops
        let workoutManager = WorkoutManager.shared
        
        // Convert each drop percentage to a rounded weight
        let weights = drops.dropFirst().map { dropPercentage -> Int in
            let calculatedWeight = Double(firstSetWeight) * (1.0 - dropPercentage)
            return workoutManager.roundToNearest5(calculatedWeight)
        }
        
        return weights.map { "\($0)" }.joined(separator: " → ") + " lb"
    }
    
    // Format weight with lb unit
    func formatWeight(_ weight: Int, useUnit: Bool = true) -> String {
        let formatted = "\(weight)"
        return useUnit ? "\(formatted) lb" : formatted
    }
    
    // Format weight with lb unit (Double version)
    func formatWeight(_ weight: Double, useUnit: Bool = true) -> String {
        let formatted = String(format: "%.1f", weight)
        return useUnit ? "\(formatted) lb" : formatted
    }
}
