//
//  WarmupPlanView.swift
//  RPT
//
//  Shows a generated warm-up ramp for the exercise's top set and adds
//  the steps to the workout in one tap.
//

import SwiftUI

struct WarmupPlanView: View {
    @Environment(\.dismiss) private var dismiss

    let topSetWeight: Int
    let onAdd: ([WarmupStep]) -> Void

    private var steps: [WarmupStep] {
        WarmupPlanner.plan(topSetWeight: topSetWeight)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if topSetWeight <= 0 {
                    EmptyStateCard(
                        icon: "thermometer.low",
                        title: "Set a Top-Set Weight First",
                        message: "Enter the weight for your first working set and RPT will build a low-fatigue warm-up ramp toward it."
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(steps) { step in
                            HStack {
                                Image(systemName: "thermometer.low")
                                    .foregroundStyle(Theme.amber)

                                Text(step.weight == 0 ? "Bodyweight" : (step.weight == WarmupPlanner.barWeight ? "Empty bar" : "\(step.weight) lb"))
                                    .font(.subheadline.weight(.semibold))

                                Spacer()

                                Text("× \(step.reps) reps")
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .rptCard(padding: 12)
                        }
                    }

                    Text("Ramping toward your \(topSetWeight) lb top set. Low reps keep fatigue away from the set that counts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        onAdd(steps)
                        dismiss()
                    } label: {
                        Label("Add Warm-up Sets", systemImage: "plus")
                    }
                    .buttonStyle(BrandButtonStyle())
                }

                Spacer(minLength: 0)
            }
            .padding(Theme.screenPadding)
            .background(Theme.screenBackground)
            .navigationTitle("Warm-up Ramp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
