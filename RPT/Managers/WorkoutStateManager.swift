import Foundation
import SwiftUI
import Combine
import SwiftData

@MainActor
class WorkoutStateManager: ObservableObject {
    static let shared = WorkoutStateManager()

    private enum Keys {
        static let discardedId = "workout_discarded_id"
        static let discardedFlag = "workout_discarded_flag"
        static let discardedTime = "workout_discarded_time"
    }

    @Published var lastDiscardedWorkoutId: String? = nil
    @Published var workoutWasDiscarded = false

    // Store when the workout was discarded
    var discardTimestamp: Date? = nil

    // Keep track of whether we've loaded from UserDefaults
    private var hasLoadedFromDefaults = false

    private init() {
        loadStateFromDefaults()
    }
    
    // Mark workout as discarded - accepts any ID type or nothing at all
    func markWorkoutAsDiscarded(_ workoutId: Any? = nil) {
        // Even if no ID is provided, mark as discarded
        workoutWasDiscarded = true
        discardTimestamp = Date()
        
        // If an ID is provided, try to convert it to a string
        if let id = workoutId {
            var idString: String? = nil
            
            if let persistentId = id as? PersistentIdentifier {
                // Use string interpolation instead of accessing description
                idString = "\(persistentId)"
            } else if let uuid = id as? UUID {
                idString = uuid.uuidString
            } else if let stringId = id as? String {
                idString = stringId
            } else {
                // For any other type, use string interpolation
                idString = "\(id)"
            }
            
            if let idString = idString {
                lastDiscardedWorkoutId = idString
            }
        }
        
        // Save to UserDefaults for persistence
        saveStateToDefaults()
    }
        
    // Check if a specific workout is discarded
    func isWorkoutDiscarded(_ workoutId: Any?) -> Bool {
        // If we haven't loaded from defaults yet, do it now
        if !hasLoadedFromDefaults {
            loadStateFromDefaults()
        }
        
        // For now, we only care that ANY workout was discarded
        return workoutWasDiscarded
    }
    
    // Check if any workout was discarded
    func wasAnyWorkoutDiscarded() -> Bool {
        // If we haven't loaded from defaults yet, do it now
        if !hasLoadedFromDefaults {
            loadStateFromDefaults()
        }
        
        return workoutWasDiscarded
    }

    func shouldResume(_ workout: Workout?) -> Bool {
        guard let workout else {
            return false
        }

        guard !workout.isCompleted else {
            return false
        }

        let wasAnyWorkoutDiscarded = wasAnyWorkoutDiscarded()

        guard wasAnyWorkoutDiscarded else {
            return true
        }

        guard let discardTimestamp else {
            // Fail open for legacy/corrupted discard state.
            return true
        }

        return workout.date >= discardTimestamp
    }

    func firstResumableWorkout(in workouts: [Workout]) -> Workout? {
        workouts.first(where: shouldResume)
    }
    
    // Clear all discard state
    func clearDiscardedState() {
        workoutWasDiscarded = false
        lastDiscardedWorkoutId = nil
        discardTimestamp = nil

        UserDefaults.standard.removeObject(forKey: Keys.discardedId)
        UserDefaults.standard.removeObject(forKey: Keys.discardedFlag)
        UserDefaults.standard.removeObject(forKey: Keys.discardedTime)
    }

    // Mark a workout as explicitly saved (not discarded)
    func markWorkoutAsSaved(_ workoutId: Any? = nil) {
        clearDiscardedState()
    }

    private func saveStateToDefaults() {
        UserDefaults.standard.set(lastDiscardedWorkoutId, forKey: Keys.discardedId)
        UserDefaults.standard.set(workoutWasDiscarded, forKey: Keys.discardedFlag)
        UserDefaults.standard.set(discardTimestamp, forKey: Keys.discardedTime)
    }

    private func loadStateFromDefaults() {
        lastDiscardedWorkoutId = UserDefaults.standard.string(forKey: Keys.discardedId)
        workoutWasDiscarded = UserDefaults.standard.bool(forKey: Keys.discardedFlag)
        discardTimestamp = UserDefaults.standard.object(forKey: Keys.discardedTime) as? Date

        hasLoadedFromDefaults = true
    }
}
