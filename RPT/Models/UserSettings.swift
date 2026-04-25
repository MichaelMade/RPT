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
    static let defaultRPTPercentageDrops: [Double] = [0.0, 0.10, 0.15]
    static let supportedRPTSetCount: Int = 3
    static let defaultRestTimerDuration: Int = 180

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
            return defaultRPTPercentageDrops
        }

        let sortedBackoffDrops = validDrops
            .filter { $0 > 0 }
            .sorted()

        let normalizedDrops = [0.0] + sortedBackoffDrops

        var dedupedDrops: [Double] = []
        dedupedDrops.reserveCapacity(normalizedDrops.count)

        for drop in normalizedDrops where dedupedDrops.last != drop {
            dedupedDrops.append(drop)
        }

        var fixedDrops = Array(dedupedDrops.prefix(supportedRPTSetCount))

        while fixedDrops.count < supportedRPTSetCount {
            let fallback = defaultRPTPercentageDrops[fixedDrops.count]
            let previous = fixedDrops.last ?? 0.0
            fixedDrops.append(max(previous, fallback))
        }

        return fixedDrops
    }

    static func normalizedRestTimerDuration(_ duration: Int) -> Int {
        min(max(duration, 1), 3600)
    }
    
    init(
         restTimerDuration: Int = defaultRestTimerDuration,
         defaultRPTPercentageDrops: [Double] = UserSettings.defaultRPTPercentageDrops,
         showRPE: Bool = true,
         darkModePreference: DarkModePreference = .system) {
        self.restTimerDuration = Self.normalizedRestTimerDuration(restTimerDuration)
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
