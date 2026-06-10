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

    @State private var topSetText: String = ""

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
            .navigationTitle("RPT Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
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
                TextField("e.g. 225", text: $topSetText)
                    .keyboardType(.numberPad)
                    .font(Theme.statFont(size: 32))

                Text("lb")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .rptCard()
    }

    private var topSetWeight: Int {
        max(0, Int(topSetText.trimmingCharacters(in: .whitespaces)) ?? 0)
    }

    @ViewBuilder
    private var resultsCard: some View {
        if topSetWeight > 0 {
            let drops = settingsManager.settings.defaultRPTPercentageDrops
            let weights = WorkoutManager.shared.calculateRPTWeights(
                firstSetWeight: Double(topSetWeight),
                percentageDrops: drops
            )

            VStack(spacing: 10) {
                ForEach(Array(weights.enumerated()), id: \.offset) { index, weight in
                    let rounded = WorkoutManager.shared.roundToNearest5(weight)

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

                        Text("\(rounded) lb")
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
