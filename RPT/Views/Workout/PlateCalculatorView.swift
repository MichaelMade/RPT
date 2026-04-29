//
//  PlateCalculatorView.swift
//  RPT
//

import SwiftUI

struct PlateCalculatorView: View {
    enum BreakdownStatus: Equatable {
        case validation(message: String)
        case barOnly(message: String)
        case unavailable(message: String)
        case calculated
    }

    @Environment(\.dismiss) private var dismiss

    @State private var targetText: String = "135"
    @State private var barbell: BarbellType = .olympic
    @State private var unit: WeightUnit = .pounds
    @State private var availableLbPlates: Set<Double> = Set(PlateCalculator.defaultLbPlates)
    @State private var availableKgPlates: Set<Double> = Set(PlateCalculator.defaultKgPlates)

    private var currentAvailablePlates: [Double] {
        unit == .pounds
            ? PlateCalculator.defaultLbPlates.filter(availableLbPlates.contains)
            : PlateCalculator.defaultKgPlates.filter(availableKgPlates.contains)
    }

    private var targetWeight: Double? {
        Self.sanitizedTargetWeight(from: targetText)
    }

    private var result: PlateCalculator.Result {
        PlateCalculator.calculate(
            targetWeight: targetWeight ?? 0,
            barbell: barbell,
            unit: unit,
            availablePlates: currentAvailablePlates
        )
    }

    private var breakdownStatus: BreakdownStatus {
        Self.breakdownStatus(
            rawTargetText: targetText,
            barbell: barbell,
            unit: unit,
            result: result
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Target") {
                    HStack {
                        TextField("Weight", text: $targetText)
                            .keyboardType(.decimalPad)
                            .font(.system(.title2, design: .monospaced))
                        Picker("", selection: $unit) {
                            ForEach(WeightUnit.allCases, id: \.self) { unit in
                                Text(unit.short).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }

                    Picker("Barbell", selection: $barbell) {
                        ForEach(BarbellType.all) { bar in
                            Text(bar.name).tag(bar)
                        }
                    }
                }

                Section("Plates Per Side") {
                    switch breakdownStatus {
                    case .validation(let message), .unavailable(let message):
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundColor(.orange)

                    case .barOnly(let message):
                        Text(message)
                            .foregroundColor(.secondary)

                    case .calculated:
                        ForEach(Array(result.platesPerSide.enumerated()), id: \.offset) { _, plate in
                            HStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(plateColor(plate.weight))
                                    .frame(width: 24, height: 34)
                                Text("\(formatted(plate.weight)) \(unit.short)")
                                    .font(.body.monospacedDigit())
                                Spacer()
                                Text("× \(plate.count)")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text("Total loaded")
                                .font(.subheadline)
                            Spacer()
                            Text("\(formatted(result.achievedWeight)) \(unit.short)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundColor(result.isExact ? .primary : .orange)
                        }

                        if !result.isExact {
                            Text("Can't make \(formatted(result.targetWeight)) exactly with the selected plates — short by \(formatted(result.leftover)) \(unit.short).")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Section("Available Plates (per side)") {
                    let allPlates = unit == .pounds ? PlateCalculator.defaultLbPlates : PlateCalculator.defaultKgPlates
                    ForEach(allPlates, id: \.self) { plate in
                        Toggle(isOn: plateBinding(for: plate)) {
                            HStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(plateColor(plate))
                                    .frame(width: 16, height: 24)
                                Text("\(formatted(plate)) \(unit.short)")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    static func sanitizedTargetWeight(from rawText: String) -> Double? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty,
              let parsedValue = Double(trimmed),
              parsedValue.isFinite,
              parsedValue > 0 else {
            return nil
        }

        return parsedValue
    }

    static func formattedWeight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.2f", value)
    }

    static func breakdownStatus(
        rawTargetText: String,
        barbell: BarbellType,
        unit: WeightUnit,
        result: PlateCalculator.Result
    ) -> BreakdownStatus {
        let trimmedTarget = rawTargetText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTarget.isEmpty else {
            return .validation(message: "Enter a target weight to see the plate breakdown.")
        }

        guard let targetWeight = sanitizedTargetWeight(from: trimmedTarget) else {
            return .validation(message: "Enter a valid positive target weight.")
        }

        let barWeight = barbell.weight(in: unit)
        if targetWeight < barWeight {
            return .validation(
                message: "Target is less than the selected bar weight (\(formattedWeight(barWeight)) \(unit.short))."
            )
        }

        if abs(targetWeight - barWeight) < 0.001 {
            return .barOnly(message: "Just the bar (\(formattedWeight(barWeight)) \(unit.short))")
        }

        let isOnlyBarLoadable = result.platesPerSide.isEmpty && abs(result.achievedWeight - barWeight) < 0.001
        if isOnlyBarLoadable {
            return .unavailable(
                message: "Can't make \(formattedWeight(targetWeight)) \(unit.short) with the selected plates — currently only the bar is loadable."
            )
        }

        return .calculated
    }

    private func plateBinding(for plate: Double) -> Binding<Bool> {
        Binding(
            get: {
                unit == .pounds ? availableLbPlates.contains(plate) : availableKgPlates.contains(plate)
            },
            set: { newValue in
                if unit == .pounds {
                    if newValue { availableLbPlates.insert(plate) } else { availableLbPlates.remove(plate) }
                } else {
                    if newValue { availableKgPlates.insert(plate) } else { availableKgPlates.remove(plate) }
                }
            }
        )
    }

    private func formatted(_ value: Double) -> String {
        Self.formattedWeight(value)
    }

    private func plateColor(_ weight: Double) -> Color {
        switch weight {
        case 45, 20:    return .red
        case 35, 15:    return .blue
        case 25, 10:    return .green
        case 5:         return .yellow
        case 2.5, 1.25: return .gray
        default:        return .secondary
        }
    }
}

#Preview {
    PlateCalculatorView()
}
