//
//  UserSettings.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import Foundation
import SwiftData

@Model
final class UserSettings {
    var restTimerDuration: Int // in seconds
    var defaultRPTPercentageDropsString: String = "0.000,0.100,0.150" // Stored as a comma-separated string with default
    var showRPE: Bool
    var darkModePreference: DarkModePreference
    
    // Computed property to access as array
    var defaultRPTPercentageDrops: [Double] {
        get {
            return defaultRPTPercentageDropsString.split(separator: ",")
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) } 
                .filter { $0 >= 0 && $0 <= 1.0 }
        }
        set {
            defaultRPTPercentageDropsString = newValue
                .map { String(format: "%.3f", $0) }
                .joined(separator: ",")
        }
    }
    
    init(
         restTimerDuration: Int = 180,
         defaultRPTPercentageDrops: [Double] = [0.0, 0.10, 0.15],
         showRPE: Bool = true,
         darkModePreference: DarkModePreference = .system) {
        self.restTimerDuration = restTimerDuration
        self.defaultRPTPercentageDropsString = defaultRPTPercentageDrops
            .map { String(format: "%.3f", $0) }
            .joined(separator: ",")
        self.showRPE = showRPE
        self.darkModePreference = darkModePreference
    }
}

enum DarkModePreference: String, Codable, CaseIterable {
    case light
    case dark
    case system
}
