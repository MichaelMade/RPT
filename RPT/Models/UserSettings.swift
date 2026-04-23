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
    private static let defaultDrops: [Double] = [0.0, 0.10, 0.15]

    var restTimerDuration: Int // in seconds
    var defaultRPTPercentageDropsString: String = "0.000,0.100,0.150" // Stored as a comma-separated string with default
    var showRPE: Bool
    var darkModePreference: DarkModePreference
    
    // Computed property to access as array
    var defaultRPTPercentageDrops: [Double] {
        get {
            let parsedDrops = defaultRPTPercentageDropsString.split(separator: ",")
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }

            return Self.normalizedRPTPercentageDrops(parsedDrops)
        }
        set {
            let normalizedDrops = Self.normalizedRPTPercentageDrops(newValue)
            defaultRPTPercentageDropsString = normalizedDrops
                .map { String(format: "%.3f", $0) }
                .joined(separator: ",")
        }
    }

    static func normalizedRPTPercentageDrops(_ drops: [Double]) -> [Double] {
        let validDrops = drops
            .filter { $0.isFinite && $0 >= 0 && $0 <= 1.0 }

        guard !validDrops.isEmpty else {
            return defaultDrops
        }

        let hasTopSet = validDrops.contains(0.0)
        let sortedBackoffDrops = validDrops
            .filter { $0 > 0 }
            .sorted()

        let normalizedDrops = (hasTopSet ? [0.0] : [0.0]) + sortedBackoffDrops

        var dedupedDrops: [Double] = []
        dedupedDrops.reserveCapacity(normalizedDrops.count)

        for drop in normalizedDrops where dedupedDrops.last != drop {
            dedupedDrops.append(drop)
        }

        return dedupedDrops.isEmpty ? defaultDrops : dedupedDrops
    }
    
    init(
         restTimerDuration: Int = 180,
         defaultRPTPercentageDrops: [Double] = [0.0, 0.10, 0.15],
         showRPE: Bool = true,
         darkModePreference: DarkModePreference = .system) {
        self.restTimerDuration = restTimerDuration
        self.defaultRPTPercentageDropsString = Self.normalizedRPTPercentageDrops(defaultRPTPercentageDrops)
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
