//
//  StatsView.swift
//  RPT
//
//  Training analytics, one story per card: lifetime summary, consistency
//  heatmap with an insight sentence, weekly volume trend, muscle balance,
//  and recent e1RM personal records.
//

import SwiftUI
import Charts

struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @ObservedObject private var purchaseManager = StoreKitPurchaseManager.shared
    @AppStorage("selectedRootTab") private var selectedRootTabRawValue = RootTab.home.rawValue
    @State private var exportURL: URL?

    /// Weeks covered by the consistency heatmap and its insight sentence.
    private let heatmapWeekCount = 16

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.sectionSpacing) {
                    pageHeader

                    if viewModel.completedWorkoutCount == 0 {
                        EmptyStateCard(
                            icon: "chart.bar.xaxis",
                            title: "No Stats Yet",
                            message: "Complete your first workout and your volume trends, muscle balance, and personal records will show up here.",
                            actionTitle: "Go Train"
                        ) {
                            selectedRootTabRawValue = RootTab.home.rawValue
                        }
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
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                viewModel.refresh()
            }
            .onDisappear {
                // Drop any generated CSV so the next visit exports fresh data
                // instead of re-sharing a stale file.
                exportURL = nil
            }
            .task {
                await purchaseManager.start()
            }
        }
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        HStack {
            Text("Stats")
                .font(Theme.titleFont(size: 26))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            if viewModel.completedWorkoutCount > 0 {
                exportHeaderItem
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Export

    @ViewBuilder
    private var exportHeaderItem: some View {
        if purchaseManager.isUnlocked {
            exportButton
        } else {
            NavigationLink {
                UpgradeView()
            } label: {
                headerButtonLabel("Export CSV", icon: "crown.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Export CSV, requires RPT Pro")
        }
    }

    @ViewBuilder
    private var exportButton: some View {
        if let exportURL {
            ShareLink(item: exportURL) {
                headerButtonLabel("Share CSV", icon: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share exported training history")
        } else {
            Button {
                exportURL = WorkoutCSVExporter.exportFile(for: viewModel.allCompletedWorkouts)
            } label: {
                headerButtonLabel("Export CSV")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Export training history as CSV")
        }
    }

    private func headerButtonLabel(_ title: String, icon: String? = nil) -> some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(Theme.primary)
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .background(
            Theme.cardBackground,
            in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    // MARK: - Summary

    private var summaryTiles: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 14) {
            GridRow {
                summaryCell(
                    value: "\(viewModel.completedWorkoutCount)",
                    caption: "Workouts"
                )
                summaryCell(
                    value: viewModel.formattedVolume(viewModel.totalVolume),
                    caption: "Lifetime volume"
                )
            }
            GridRow {
                summaryCell(
                    value: streakValue,
                    caption: "Current streak",
                    valueColor: Theme.dropOne
                )
                summaryCell(
                    value: viewModel.averageDuration > 0 ? viewModel.formattedDuration(viewModel.averageDuration) : "—",
                    caption: "Avg duration"
                )
            }
        }
        .rptCard()
    }

    private var streakValue: String {
        viewModel.workoutStreak == 1 ? "1 day" : "\(viewModel.workoutStreak) days"
    }

    private func summaryCell(value: String, caption: String, valueColor: Color = Theme.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.titleFont(size: 22))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
                        .foregroundStyle(Theme.textTertiary)
                }

                Text("Upgrade when you're ready to go beyond basic tracking.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text(MonetizationPlan.upgradeCTA)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)

                Text("\(MonetizationPlan.launchOfferTitle) • \(purchaseManager.displayPrice)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.primary)

                if purchaseManager.isUnlocked {
                    Text("RPT Pro is unlocked on this device.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.done)
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

            if !viewModel.personalRecords.isEmpty {
                recordsSection
            }

            if !viewModel.muscleGroupShares.isEmpty {
                muscleSection
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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text("Weekly volume charts, muscle-balance breakdowns, and personal-record leaderboards are part of RPT Pro.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)

                Text("Unlock RPT Pro for \(purchaseManager.displayPrice)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .rptCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Consistency")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                Text("\(heatmapWeekCount) weeks")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }

            TrainingHeatmapView(dailyIntensity: viewModel.dailyVolume, weekCount: heatmapWeekCount)

            if let insight = consistencyInsight {
                (Text("You train most on ")
                    + Text(insight.dayNames).fontWeight(.semibold).foregroundStyle(Theme.textPrimary)
                    + Text(" — \(insight.sessionsPerWeek) training days per week on average."))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .rptCard()
    }

    private struct ConsistencyInsight {
        let dayNames: String
        let sessionsPerWeek: String
    }

    /// Top training weekday(s) and average sessions per week over the same
    /// window the heatmap shows; nil while there is too little data to say.
    private var consistencyInsight: ConsistencyInsight? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let windowStart = TrainingHeatmapView.windowStart(weekCount: heatmapWeekCount, calendar: calendar)

        let activeDays = viewModel.dailyVolume
            .filter { $0.value > 0 && $0.key >= windowStart && $0.key <= today }
            .map(\.key)

        guard activeDays.count >= 4 else { return nil }

        var countsByWeekday: [Int: Int] = [:]
        for day in activeDays {
            countsByWeekday[calendar.component(.weekday, from: day), default: 0] += 1
        }

        guard let topCount = countsByWeekday.values.max(), topCount >= 2 else { return nil }

        let symbols = calendar.shortWeekdaySymbols
        let dayNames = countsByWeekday
            .filter { $0.value == topCount }
            .keys
            .sorted()
            .prefix(3)
            .compactMap { symbols.indices.contains($0 - 1) ? symbols[$0 - 1] : nil }
            .joined(separator: " / ")

        guard !dayNames.isEmpty else { return nil }

        let elapsedDays = (calendar.dateComponents([.day], from: windowStart, to: today).day ?? 0) + 1
        let weeks = max(1, Double(elapsedDays) / 7)
        let rate = Double(activeDays.count) / weeks

        return ConsistencyInsight(
            dayNames: dayNames,
            sessionsPerWeek: String(format: "%.1f", rate)
        )
    }

    // MARK: - Weekly Volume

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Weekly volume")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if let trend = volumeTrendText {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(trend)
                            .font(.system(size: 12, weight: .semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Theme.done)
                    .accessibilityElement(children: .combine)
                }
            }

            let maxVolume = viewModel.weeklyVolume.map(\.volume).max() ?? 0

            Chart(viewModel.weeklyVolume) { point in
                BarMark(
                    x: .value("Week", point.weekStart, unit: .weekOfYear),
                    y: .value("Volume", point.volume)
                )
                .foregroundStyle(barColor(for: point))
                .cornerRadius(4)
                .annotation(position: .top, spacing: 4) {
                    if point.id == viewModel.weeklyVolume.last?.id, point.volume > 0 {
                        Text(compactVolume(point.volume))
                            .font(.system(size: 10.5, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.primary)
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...max(maxVolume * 1.18, 1))
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(height: 140)
            .accessibilityLabel("Completed working-set volume per week, last 12 weeks")
        }
        .rptCard()
    }

    /// Current week is highlighted in the action blue, the four weeks
    /// before it in the mid tone, everything older in the dim tone.
    private func barColor(for point: WeeklyVolumePoint) -> Color {
        let points = viewModel.weeklyVolume
        guard let index = points.firstIndex(where: { $0.id == point.id }) else {
            return Theme.chartBarDim
        }

        if index == points.count - 1 { return Theme.primary }
        if index >= points.count - 5 { return Theme.chartBarMid }
        return Theme.chartBarDim
    }

    /// Short numeric form for the in-chart annotation ("27.4k").
    private func compactVolume(_ volume: Double) -> String {
        let safe = volume.isFinite ? max(0, volume) : 0
        if safe >= 1_000_000 {
            return String(format: "%.1fM", safe / 1_000_000)
        }
        if safe >= 1_000 {
            return String(format: "%.1fk", safe / 1_000)
        }
        return "\(Int(safe))"
    }

    /// Percent change of the last four weeks of volume against the four
    /// weeks before them; nil when there is no prior volume or no gain.
    private var volumeTrendText: String? {
        let points = viewModel.weeklyVolume
        guard points.count >= 8 else { return nil }

        let recent = points.suffix(4).reduce(0) { $0 + $1.volume }
        let prior = points.dropLast(4).suffix(4).reduce(0) { $0 + $1.volume }
        guard prior > 0, recent > prior else { return nil }

        let percent = Int(((recent - prior) / prior * 100).rounded())
        guard percent >= 1 else { return nil }

        return "+\(percent)% this month"
    }

    // MARK: - Muscle Balance

    private var muscleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Muscle balance")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            let maxSets = max(viewModel.muscleGroupShares.first?.workingSets ?? 1, 1)

            ForEach(viewModel.muscleGroupShares.prefix(8)) { share in
                HStack(spacing: 10) {
                    Text(share.muscleGroup.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 86, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.surfaceMuted)

                            Capsule()
                                .fill(Theme.primary)
                                .frame(width: max(6, proxy.size.width * CGFloat(share.workingSets) / CGFloat(maxSets)))
                        }
                    }
                    .frame(height: 8)

                    Text("\(share.workingSets)")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 30, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }

            Text("Working sets per primary muscle group, last 4 weeks.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
        .rptCard()
    }

    // MARK: - Personal Records

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            let records = recentRecords
            let deltas = recordDeltas(for: records)

            Text("Recent PRs")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.bottom, 6)

            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                if index > 0 {
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(height: 1)
                }

                recordRow(record, delta: deltas[record.exerciseName])
            }
        }
        .rptCard()
    }

    /// Most recent PRs first — the card celebrates fresh progress.
    private var recentRecords: [PersonalRecordEntry] {
        viewModel.personalRecords
            .sorted { $0.date > $1.date }
            .prefix(6)
            .map { $0 }
    }

    /// e1RM gain over each exercise's best set logged before the PR
    /// workout; exercises with no earlier history carry no delta.
    private func recordDeltas(for records: [PersonalRecordEntry]) -> [String: Int] {
        guard !records.isEmpty else { return [:] }

        let prDates = Dictionary(uniqueKeysWithValues: records.map { ($0.exerciseName, $0.date) })
        var previousBest: [String: Double] = [:]

        for workout in viewModel.allCompletedWorkouts {
            for set in workout.sets where set.isCompletedWorkingSet && set.weight > 0 {
                guard let name = set.exercise?.displayName,
                      let prDate = prDates[name],
                      workout.date < prDate else { continue }

                let estimate = OneRepMax.estimate(weight: set.weight, reps: set.reps)
                if estimate > 0 {
                    previousBest[name] = max(previousBest[name] ?? 0, estimate)
                }
            }
        }

        var deltas: [String: Int] = [:]
        for record in records {
            guard let previous = previousBest[record.exerciseName] else { continue }

            let gain = Int((record.estimatedOneRepMax - previous).rounded())
            if gain > 0 {
                deltas[record.exerciseName] = gain
            }
        }
        return deltas
    }

    private func recordRow(_ record: PersonalRecordEntry, delta: Int?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "star.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.dropOne)
                .frame(width: 28, height: 28)
                .background(
                    Theme.orangeTint,
                    in: RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("\(record.exerciseName) · e1RM \(OneRepMax.formatted(record.estimatedOneRepMax))")
                    .font(.system(size: 13.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("\(record.weight) × \(record.reps) · \(record.date.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.system(size: 11.5))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 8)

            if let delta {
                Text("+\(delta) lb")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.done)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}
