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

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    // MARK: - Derived data

    private var sets: [ExerciseSet] {
        let interval = DateInterval(start: timeRange.startDate(), end: Date())
        return DataManager.shared.fetchExerciseSetsSafely(for: exercise, timeFrame: interval)
            .filter { !$0.isWarmup }
    }

    private var dataPoints: [Point] {
        let grouped = Dictionary(grouping: sets) { Calendar.current.startOfDay(for: $0.completedAt) }
        return grouped.map { (day, daySets) -> Point in
            switch metric {
            case .topSet:
                let top = daySets.map { $0.weight }.max() ?? 0
                return Point(date: day, value: Double(top))
            case .volume:
                let vol = daySets.reduce(0.0) { $0 + Double($1.weight) * Double($1.reps) }
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
                    ForEach(Metric.allCases) { m in
                        Text(m.rawValue).tag(m)
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
    }

    @ViewBuilder
    private var chartView: some View {
        Chart(dataPoints) { point in
            if metric == .volume {
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value(metric.rawValue, point.value)
                )
                .foregroundStyle(exercise.category.style.color)
            } else {
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(metric.rawValue, point.value)
                )
                .foregroundStyle(exercise.category.style.color)
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value(metric.rawValue, point.value)
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
        let unit = metric == .volume ? " lb" : " lb"
        let isWhole = value.truncatingRemainder(dividingBy: 1) == 0
        if metric == .volume && abs(value) >= 1000 {
            let k = value / 1000
            return String(format: "%.1fk%@", k, unit)
        }
        return isWhole ? "\(Int(value))\(unit)" : String(format: "%.1f%@", value, unit)
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
