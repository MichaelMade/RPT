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

                    weeklyVolumeChart

                    muscleGroupDistribution

                    personalRecords
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
                title: "Volume",
                value: formattedTotal(viewModel.totalVolume),
                subtitle: "lifted",
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
                            Text("(\(Int(Double(share.setCount) / Double(totalSets) * 100))%)")
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
                            Text(pr.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(pr.weight) lb × \(pr.reps)")
                            .font(.headline.monospacedDigit())
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Helpers

    private func formattedTotal(_ volume: Double) -> String {
        if volume >= 1000 {
            let k = volume / 1000
            let whole = k.truncatingRemainder(dividingBy: 1) == 0
            return whole ? "\(Int(k))k lb" : String(format: "%.1fk lb", k)
        }
        return "\(Int(volume)) lb"
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
