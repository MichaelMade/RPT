//
//  ExerciseProgressView.swift
//  RPT
//

import SwiftUI
import SwiftData
import Charts

struct ExerciseProgressView: View {
    let exercise: Exercise

    @State private var timeRange: TimeRange = .threeMonths
    @State private var metric: Metric = .topSet

    enum TimeRange: String, CaseIterable, Identifiable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"
        case all = "All"

        var id: String { rawValue }

        func startDate(from now: Date = Date()) -> Date {
            let cal = Calendar.current
            switch self {
            case .oneMonth:     return cal.date(byAdding: .month, value: -1, to: now) ?? .distantPast
            case .threeMonths:  return cal.date(byAdding: .month, value: -3, to: now) ?? .distantPast
            case .sixMonths:    return cal.date(byAdding: .month, value: -6, to: now) ?? .distantPast
            case .oneYear:      return cal.date(byAdding: .year,  value: -1, to: now) ?? .distantPast
            case .all:          return .distantPast
            }
        }
    }

    enum Metric: String, CaseIterable, Identifiable {
        case topSet = "Top Weight"
        case volume = "Volume"
        case estimatedOneRM = "Est. 1RM"

        var id: String { rawValue }
    }

    static func availableMetrics(for exerciseCategory: ExerciseCategory) -> [Metric] {
        switch exerciseCategory {
        case .bodyweight:
            return [.topSet, .volume]
        default:
            return Metric.allCases
        }
    }

    static func metricDisplayName(for metric: Metric, exerciseCategory: ExerciseCategory) -> String {
        switch (metric, exerciseCategory) {
        case (.topSet, .bodyweight):
            return "Top Reps"
        case (.volume, .bodyweight):
            return "Total Reps"
        default:
            return metric.rawValue
        }
    }

    static func topSetMetricValue(from sets: [ExerciseSet], exerciseCategory: ExerciseCategory) -> Double {
        switch exerciseCategory {
        case .bodyweight:
            return Double(sets.map(\.reps).max() ?? 0)
        default:
            return Double(sets.map(\.weight).max() ?? 0)
        }
    }

    static func volumeMetricValue(from sets: [ExerciseSet], exerciseCategory: ExerciseCategory) -> Double {
        switch exerciseCategory {
        case .bodyweight:
            return Double(sets.reduce(0) { $0 + $1.reps })
        default:
            return sets.reduce(0.0) { $0 + Double($1.weight) * Double($1.reps) }
        }
    }

    static func formatMetricValue(_ value: Double, metric: Metric, exerciseCategory: ExerciseCategory) -> String {
        if exerciseCategory == .bodyweight, metric == .topSet || metric == .volume {
            let roundedReps = Int(value.rounded())
            return "\(roundedReps) \(roundedReps == 1 ? \"rep\" : \"reps\")"
        }

        let isWhole = value.truncatingRemainder(dividingBy: 1) == 0
        if metric == .volume && abs(value) >= 1000 {
            let k = value / 1000
            return String(format: "%.1fk lb", k)
        }
        return isWhole ? "\(Int(value)) lb" : String(format: "%.1f lb", value)
    }

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    // MARK: - Derived data

    private var sets: [ExerciseSet] {
        let interval = DateInterval(start: timeRange.startDate(), end: Date())
        return DataManager.shared.fetchExerciseSetsSafely(for: exercise, timeFrame: interval)
            .filter { $0.isCompletedWorkingSet }
    }

    private var dataPoints: [Point] {
        let grouped = Dictionary(grouping: sets) { Calendar.current.startOfDay(for: $0.completedAt) }
        return grouped.map { (day, daySets) -> Point in
            switch metric {
            case .topSet:
                let top = Self.topSetMetricValue(from: daySets, exerciseCategory: exercise.category)
                return Point(date: day, value: top)
            case .volume:
                let vol = Self.volumeMetricValue(from: daySets, exerciseCategory: exercise.category)
                return Point(date: day, value: vol)
            case .estimatedOneRM:
                // Brzycki formula, capped at 10 reps for accuracy
                let values = daySets.map { set -> Double in
                    let reps = min(max(1, set.reps), 10)
                    return Double(set.weight) * (36.0 / (37.0 - Double(reps)))
                }
                return Point(date: day, value: values.max() ?? 0)
            }
        }
        .sorted { $0.date < $1.date }
    }

    private var summary: (current: Double, best: Double, delta: Double)? {
        guard let first = dataPoints.first, let last = dataPoints.last else { return nil }
        let best = dataPoints.map(\.value).max() ?? last.value
        return (current: last.value, best: best, delta: last.value - first.value)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Metric", selection: $metric) {
                    ForEach(Self.availableMetrics(for: exercise.category)) { m in
                        Text(Self.metricDisplayName(for: m, exerciseCategory: exercise.category)).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                if dataPoints.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.downtrend.xyaxis")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("No data in this range")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    chartView
                    summaryCards
                }
            }
            .padding()
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !Self.availableMetrics(for: exercise.category).contains(metric) {
                metric = .topSet
            }
        }
    }

    @ViewBuilder
    private var chartView: some View {
        Chart(dataPoints) { point in
            if metric == .volume {
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value(Self.metricDisplayName(for: metric, exerciseCategory: exercise.category), point.value)
                )
                .foregroundStyle(exercise.category.style.color)
            } else {
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(Self.metricDisplayName(for: metric, exerciseCategory: exercise.category), point.value)
                )
                .foregroundStyle(exercise.category.style.color)
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value(Self.metricDisplayName(for: metric, exerciseCategory: exercise.category), point.value)
                )
                .foregroundStyle(exercise.category.style.color)
                .symbolSize(40)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 240)
    }

    @ViewBuilder
    private var summaryCards: some View {
        if let summary {
            HStack(spacing: 12) {
                statCard(title: "Current", value: formatValue(summary.current))
                statCard(title: "Best", value: formatValue(summary.best))
                statCard(
                    title: "Change",
                    value: (summary.delta >= 0 ? "+" : "") + formatValue(summary.delta),
                    tint: summary.delta >= 0 ? .green : .red
                )
            }
        }
    }

    private func statCard(title: String, value: String, tint: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundColor(tint ?? .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }

    private func formatValue(_ value: Double) -> String {
        Self.formatMetricValue(value, metric: metric, exerciseCategory: exercise.category)
    }
}

#Preview {
    let exercise = Exercise(
        name: "Bench Press",
        category: .compound,
        primaryMuscleGroups: [.chest]
    )
    return NavigationStack {
        ExerciseProgressView(exercise: exercise)
    }
}
