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
protocol SettingsManaging: AnyObject {
    var settings: UserSettings { get }
    func updateSettings() throws
    func updateSettingsSafely() -> Bool
    func updateRestTimerDuration(seconds: Int) throws
    func updateRestTimerDurationSafely(seconds: Int) -> Bool
    func updateRPTPercentageDrops(drops: [Double]) throws
    func updateRPTPercentageDropsSafely(drops: [Double]) -> Bool
    func updateShowRPE(show: Bool) throws
    func updateShowRPESafely(show: Bool) -> Bool
    func updateDarkModePreference(preference: DarkModePreference) throws
    func updateDarkModePreferenceSafely(preference: DarkModePreference) -> Bool
    func resetToDefaults() throws
    func resetToDefaultsSafely() -> Bool
    func calculateRPTExample(firstSetWeight: Int) -> String
}

@MainActor
class SettingsManager: ObservableObject, SettingsManaging {
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
    private let dataManager: DataManaging
    static let shared = SettingsManager()
    
    @Published var settings: UserSettings
    
    init(dataManager: DataManaging = DataManager.shared) {
        self.dataManager = dataManager
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

            try sanitizePersistedSettingsIfNeeded()
            
            // Sync settings with UserDefaults for @AppStorage compatibility
            syncWithUserDefaults()
        } catch {
            print("Error initializing settings: \(error)")
            // Keep using the default settings created above
            
            // Sync default settings with UserDefaults
            syncWithUserDefaults()
        }
    }

    private func sanitizePersistedSettingsIfNeeded() throws {
        let normalizedRestTimer = UserSettings.normalizedRestTimerDuration(settings.restTimerDuration)
        let normalizedDrops = UserSettings.normalizedRPTPercentageDrops(settings.defaultRPTPercentageDrops)
        let normalizedDropsString = normalizedDrops
            .map { String(format: "%.3f", $0) }
            .joined(separator: ",")

        let didChange = normalizedRestTimer != settings.restTimerDuration ||
            normalizedDropsString != settings.defaultRPTPercentageDropsString

        guard didChange else { return }

        settings.restTimerDuration = normalizedRestTimer
        settings.defaultRPTPercentageDrops = normalizedDrops
        try dataManager.saveChanges()
    }
    
    // Helper method to sync SwiftData settings with UserDefaults
    private func syncWithUserDefaults() {
        UserDefaults.standard.set(settings.showRPE, forKey: "showRPE")
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
    
    private struct SettingsSnapshot {
        let restTimerDuration: Int
        let defaultRPTPercentageDrops: [Double]
        let showRPE: Bool
        let darkModePreference: DarkModePreference
    }

    private func makeSnapshot() -> SettingsSnapshot {
        SettingsSnapshot(
            restTimerDuration: settings.restTimerDuration,
            defaultRPTPercentageDrops: settings.defaultRPTPercentageDrops,
            showRPE: settings.showRPE,
            darkModePreference: settings.darkModePreference
        )
    }

    private func restore(_ snapshot: SettingsSnapshot) {
        settings.restTimerDuration = snapshot.restTimerDuration
        settings.defaultRPTPercentageDrops = snapshot.defaultRPTPercentageDrops
        settings.showRPE = snapshot.showRPE
        settings.darkModePreference = snapshot.darkModePreference
    }

    private func commitSettingsChange(syncUserDefaults: Bool = true) throws {
        do {
            try dataManager.saveChanges()
            if syncUserDefaults {
                syncWithUserDefaults()
            }
            objectWillChange.send()
        } catch {
            print("Error updating settings: \(error)")
            throw SettingsError.saveFailed
        }
    }

    func updateSettings() throws {
        try commitSettingsChange()
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

        let snapshot = makeSnapshot()
        settings.restTimerDuration = seconds
        do {
            try commitSettingsChange(syncUserDefaults: false)
        } catch {
            restore(snapshot)
            throw error
        }
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
        let normalizedDrops = UserSettings.normalizedRPTPercentageDrops(drops)

        guard drops.count == UserSettings.supportedRPTSetCount,
              normalizedDrops == drops else {
            throw SettingsError.invalidValue
        }

        let snapshot = makeSnapshot()
        settings.defaultRPTPercentageDrops = drops
        do {
            try commitSettingsChange(syncUserDefaults: false)
        } catch {
            restore(snapshot)
            throw error
        }
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
        let snapshot = makeSnapshot()
        settings.showRPE = show

        do {
            try commitSettingsChange()
        } catch {
            restore(snapshot)
            syncWithUserDefaults()
            throw error
        }
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
        let snapshot = makeSnapshot()
        settings.darkModePreference = preference
        do {
            try commitSettingsChange(syncUserDefaults: false)
        } catch {
            restore(snapshot)
            throw error
        }
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
        let snapshot = makeSnapshot()
        settings.restTimerDuration = UserSettings.defaultRestTimerDuration
        settings.defaultRPTPercentageDrops = UserSettings.defaultRPTPercentageDrops
        settings.showRPE = true
        settings.darkModePreference = .system

        do {
            try commitSettingsChange()
        } catch {
            restore(snapshot)
            syncWithUserDefaults()
            throw error
        }
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

        guard !weights.isEmpty else {
            return "Top set only"
        }

        return weights.map { "\($0)" }.joined(separator: " → ") + " lb"
    }
    
    // Format weight with lb unit
    func formatWeight(_ weight: Int, useUnit: Bool = true) -> String {
        let safeWeight = max(0, weight)
        let formatted = "\(safeWeight)"
        return useUnit ? "\(formatted) lb" : formatted
    }
    
    // Format weight with lb unit (Double version)
    func formatWeight(_ weight: Double, useUnit: Bool = true) -> String {
        let safeWeight = weight.isFinite ? max(0, weight) : 0
        let formatted = String(format: "%.1f", safeWeight)
        return useUnit ? "\(formatted) lb" : formatted
    }
}
