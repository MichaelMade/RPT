//
//  PlateCalculatorView.swift
//  RPT
//
//  Loads the bar for you: pick a target weight and barbell, get the
//  plates per side with a visual stack.
//

import SwiftUI

struct PlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss

    var initialTargetWeight: Int = 0

    @State private var targetText: String = ""
    @State private var unit: WeightUnit = .pounds
    @State private var barbell: BarbellType = .olympic
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.sectionSpacing) {
                    inputCard
                    resultCard
                }
                .padding(Theme.screenPadding)
            }
            .background(Theme.screenBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Plate Math")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isInputFocused = false }
                }
            }
            .onAppear {
                if initialTargetWeight > 0 {
                    targetText = "\(initialTargetWeight)"
                }
            }
        }
    }

    // MARK: - Inputs

    private var inputCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Target")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                TextField("0", text: $targetText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(Theme.statFont(size: 28))
                    .frame(maxWidth: 140)
                    .focused($isInputFocused)

                Text(unit.short)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Picker("Unit", selection: $unit) {
                Text("lb").tag(WeightUnit.pounds)
                Text("kg").tag(WeightUnit.kilograms)
            }
            .pickerStyle(.segmented)

            Picker("Barbell", selection: $barbell) {
                ForEach(BarbellType.all) { bar in
                    Text(bar.name).tag(bar)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .rptCard()
    }

    // MARK: - Result

    private var targetWeight: Double {
        Double(targetText.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private var result: PlateCalculator.Result? {
        guard targetWeight > 0 else { return nil }

        let plates = unit == .pounds ? PlateCalculator.defaultLbPlates : PlateCalculator.defaultKgPlates
        return PlateCalculator.calculate(
            targetWeight: targetWeight,
            barbell: barbell,
            unit: unit,
            availablePlates: plates
        )
    }

    @ViewBuilder
    private var resultCard: some View {
        if let result {
            VStack(spacing: 16) {
                if targetWeight < barbell.weight(in: unit) {
                    Label("Target is lighter than the bar (\(formatted(barbell.weight(in: unit))) \(unit.short)).", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.amber)
                } else {
                    plateStack(result)

                    if result.platesPerSide.isEmpty {
                        Text("Empty bar — no plates needed.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 8) {
                            Text("Per side")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            ForEach(result.platesPerSide, id: \.weight) { plate in
                                HStack {
                                    Circle()
                                        .fill(plateColor(plate.weight))
                                        .frame(width: 12, height: 12)
                                    Text("\(formatted(plate.weight)) \(unit.short)")
                                        .font(.subheadline.weight(.medium))
                                        .monospacedDigit()
                                    Spacer()
                                    Text("× \(plate.count)")
                                        .font(.subheadline)
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Divider()

                    LabeledValueRow(
                        label: "Loaded weight",
                        value: "\(formatted(result.achievedWeight)) \(unit.short)",
                        valueTint: result.isExact ? Theme.success : Theme.amber
                    )

                    if !result.isExact {
                        Text("Closest load with standard plates — \(formatted(abs(result.leftover))) \(unit.short) short of target.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .rptCard()
        } else {
            EmptyStateCard(
                icon: "circle.circle",
                title: "Enter a Target Weight",
                message: "RPT will work out exactly which plates to load on each side."
            )
        }
    }

    private func plateStack(_ result: PlateCalculator.Result) -> some View {
        // Visual bar: sleeve + mirrored plates.
        let plates = result.platesPerSide.flatMap { plate in
            Array(repeating: plate.weight, count: plate.count)
        }

        return HStack(spacing: 3) {
            Rectangle()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 26, height: 8)

            ForEach(Array(plates.enumerated()), id: \.offset) { _, weight in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(plateColor(weight))
                    .frame(width: 14, height: plateHeight(weight))
            }

            Rectangle()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 20, height: 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
    }

    private func plateHeight(_ weight: Double) -> CGFloat {
        let maxPlate = unit == .pounds ? 45.0 : 25.0
        let fraction = max(0.3, min(1, weight / maxPlate))
        return CGFloat(30 + 55 * fraction)
    }

    private func plateColor(_ weight: Double) -> Color {
        let maxPlate = unit == .pounds ? 45.0 : 25.0
        let fraction = max(0, min(1, weight / maxPlate))

        if fraction >= 0.95 { return Theme.accentDeep }
        if fraction >= 0.5 { return Theme.accent }
        if fraction >= 0.2 { return Theme.amber }
        return Theme.info
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }
}
