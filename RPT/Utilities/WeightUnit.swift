//
//  WeightUnit.swift
//  RPT
//
//  The unit the lifter trains in, and everything that follows from it: how
//  a load is converted, rounded to something that can be put on a bar,
//  typed, and shown.
//
//  Totals (volume, estimated 1RM, records) are always computed in pounds
//  from each set's exact load and converted once for display. Only entry,
//  suggested loads and display work in the lifter's own unit, because those
//  are the places where "a number you can actually load" matters.
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

    /// For settings and pickers.
    var displayName: String {
        switch self {
        case .pounds: return "Pounds"
        case .kilograms: return "Kilograms"
        }
    }

    // MARK: - The lifter's choice

    static let defaultsKey = "training.weightUnit"

    /// The unit loads are entered and shown in. Pounds until the lifter
    /// chooses otherwise: every load logged before this setting existed is
    /// in pounds, so nobody's history changes meaning on update.
    static var current: WeightUnit {
        get { stored(in: .standard) ?? .pounds }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }

    static func stored(in defaults: UserDefaults) -> WeightUnit? {
        defaults.string(forKey: defaultsKey).flatMap(WeightUnit.init(rawValue:))
    }

    /// The unit a first-time lifter most likely trains in. Only the United
    /// States loads its bars in pounds.
    static func suggested(for locale: Locale = .current) -> WeightUnit {
        locale.measurementSystem == .us ? .pounds : .kilograms
    }

    // MARK: - Conversion

    /// Exact by definition: one pound is 0.45359237 kg.
    static let kilogramsPerPound = 0.45359237

    /// `value`, given in `source`, expressed in this unit.
    func converting(_ value: Double, from source: WeightUnit) -> Double {
        guard value.isFinite else { return 0 }

        switch (source, self) {
        case (.pounds, .pounds), (.kilograms, .kilograms):
            return value
        case (.pounds, .kilograms):
            return value * Self.kilogramsPerPound
        case (.kilograms, .pounds):
            return value / Self.kilogramsPerPound
        }
    }

    // MARK: - Loads you can put on a bar

    /// The step RPT rounds its own suggestions to: back-off sets, warm-ups,
    /// follow-up targets.
    var loadIncrement: Double {
        switch self {
        case .pounds: return 5
        case .kilograms: return 2.5
        }
    }

    var emptyBarLoad: Double {
        switch self {
        case .pounds: return 45
        case .kilograms: return 20
        }
    }

    /// Sanity ceiling for one set. Far above any real load; it keeps a slip
    /// of the thumb out of history and out of volume math.
    var maximumLoad: Double {
        switch self {
        case .pounds: return 9_999
        case .kilograms: return 4_500
        }
    }

    /// Decimal places a lifter may type. Kilogram plates go down to 0.25 kg
    /// a side; pounds are logged whole.
    var entryFractionDigits: Int {
        switch self {
        case .pounds: return 0
        case .kilograms: return 2
        }
    }

    /// Nearest load RPT would suggest, never negative.
    func roundedToIncrement(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return 0 }
        return (value / loadIncrement).rounded() * loadIncrement
    }

    /// A typed or computed load with float noise removed: whole pounds, or
    /// kilograms to the hundredth.
    func normalized(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return 0 }

        switch self {
        case .pounds:
            return value.rounded()
        case .kilograms:
            return (value * 100).rounded() / 100
        }
    }

    /// Whether two loads would be written the same way in this unit. Used
    /// to tell a real change from a value that merely passed through a
    /// conversion and back.
    func displaysSameLoad(_ lhs: Double, _ rhs: Double) -> Bool {
        string(for: lhs) == string(for: rhs)
    }

    // MARK: - Display

    /// The load as a lifter would write it, without the unit.
    ///
    /// Pounds are whole. Kilograms show plate-sized values exactly (62.5,
    /// 61.25) and anything else, such as a converted pound load, to one
    /// decimal (102.1).
    func string(for value: Double) -> String {
        guard value.isFinite, value > 0 else { return "0" }

        switch self {
        case .pounds:
            return String(Int(value.rounded()))
        case .kilograms:
            let hundredths = Int((value * 100).rounded())
            if hundredths % 25 == 0 {
                return Self.trimmed(hundredths: hundredths)
            }
            let tenths = Int((value * 10).rounded())
            return Self.trimmed(hundredths: tenths * 10)
        }
    }

    /// The load with its unit: "135 lb", "62.5 kg".
    func formatted(_ value: Double) -> String {
        "\(string(for: value)) \(short)"
    }

    /// A value held in pounds (a total, an estimate, a stored whole-pound
    /// load), written in this unit.
    func string(forPounds pounds: Double) -> String {
        string(for: converting(pounds, from: .pounds))
    }

    func formatted(pounds: Double) -> String {
        formatted(converting(pounds, from: .pounds))
    }

    private static func trimmed(hundredths: Int) -> String {
        let whole = hundredths / 100
        let fraction = hundredths % 100

        if fraction == 0 {
            return String(whole)
        }
        if fraction % 10 == 0 {
            return "\(whole).\(fraction / 10)"
        }
        return "\(whole)." + (fraction < 10 ? "0\(fraction)" : "\(fraction)")
    }
}
