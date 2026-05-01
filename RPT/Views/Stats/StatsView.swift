//
//  StatsView.swift
//  RPT
//

import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headlineCards
                    thisWeekSnapshot

                    if viewModel.totalWorkouts == 0 {
                        emptyStateCard
                    } else {
                        weeklyVolumeChart

                        muscleGroupDistribution

                        personalRecords
                    }
                }
                .padding()
            }
            .navigationTitle("Stats")
            .onAppear { viewModel.reload() }
        }
    }

    // MARK: - Headline cards

    private var headlineCards: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            StatTile(
                icon: "flame.fill",
                title: "Streak",
                value: "\(viewModel.currentStreak)",
                subtitle: viewModel.currentStreak == 1 ? "day" : "days",
                tint: .orange
            )
            StatTile(
                icon: "figure.strengthtraining.traditional",
                title: "Workouts",
                value: "\(viewModel.totalWorkouts)",
                subtitle: "total",
                tint: .blue
            )
            StatTile(
                icon: "scalemass",
                title: viewModel.lifetimeWorkMetricTitle,
                value: viewModel.lifetimeWorkMetricValue,
                subtitle: viewModel.lifetimeWorkMetricSubtitle,
                tint: .purple
            )
            StatTile(
                icon: "calendar",
                title: "Active Weeks",
                value: "\(viewModel.weeksActive)",
                subtitle: "weeks",
                tint: .green
            )
        }
    }

    // MARK: - This week snapshot

    private var thisWeekSnapshot: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("This Week")
                    .font(.headline)

                Spacer()

                Text(thisWeekSummaryMessage(totalWorkouts: viewModel.totalWorkouts, weeklyWorkoutCount: viewModel.weeklyWorkoutCount))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                StatTile(
                    icon: "calendar.badge.clock",
                    title: "Workouts",
                    value: "\(viewModel.weeklyWorkoutCount)",
                    subtitle: "last 7 days",
                    tint: .blue
                )
                StatTile(
                    icon: "scalemass",
                    title: viewModel.weeklyWorkMetricTitle,
                    value: viewModel.weeklyWorkMetricValue,
                    subtitle: viewModel.weeklyWorkMetricSubtitle,
                    tint: .purple
                )
                StatTile(
                    icon: "clock",
                    title: "Avg Time",
                    value: thisWeekAverageDurationValue(
                        weeklyWorkoutCount: viewModel.weeklyWorkoutCount,
                        hasAverageDuration: viewModel.hasWeeklyAverageDuration,
                        formattedDuration: viewModel.weeklyAverageDuration
                    ),
                    subtitle: "per workout",
                    tint: .green
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Empty state

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundColor(.blue)

                Text("No workout stats yet")
                    .font(.headline)
            }

            Text("Complete your first workout to unlock weekly volume, muscle group focus, and personal records here.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Label("Start a workout from Home or use Templates to begin faster.", systemImage: "arrow.right.circle")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Weekly volume chart

    @ViewBuilder
    private var weeklyVolumeChart: some View {
        if !viewModel.weeklyVolume.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Weekly Volume")
                    .font(.headline)
                Text("Last 12 weeks")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Chart(viewModel.weeklyVolume) { point in
                    BarMark(
                        x: .value("Week", point.weekStart, unit: .weekOfYear),
                        y: .value("Volume", point.volume)
                    )
                    .foregroundStyle(Color.blue.gradient)
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 180)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        } else if viewModel.totalWorkouts > 0 {
            SectionPlaceholderCard(
                title: "Weekly Volume",
                systemImage: "chart.bar.xaxis",
                message: weeklyVolumeEmptyStateMessage(totalWorkouts: viewModel.totalWorkouts)
            )
        }
    }

    // MARK: - Muscle group distribution

    @ViewBuilder
    private var muscleGroupDistribution: some View {
        if !viewModel.muscleGroupShare.isEmpty {
            let totalSets = viewModel.muscleGroupShare.reduce(0) { $0 + $1.setCount }
            VStack(alignment: .leading, spacing: 10) {
                Text("Muscle Group Focus")
                    .font(.headline)
                Text("Working sets over the last 4 weeks")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Chart(viewModel.muscleGroupShare) { share in
                    SectorMark(
                        angle: .value("Sets", share.setCount),
                        innerRadius: .ratio(0.55),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Group", share.group.displayName))
                    .cornerRadius(3)
                }
                .frame(height: 220)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.muscleGroupShare.prefix(6)) { share in
                        HStack {
                            Text(share.group.displayName)
                                .font(.caption)
                            Spacer()
                            Text("\(share.setCount) sets")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                            Text(formattedSetSharePercentage(setCount: share.setCount, totalSets: totalSets))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        } else if viewModel.totalWorkouts > 0 {
            SectionPlaceholderCard(
                title: "Muscle Group Focus",
                systemImage: "figure.strengthtraining.traditional",
                message: muscleGroupEmptyStateMessage(totalWorkouts: viewModel.totalWorkouts)
            )
        }
    }

    // MARK: - Personal records

    @ViewBuilder
    private var personalRecords: some View {
        if !viewModel.recentPRs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Recent Personal Records")
                    .font(.headline)

                ForEach(viewModel.recentPRs) { pr in
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                        VStack(alignment: .leading) {
                            Text(pr.exerciseName)
                                .font(.subheadline)
                            Text(personalRecordDateText(for: pr.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(pr.formattedWeightReps)
                            .font(.headline.monospacedDigit())
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        } else if viewModel.totalWorkouts > 0 {
            SectionPlaceholderCard(
                title: "Recent Personal Records",
                systemImage: "trophy",
                message: personalRecordsEmptyStateMessage(totalWorkouts: viewModel.totalWorkouts)
            )
        }
    }

    // MARK: - Helpers

    func thisWeekSummaryMessage(totalWorkouts: Int, weeklyWorkoutCount: Int) -> String {
        let safeWeeklyCount = max(0, weeklyWorkoutCount)

        guard safeWeeklyCount > 0 else {
            return totalWorkouts > 0
                ? "No completed workouts in the last 7 days"
                : "Finish a workout to start this week’s trend"
        }

        return safeWeeklyCount == 1
            ? "1 workout in the last 7 days"
            : "\(safeWeeklyCount) workouts in the last 7 days"
    }

    func thisWeekAverageDurationValue(weeklyWorkoutCount: Int, hasAverageDuration: Bool, formattedDuration: String) -> String {
        guard max(0, weeklyWorkoutCount) > 0, hasAverageDuration else {
            return "—"
        }

        return formattedDuration
    }

    func weeklyVolumeEmptyStateMessage(totalWorkouts: Int) -> String {
        guard totalWorkouts > 0 else {
            return "Complete a workout to start building your weekly training chart."
        }

        return "No completed workouts landed in the last 12 weeks, so there’s no recent volume to chart yet."
    }

    func muscleGroupEmptyStateMessage(totalWorkouts: Int) -> String {
        guard totalWorkouts > 0 else {
            return "Complete a workout to see where your working sets are landing."
        }

        return "Log completed working sets in the last 4 weeks to see which muscle groups are getting the most attention."
    }

    func personalRecordsEmptyStateMessage(totalWorkouts: Int) -> String {
        guard totalWorkouts > 0 else {
            return "Complete a workout to start capturing personal records."
        }

        return "Finish a few completed working sets and your strongest recent performances will show up here."
    }

    func personalRecordDateText(
        for date: Date,
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        WorkoutRow.relativeDateText(
            for: date,
            now: now,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )
    }

    func formattedTotal(_ volume: Double) -> String {
        let safeVolume = volume.isFinite ? max(0, volume) : 0
        let truncatedVolume = floor(safeVolume * 10) / 10

        if truncatedVolume >= 1_000_000 {
            let millions = truncatedVolume / 1_000_000
            let truncatedMillions = floor(millions * 10) / 10
            let isWhole = truncatedMillions.truncatingRemainder(dividingBy: 1) == 0
            return isWhole
                ? "\(Int(truncatedMillions))M lb"
                : String(format: "%.1fM lb", truncatedMillions)
        }

        if truncatedVolume >= 1000 {
            let thousands = truncatedVolume / 1000
            let truncatedThousands = floor(thousands * 10) / 10
            let isWhole = truncatedThousands.truncatingRemainder(dividingBy: 1) == 0
            return isWhole
                ? "\(Int(truncatedThousands))k lb"
                : String(format: "%.1fk lb", truncatedThousands)
        }

        return "\(Int(floor(truncatedVolume))) lb"
    }

    func formattedSetSharePercentage(setCount: Int, totalSets: Int) -> String {
        let safeTotalSets = max(0, totalSets)

        guard safeTotalSets > 0 else {
            return "(0%)"
        }

        let safeSetCount = min(max(0, setCount), safeTotalSets)
        let ratio = Double(safeSetCount) / Double(safeTotalSets)
        let rawPercentage = ratio.isFinite ? ratio * 100 : 0
        let safePercentage = min(100, max(0, Int(rawPercentage)))

        return "(\(safePercentage)%)"
    }
}

private struct SectionPlaceholderCard: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

private struct StatTile: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(tint)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title.monospacedDigit())
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    StatsView()
        .modelContainer(for: [Exercise.self, Workout.self, ExerciseSet.self, UserSettings.self, User.self])
}
