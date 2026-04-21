//
//  PlateCalculator.swift
//  RPT
//

import Foundation

enum WeightUnit: String, CaseIterable, Codable {
    case pounds
    case kilograms

    var short: String {
        switch self {
        case .pounds: return "lb"
        case .kilograms: return "kg"
        }
    }
}

struct BarbellType: Hashable, Identifiable {
    let id = UUID()
    let name: String
    let weightLb: Double
    let weightKg: Double

    static let olympic = BarbellType(name: "Olympic (45 lb / 20 kg)", weightLb: 45, weightKg: 20)
    static let womensOlympic = BarbellType(name: "Women's Olympic (35 lb / 15 kg)", weightLb: 35, weightKg: 15)
    static let ezCurl = BarbellType(name: "EZ Curl (15 lb / 7 kg)", weightLb: 15, weightKg: 7)
    static let trap = BarbellType(name: "Trap Bar (60 lb / 25 kg)", weightLb: 60, weightKg: 25)
    static let none = BarbellType(name: "No Barbell", weightLb: 0, weightKg: 0)

    static let all: [BarbellType] = [.olympic, .womensOlympic, .ezCurl, .trap, .none]

    func weight(in unit: WeightUnit) -> Double {
        unit == .pounds ? weightLb : weightKg
    }
}

struct PlateCalculator {
    // Default plate inventories available in most gyms
    static let defaultLbPlates: [Double] = [45, 35, 25, 10, 5, 2.5]
    static let defaultKgPlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    struct Result: Equatable {
        let platesPerSide: [(weight: Double, count: Int)]
        let achievedWeight: Double
        let targetWeight: Double
        let leftover: Double

        var isExact: Bool { abs(leftover) < 0.001 }

        static func == (lhs: Result, rhs: Result) -> Bool {
            lhs.achievedWeight == rhs.achievedWeight &&
            lhs.targetWeight == rhs.targetWeight &&
            lhs.leftover == rhs.leftover &&
            lhs.platesPerSide.map { $0.weight } == rhs.platesPerSide.map { $0.weight } &&
            lhs.platesPerSide.map { $0.count } == rhs.platesPerSide.map { $0.count }
        }
    }

    /// Calculate plates to load on each side. Always uses a greedy descending algorithm.
    /// `availablePlates` is per-side in the user's chosen unit, sorted descending by weight.
    static func calculate(
        targetWeight: Double,
        barbell: BarbellType,
        unit: WeightUnit,
        availablePlates: [Double]
    ) -> Result {
        let plates = availablePlates.sorted(by: >).filter { $0 > 0 }
        let barWeight = barbell.weight(in: unit)
        let weightOnBar = max(0, targetWeight - barWeight)
        let weightPerSide = weightOnBar / 2.0

        var remaining = weightPerSide
        var breakdown: [(weight: Double, count: Int)] = []

        for plate in plates {
            guard plate <= remaining + 0.0001 else { continue }
            let count = Int((remaining + 0.0001) / plate)
            if count > 0 {
                breakdown.append((weight: plate, count: count))
                remaining -= Double(count) * plate
            }
        }

        let loadedPerSide = breakdown.reduce(0.0) { $0 + $1.weight * Double($1.count) }
        let achieved = barWeight + loadedPerSide * 2.0

        return Result(
            platesPerSide: breakdown,
            achievedWeight: achieved,
            targetWeight: targetWeight,
            leftover: targetWeight - achieved
        )
    }
}
