//
//  RPTCalculatorView.swift
//  RPT
//
//  Plans a reverse pyramid session from a top-set weight using the
//  configured percentage drops.
//

import SwiftUI

struct RPTCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsManager = SettingsManager.shared
    @AppStorage(WeightUnit.defaultsKey) private var weightUnit: WeightUnit = .pounds

    @State private var topSetText: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.sectionSpacing) {
                    inputCard
                    resultsCard
                    explainerCard
                }
                .padding(Theme.screenPadding)
            }
            .background(Theme.screenBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("RPT Calculator")
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
        }
    }

    private var inputCard: some View {
        VStack(spacing: 10) {
            Text("Top-Set Weight")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                TextField(weightUnit == .pounds ? "e.g. 225" : "e.g. 100", text: $topSetText)
                    .keyboardType(weightUnit.entryFractionDigits > 0 ? .decimalPad : .numberPad)
                    .font(Theme.statFont(size: 32))
                    .focused($isInputFocused)

                Text(weightUnit.short)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .rptCard()
    }

    /// The top set, in the lifter's unit.
    private var topSetLoad: Double {
        SetInputParser.load(from: topSetText, unit: weightUnit) ?? 0
    }

    @ViewBuilder
    private var resultsCard: some View {
        if topSetLoad > 0 {
            let drops = settingsManager.settings.defaultRPTPercentageDrops
            let weights = WorkoutManager.shared.calculateRPTWeights(
                firstSetWeight: topSetLoad,
                percentageDrops: drops
            )

            VStack(spacing: 10) {
                ForEach(Array(weights.enumerated()), id: \.offset) { index, weight in
                    // The top set is the lifter's own number; only the
                    // calculated back-offs are rounded to a loadable weight.
                    let rounded = index == 0 ? topSetLoad : weightUnit.roundedToIncrement(weight)

                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .frame(width: 26, height: 26)
                            .background(Theme.accent.opacity(0.12), in: Circle())
                            .foregroundStyle(Theme.accent)

                        Text(index == 0 ? "Top set" : "Back-off \(index)")
                            .font(.subheadline.weight(.medium))

                        Spacer()

                        if index > 0 {
                            Text("−\(Int((drops[safe: index] ?? 0) * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(weightUnit.formatted(rounded))
                            .font(.headline)
                            .monospacedDigit()
                    }
                    .rptCard(padding: 12)
                }
            }
        }
    }

    private var explainerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("How RPT works", systemImage: "info.circle")
                .font(.subheadline.weight(.semibold))

            Text("Your heaviest set comes first, while you're fresh. Each back-off set drops the weight by your configured percentage and adds a couple of reps. Adjust the drops in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rptCard()
    }
}
