//
//  StatsView.swift
//  RPT
//
//  Training analytics: lifetime summary, consistency heatmap, weekly
//  volume trend, muscle balance, and e1RM personal records.
//

import SwiftUI
import Charts

struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @ObservedObject private var purchaseManager = StoreKitPurchaseManager.shared
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.sectionSpacing) {
                    if viewModel.completedWorkoutCount == 0 {
                        EmptyStateCard(
                            icon: "chart.bar.xaxis",
                            title: "No Stats Yet",
                            message: "Complete your first workout and your volume trends, muscle balance, and personal records will show up here."
                        )
                    } else {
                        summaryTiles

                        // One upgrade pitch per state: locked users get the
                        // analytics-specific card below instead of stacking
                        // two upsell cards on the same screen.
                        if purchaseManager.isUnlocked {
                            premiumPreviewCard
                        }

                        heatmapSection
                        advancedAnalyticsContent
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 24)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Stats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.completedWorkoutCount > 0 {
                        exportToolbarItem
                    }
                }
            }
            .onAppear {
                viewModel.refresh()
            }
            .task {
                await purchaseManager.start()
            }
        }
    }

    // MARK: - Export

    @ViewBuilder
    private var exportToolbarItem: some View {
        if purchaseManager.isUnlocked {
            exportButton
        } else {
            NavigationLink {
                UpgradeView()
            } label: {
                Image(systemName: "crown.fill")
            }
        }
    }

    @ViewBuilder
    private var exportButton: some View {
        if let exportURL {
            ShareLink(item: exportURL) {
                Image(systemName: "square.and.arrow.up")
            }
        } else {
            Button {
                exportURL = WorkoutCSVExporter.exportFile(for: viewModel.allCompletedWorkouts)
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }

    // MARK: - Summary

    private var summaryTiles: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatTile(
                    title: "Workouts",
                    value: "\(viewModel.completedWorkoutCount)",
                    icon: "checkmark.seal.fill"
                )
                StatTile(
                    title: "Day Streak",
                    value: "\(viewModel.workoutStreak)",
                    icon: "flame.fill",
                    tint: Theme.amber
                )
            }

            HStack(spacing: 12) {
                StatTile(
                    title: "Total Volume",
                    value: viewModel.formattedVolume(viewModel.totalVolume),
                    icon: "scalemass.fill",
                    tint: Theme.info
                )
                StatTile(
                    title: "Avg Duration",
                    value: viewModel.averageDuration > 0 ? viewModel.formattedDuration(viewModel.averageDuration) : "—",
                    icon: "clock.fill",
                    tint: Theme.success
                )
            }
        }
    }

    private var premiumPreviewCard: some View {
        NavigationLink {
            UpgradeView()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PillTag(text: MonetizationPlan.proTier.name, tint: Theme.amber, icon: "crown.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text("Upgrade when you're ready to go beyond basic tracking.")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(MonetizationPlan.upgradeCTA)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(MonetizationPlan.launchOfferTitle) • \(purchaseManager.displayPrice)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)

                if purchaseManager.isUnlocked {
                    Text("RPT Pro is unlocked on this device.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.success)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .rptCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Advanced Analytics Gate

    @ViewBuilder
    private var advancedAnalyticsContent: some View {
        if purchaseManager.isUnlocked {
            volumeSection

            if !viewModel.muscleGroupShares.isEmpty {
                muscleSection
            }

            if !viewModel.personalRecords.isEmpty {
                recordsSection
            }
        } else {
            advancedAnalyticsLockedCard
        }
    }

    private var advancedAnalyticsLockedCard: some View {
        NavigationLink {
            UpgradeView()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PillTag(text: "Advanced Analytics", tint: Theme.amber, icon: "chart.line.uptrend.xyaxis")
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.amber)
                }

                Text("Unlock deeper training trends")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Weekly volume charts, muscle-balance breakdowns, and personal-record leaderboards are part of RPT Pro.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Unlock RPT Pro for \(purchaseManager.displayPrice)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .rptCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Consistency")

            TrainingHeatmapView(dailyIntensity: viewModel.dailyVolume)
                .rptCard()
        }
    }

    // MARK: - Weekly Volume

    private var volumeSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Weekly Volume")

            VStack(alignment: .leading, spacing: 8) {
                Chart(viewModel.weeklyVolume) { point in
                    BarMark(
                        x: .value("Week", point.weekStart, unit: .weekOfYear),
                        y: .value("Volume", point.volume)
                    )
                    .foregroundStyle(Theme.brandGradient)
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 180)

                Text("Completed working-set volume per week, last 12 weeks.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .rptCard()
        }
    }

    // MARK: - Muscle Balance

    private var muscleSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Muscle Balance")

            VStack(spacing: 10) {
                let maxSets = max(viewModel.muscleGroupShares.first?.workingSets ?? 1, 1)

                ForEach(viewModel.muscleGroupShares.prefix(8)) { share in
                    HStack(spacing: 10) {
                        Text(share.muscleGroup.displayName)
                            .font(.caption.weight(.medium))
                            .frame(width: 86, alignment: .leading)
                            .lineLimit(1)

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.06))

                                Capsule()
                                    .fill(Theme.brandGradient)
                                    .frame(width: max(6, proxy.size.width * CGFloat(share.workingSets) / CGFloat(maxSets)))
                            }
                        }
                        .frame(height: 10)

                        Text("\(share.workingSets)")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .trailing)
                    }
                }

                Text("Working sets per primary muscle group, last 4 weeks.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .rptCard()
        }
    }

    // MARK: - Personal Records

    private var recordsSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Personal Records")

            VStack(spacing: 0) {
                ForEach(Array(viewModel.personalRecords.prefix(6).enumerated()), id: \.element.id) { index, record in
                    HStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .font(.subheadline)
                            .foregroundStyle(index == 0 ? Theme.amber : Color.secondary.opacity(0.5))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.exerciseName)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)

                            Text("\(record.weight) lb × \(record.reps) • \(record.date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(OneRepMax.formatted(record.estimatedOneRepMax))
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                            Text("e1RM")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 10)

                    if index < min(viewModel.personalRecords.count, 6) - 1 {
                        Divider()
                    }
                }
            }
            .rptCard()
        }
    }
}
