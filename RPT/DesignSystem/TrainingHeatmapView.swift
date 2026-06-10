//
//  TrainingHeatmapView.swift
//  RPT
//
//  GitHub-style training consistency heatmap. Each column is a week,
//  each cell a day, colored by that day's completed training volume.
//

import SwiftUI

struct TrainingHeatmapView: View {
    /// Volume (or any intensity metric) keyed by start-of-day date.
    let dailyIntensity: [Date: Double]
    var weekCount: Int = 16

    private let calendar = Calendar.current
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3

    private var maxIntensity: Double {
        max(dailyIntensity.values.max() ?? 0, 1)
    }

    /// Start-of-day for the first day (weekStart) of the oldest week shown.
    private var gridStartDay: Date {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysIntoWeek = (weekday - calendar.firstWeekday + 7) % 7
        let currentWeekStart = calendar.date(byAdding: .day, value: -daysIntoWeek, to: today) ?? today
        return calendar.date(byAdding: .day, value: -7 * (weekCount - 1), to: currentWeekStart) ?? currentWeekStart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: cellSpacing) {
                    ForEach(0..<weekCount, id: \.self) { weekIndex in
                        VStack(spacing: cellSpacing) {
                            ForEach(0..<7, id: \.self) { dayIndex in
                                cell(weekIndex: weekIndex, dayIndex: dayIndex)
                            }
                        }
                    }
                }
            }
            .defaultScrollAnchor(.trailing)

            HStack(spacing: 4) {
                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color(forNormalized: level))
                        .frame(width: 10, height: 10)
                }
                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func cell(weekIndex: Int, dayIndex: Int) -> some View {
        let day = calendar.date(byAdding: .day, value: weekIndex * 7 + dayIndex, to: gridStartDay)
        let today = calendar.startOfDay(for: Date())

        if let day, day <= today {
            let intensity = dailyIntensity[day] ?? 0
            let normalized = intensity > 0 ? max(0.25, intensity / maxIntensity) : 0

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color(forNormalized: normalized))
                .frame(width: cellSize, height: cellSize)
        } else {
            // Future days in the current week stay invisible to keep the grid aligned.
            Color.clear
                .frame(width: cellSize, height: cellSize)
        }
    }

    private func color(forNormalized value: Double) -> Color {
        guard value > 0 else {
            return Color.primary.opacity(0.07)
        }

        return Theme.accent.opacity(0.25 + 0.75 * min(1, value))
    }
}
