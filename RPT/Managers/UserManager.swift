//
//  UserManager.swift
//  RPT
//
//  Created by Michael Moore on 4/28/25.
//

import SwiftUI
import SwiftData

@MainActor
class UserManager {
    private let modelContext: ModelContext
    static let shared = UserManager()
    
    private init() {
        let dataManager = DataManager.shared
        self.modelContext = dataManager.getModelContext()
        createDefaultUserIfNeeded()
    }
    
    // Create a default user if none exists
    private func createDefaultUserIfNeeded() {
        var descriptor = FetchDescriptor<User>()
        descriptor.fetchLimit = 1
        
        if let count = try? modelContext.fetchCount(descriptor), count > 0 {
            return // User already exists
        }
        
        // Create default user
        let defaultUser = User(
            username: "User",
            email: "user@example.com"
        )
        
        modelContext.insert(defaultUser)
        try? modelContext.save()
    }
    
    // Get the current user (for now, just the first one)
    func getCurrentUser() -> User? {
        var descriptor = FetchDescriptor<User>()
        descriptor.fetchLimit = 1
        
        return try? modelContext.fetch(descriptor).first
    }
    
    // Update user profile information
    func updateUserProfile(username: String? = nil, email: String? = nil,
                          height: Double? = nil, weight: Double? = nil,
                          birthdate: Date? = nil, profileImageName: String? = nil) {
        guard let user = getCurrentUser() else { return }
        
        if let username = username {
            user.username = username
        }
        
        if let email = email {
            user.email = email
        }
        
        if let height = height {
            user.height = height
        }
        
        if let weight = weight {
            user.weight = weight
        }
        
        if let birthdate = birthdate {
            user.birthdate = birthdate
        }
        
        if let profileImageName = profileImageName {
            user.profileImageName = profileImageName
        }
        
        try? modelContext.save()
    }
    
    // Process a completed workout
    func processCompletedWorkout(_ workout: Workout) {
        guard let user = getCurrentUser() else { return }
        
        // Associate workout with user
        workout.user = user
        user.workouts.append(workout)
        
        // Update user stats
        user.updateStats(with: workout)
        
        try? modelContext.save()
    }
    
    // Get user statistics
    func getUserStats() -> (totalWorkouts: Int, totalVolume: Double, workoutStreak: Int) {
        guard let user = getCurrentUser() else { return (0, 0.0, 0) }
        
        return (user.totalWorkouts, user.totalVolume, user.workoutStreak)
    }
    
    // Get personal bests for display
    func getPersonalBests() -> [(exercise: String, weight: Int)] {
        guard let user = getCurrentUser() else { return [] }
        
        return user.personalBests.map { (exercise: $0.key, weight: $0.value) }
            .sorted { $0.weight > $1.weight }
    }
}
