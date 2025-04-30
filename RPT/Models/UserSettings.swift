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
    var defaultRPTPercentageDrops: [Double] // e.g. [0.0, 0.10, 0.20]
    var showRPE: Bool
    var darkModePreference: DarkModePreference
    
    init(
         restTimerDuration: Int = 90,
         defaultRPTPercentageDrops: [Double] = [0.0, 0.10, 0.15],
         showRPE: Bool = true,
         darkModePreference: DarkModePreference = .system) {
        self.restTimerDuration = restTimerDuration
        self.defaultRPTPercentageDrops = defaultRPTPercentageDrops
        self.showRPE = showRPE
        self.darkModePreference = darkModePreference
    }
}

enum DarkModePreference: String, Codable, CaseIterable {
    case light
    case dark
    case system
}
