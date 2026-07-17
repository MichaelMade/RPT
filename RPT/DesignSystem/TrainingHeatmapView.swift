//
//  TrainingHeatmapView.swift
//  RPT
//
//  GitHub-style training consistency heatmap. Each column is a week,
//  each cell a day, colored on the Theme.heatRamp blue ramp by that
//  day's completed training volume.
//

import SwiftUI

struct TrainingHeatmapView: View {
    /// Volume (or any intensity metric) keyed by start-of-day date.
    let dailyIntensity: [Date: Double]
    var weekCount: Int = 16

    private let calendar = Calendar.current
    private let cellSize: CGFloat = 13
    private let cellSpacing: CGFloat = 3

    /// Start-of-day of the first day (week start) of the oldest week in a
    /// `weekCount`-week window ending today. Exposed so hosts can compute
    /// insights over exactly the window the grid shows.
    static func windowStart(weekCount: Int, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysIntoWeek = (weekday - calendar.firstWeekday + 7) % 7
        let currentWeekStart = calendar.date(byAdding: .day, value: -daysIntoWeek, to: today) ?? today
        return calendar.date(byAdding: .day, value: -7 * (weekCount - 1), to: currentWeekStart) ?? currentWeekStart
    }

    private var maxIntensity: Double {
        max(dailyIntensity.values.max() ?? 0, 1)
    }

    /// Start-of-day for the first day (weekStart) of the oldest week shown.
    private var gridStartDay: Date {
        Self.windowStart(weekCount: weekCount, calendar: calendar)
    }

    /// Days inside the visible grid window that have logged training.
    private var activeDayCount: Int {
        let today = calendar.startOfDay(for: Date())
        return dailyIntensity.filter { day, intensity in
            intensity > 0 && day >= gridStartDay && day <= today
        }.count
    }

    var body: some View {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Training consistency: \(activeDayCount) training \(activeDayCount == 1 ? "day" : "days") in the last \(weekCount) weeks")
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

    /// Buckets a 0...1 intensity onto Theme.heatRamp; zero maps to the
    /// muted empty tile at the bottom of the ramp.
    private func color(forNormalized value: Double) -> Color {
        let ramp = Theme.heatRamp
        guard value > 0 else { return ramp[0] }

        let steps = ramp.count - 1
        let bucket = min(steps, max(1, Int((value * Double(steps)).rounded(.up))))
        return ramp[bucket]
    }
}
