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
            return Double(sets.map { max(0, $0.reps) }.max() ?? 0)
        default:
            return Double(sets.map { max(0, $0.weight) }.max() ?? 0)
        }
    }

    static func volumeMetricValue(from sets: [ExerciseSet], exerciseCategory: ExerciseCategory) -> Double {
        switch exerciseCategory {
        case .bodyweight:
            return Double(sets.reduce(0) { $0 + max(0, $1.reps) })
        default:
            return sets.reduce(0.0) { partialResult, set in
                let safeWeight = max(0, set.weight)
                let safeReps = max(0, set.reps)
                return partialResult + Double(safeWeight) * Double(safeReps)
            }
        }
    }

    static func formatMetricValue(_ value: Double, metric: Metric, exerciseCategory: ExerciseCategory) -> String {
        let safeValue: Double
        if value.isFinite {
            safeValue = max(0, value)
        } else {
            safeValue = 0
        }

        if exerciseCategory == .bodyweight, metric == .topSet || metric == .volume {
            let truncatedReps = Int(safeValue.rounded(.towardZero))
            return "\(truncatedReps) \(truncatedReps == 1 ? \"rep\" : \"reps\")"
        }

        if metric == .volume {
            let magnitude = abs(safeValue)

            if magnitude >= 1_000_000 {
                let signedMillions = safeValue / 1_000_000
                let truncatedMillions = truncatedTowardZero(signedMillions, decimals: 1)
                let isWholeMillion = truncatedMillions.truncatingRemainder(dividingBy: 1) == 0
                return isWholeMillion
                    ? "\(Int(truncatedMillions))M lb"
                    : String(format: "%.1fM lb", truncatedMillions)
            }

            if magnitude >= 1000 {
                let signedThousands = safeValue / 1000
                let truncatedThousands = truncatedTowardZero(signedThousands, decimals: 1)
                let isWholeThousand = truncatedThousands.truncatingRemainder(dividingBy: 1) == 0
                return isWholeThousand
                    ? "\(Int(truncatedThousands))k lb"
                    : String(format: "%.1fk lb", truncatedThousands)
            }

            let truncatedVolume = truncatedTowardZero(safeValue, decimals: 1)
            let isWholeVolume = truncatedVolume.truncatingRemainder(dividingBy: 1) == 0
            return isWholeVolume
                ? "\(Int(truncatedVolume)) lb"
                : String(format: "%.1f lb", truncatedVolume)
        }

        let isWhole = safeValue.truncatingRemainder(dividingBy: 1) == 0
        return isWhole ? "\(Int(safeValue)) lb" : String(format: "%.1f lb", safeValue)
    }

    private static func truncatedTowardZero(_ input: Double, decimals: Int) -> Double {
        let factor = pow(10.0, Double(decimals))
        let scaled = input * factor
        let truncated = input >= 0 ? floor(scaled) : ceil(scaled)
        return truncated / factor
    }

    private static func displaysAsZeroDeltaMagnitude(_ value: Double, metric: Metric, exerciseCategory: ExerciseCategory) -> Bool {
        let safeMagnitude = value.isFinite ? abs(value) : 0

        if exerciseCategory == .bodyweight, metric == .topSet || metric == .volume {
            return Int(safeMagnitude.rounded(.towardZero)) == 0
        }

        if metric == .volume {
            if safeMagnitude >= 1_000_000 {
                return truncatedTowardZero(safeMagnitude / 1_000_000, decimals: 1) == 0
            }

            if safeMagnitude >= 1000 {
                return truncatedTowardZero(safeMagnitude / 1000, decimals: 1) == 0
            }

            return truncatedTowardZero(safeMagnitude, decimals: 1) == 0
        }

        return ((safeMagnitude * 10).rounded() / 10) == 0
    }

    enum DeltaTrend: Equatable {
        case positive
        case neutral
        case negative
    }

    static func deltaTrend(for value: Double) -> DeltaTrend {
        guard value.isFinite else {
            return .neutral
        }

        if value > 0 {
            return .positive
        }

        if value < 0 {
            return .negative
        }

        return .neutral
    }

    static func formatMetricDeltaValue(_ value: Double, metric: Metric, exerciseCategory: ExerciseCategory) -> String {
        guard value.isFinite else {
            return formatMetricValue(0, metric: metric, exerciseCategory: exerciseCategory)
        }

        if value == 0 || displaysAsZeroDeltaMagnitude(value, metric: metric, exerciseCategory: exerciseCategory) {
            return formatMetricValue(0, metric: metric, exerciseCategory: exerciseCategory)
        }

        let signPrefix = value > 0 ? "+" : "-"
        let magnitudeText = formatMetricValue(abs(value), metric: metric, exerciseCategory: exerciseCategory)
        return "\(signPrefix)\(magnitudeText)"
    }

    static func deltaTrend(for value: Double, metric: Metric, exerciseCategory: ExerciseCategory) -> DeltaTrend {
        guard value.isFinite else {
            return .neutral
        }

        if value == 0 || displaysAsZeroDeltaMagnitude(value, metric: metric, exerciseCategory: exerciseCategory) {
            return .neutral
        }

        return value > 0 ? .positive : .negative
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
                    let safeWeight = max(0, set.weight)
                    let oneRM = Double(safeWeight) * (36.0 / (37.0 - Double(reps)))
                    return oneRM.isFinite ? max(0, oneRM) : 0
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
                    value: Self.formatMetricDeltaValue(summary.delta, metric: metric, exerciseCategory: exercise.category),
                    tint: {
                        switch Self.deltaTrend(for: summary.delta, metric: metric, exerciseCategory: exercise.category) {
                        case .positive:
                            return .green
                        case .neutral:
                            return nil
                        case .negative:
                            return .red
                        }
                    }()
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
