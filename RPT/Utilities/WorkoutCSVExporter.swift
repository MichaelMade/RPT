//
//  WorkoutCSVExporter.swift
//  RPT
//
//  Plain-text CSV export of training history so data is never locked
//  inside the app.
//

import Foundation

enum WorkoutCSVExporter {
    static let header = header(for: .pounds)

    /// Column names carry the unit, so a spreadsheet never has to guess.
    static func header(for unit: WeightUnit) -> String {
        "date,workout,exercise,set_type,weight_\(unit.short),reps,rpe,volume_\(unit.short)"
    }

    /// Builds a CSV string of all logged sets in completed workouts,
    /// newest workout first, sets in logged order.
    ///
    /// Dates are the lifter's own calendar days (`timeZone`, the device's
    /// zone by default) so the export agrees with History and Stats. A UTC
    /// date would file an evening session under the following day.
    ///
    /// Loads are exported in `unit`, the unit the lifter trains in. A set
    /// logged in that unit is written exactly as it was entered.
    static func csv(for workouts: [Workout], timeZone: TimeZone = .current, unit: WeightUnit = .current) -> String {
        var lines: [String] = [header(for: unit)]

        let dateFormatter = dayFormatter(timeZone: timeZone)

        let completed = workouts
            .filter(\.isCompleted)
            .sorted { $0.date > $1.date }

        for workout in completed {
            let dateField = dateFormatter.string(from: workout.date)
            let workoutField = escape(WorkoutNameFormatter.displayName(for: workout))

            for set in workout.setsInLoggedOrder where set.isCompletedLoggedSet {
                guard let exercise = set.exercise else { continue }

                let setType = set.isWarmup ? "warmup" : "working"
                let rpeField = set.displayRPE.map(String.init) ?? ""
                // Volume is the written load times reps, so each row adds
                // up for anyone checking it by hand.
                let weightField = set.writtenLoad(in: unit)
                let writtenLoad = Double(weightField) ?? 0
                let volumeField = set.isWarmup ? "0" : unit.exactString(for: writtenLoad * Double(set.reps))

                lines.append(
                    [
                        dateField,
                        workoutField,
                        escape(exercise.displayName),
                        setType,
                        weightField,
                        String(set.reps),
                        rpeField,
                        volumeField
                    ].joined(separator: ",")
                )
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Writes the CSV to a temporary file suitable for the share sheet.
    static func exportFile(for workouts: [Workout]) -> URL? {
        let content = csv(for: workouts)
        let filename = "RPT-History-\(dayFormatter(timeZone: .current).string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    /// `yyyy-MM-dd` in a fixed Gregorian/POSIX format, so the output does not
    /// change with the device's region, calendar, or numbering system.
    static func dayFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    /// Escapes a CSV field per RFC 4180.
    static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") else {
            return field
        }

        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
