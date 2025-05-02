import Foundation
import SwiftUI
import Combine
import SwiftData

class WorkoutStateManager: ObservableObject {
    static let shared = WorkoutStateManager()
    
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
    
    // Clear all discard state
    func clearDiscardedState() {
        workoutWasDiscarded = false
        lastDiscardedWorkoutId = nil
        discardTimestamp = nil
        
        // Clear from UserDefaults
        UserDefaults.standard.removeObject(forKey: "workout_discarded_id")
        UserDefaults.standard.removeObject(forKey: "workout_discarded_flag")
        UserDefaults.standard.removeObject(forKey: "workout_discarded_time")
    }
    
    // Mark a workout as explicitly saved (not discarded)
    func markWorkoutAsSaved(_ workoutId: Any? = nil) {
        // Ensure we're not in discarded state
        clearDiscardedState()
    }
    
    private func saveStateToDefaults() {
        UserDefaults.standard.set(lastDiscardedWorkoutId, forKey: "workout_discarded_id")
        UserDefaults.standard.set(workoutWasDiscarded, forKey: "workout_discarded_flag")
        UserDefaults.standard.set(discardTimestamp, forKey: "workout_discarded_time")
    }
    
    private func loadStateFromDefaults() {
        lastDiscardedWorkoutId = UserDefaults.standard.string(forKey: "workout_discarded_id")
        workoutWasDiscarded = UserDefaults.standard.bool(forKey: "workout_discarded_flag")
        discardTimestamp = UserDefaults.standard.object(forKey: "workout_discarded_time") as? Date
        
        hasLoadedFromDefaults = true
    }
}
