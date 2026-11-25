//
//  UITestSupport.swift
//  RPT
//
//  Launch arguments the UI tests use to put the app in a known state.
//  Debug builds for the simulator only: none of this exists in a release
//  build, or in any build that runs on a phone, so it can never reach a
//  lifter's own settings.
//

#if DEBUG && targetEnvironment(simulator)
import Foundation
import SwiftData

enum UITestSupport {
    /// Launches with a finished workout logged as bare pound numbers, the
    /// way every set was stored before RPT had a weight unit, and with the
    /// unit back on pounds. The store lives only for that launch, so the
    /// workout never reaches another test or the simulator's stored
    /// workouts. The unit choice does persist in the simulator's defaults,
    /// as it would from the picker: `resetUnitChoices` starts each run
    /// from pounds, and the test ends on pounds.
    static let poundHistoryArgument = "--uiTestPoundHistory"

    static var wantsPoundHistory: Bool {
        ProcessInfo.processInfo.arguments.contains(poundHistoryArgument)
    }

    /// Puts the unit and the relabel question back to how a lifter who has
    /// never opened the unit picker has them. Runs before any view reads
    /// them.
    static func resetUnitChoices(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: WeightUnit.defaultsKey)
        defaults.removeObject(forKey: KilogramRelabelPolicy.promptAnsweredDefaultsKey)
        defaults.removeObject(forKey: KilogramRelabelPolicy.revisionDefaultsKey)
    }

    /// One finished bench workout from an hour ago: 100 x 5 and 90 x 5,
    /// 950 in total. Read as pounds that is 431 kg; relabeled it is 950 kg.
    @MainActor
    static func seedPoundHistory(using dataManager: DataManaging) {
        let context = dataManager.getModelContext()
        let benchName = "Barbell Bench Press"

        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let bench: Exercise
        if let existing = exercises.first(where: { $0.name == benchName }) {
            bench = existing
        } else {
            bench = Exercise(name: benchName, category: .compound, primaryMuscleGroups: [.chest])
            context.insert(bench)
        }

        let startedAt = Date().addingTimeInterval(-3_600)
        let workout = Workout(date: startedAt, name: "Bench Day", duration: 1_800, isCompleted: true)
        context.insert(workout)

        let loads: [(weight: Int, reps: Int)] = [(100, 5), (90, 5)]
        for (index, load) in loads.enumerated() {
            let set = workout.addSet(exercise: bench, weight: load.weight, reps: load.reps)
            set.completedAt = startedAt.addingTimeInterval(TimeInterval(index + 1) * 180)
        }

        try? dataManager.saveChanges()
    }
}
#endif
