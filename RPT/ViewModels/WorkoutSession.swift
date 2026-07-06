//
//  WorkoutSession.swift
//  RPT
//
//  App-wide coordinator for the single in-progress workout. Owns which
//  draft is active, whether the workout screen is presented, and the
//  save/discard handoff when a new workout replaces a live one.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
final class WorkoutSession: ObservableObject {
    static let shared = WorkoutSession()

    @Published var activeWorkout: Workout?
    @Published var isPresentingWorkout = false

    private let workoutManager: WorkoutManager
    private let stateManager: WorkoutStateManager

    init(workoutManager: WorkoutManager? = nil, stateManager: WorkoutStateManager? = nil) {
        self.workoutManager = workoutManager ?? WorkoutManager.shared
        self.stateManager = stateManager ?? WorkoutStateManager.shared
    }

    /// The current draft, but only when it is genuinely resumable.
    var resumableWorkout: Workout? {
        guard let workout = activeWorkout, stateManager.shouldResume(workout) else {
            return nil
        }
        return workout
    }

    /// Re-attaches the most recent resumable draft (e.g. after app launch).
    func restoreResumableWorkout() {
        if let workout = activeWorkout {
            if stateManager.shouldResume(workout) {
                return
            }

            isPresentingWorkout = false
            activeWorkout = nil
        }

        activeWorkout = stateManager.firstResumableWorkout(in: workoutManager.getIncompleteWorkouts())
    }

    /// Starts (and presents) a workout.
    func start(_ workout: Workout) {
        stateManager.clearDiscardedState()
        activeWorkout = workout
        isPresentingWorkout = true
    }

    /// Creates and starts an empty workout. Returns false if persistence failed.
    @discardableResult
    func startEmptyWorkout(named name: String = "Workout") -> Bool {
        guard let workout = workoutManager.createWorkoutSafely(name: name) else {
            return false
        }

        start(workout)
        return true
    }

    /// Re-opens the current resumable draft.
    func openCurrent() {
        guard resumableWorkout != nil else { return }
        isPresentingWorkout = true
    }

    /// Presenting the workout cover in the same transaction that swaps the
    /// root view (onboarding → tab shell) can silently no-op in SwiftUI.
    /// Call this when the tab shell first appears: it re-arms the pending
    /// presentation one runloop tick later. A no-op in every other case,
    /// since `isPresentingWorkout` is only true here during that handoff.
    func rearmPresentationAfterRootSwap() {
        guard isPresentingWorkout, resumableWorkout != nil else { return }

        isPresentingWorkout = false
        Task { @MainActor in
            self.isPresentingWorkout = true
        }
    }

    /// Hides the workout screen but keeps the draft resumable.
    func dismissKeepingDraft() {
        isPresentingWorkout = false
    }

    /// Clears session state after a workout was completed or discarded
    /// inside the workout screen.
    func finishSession() {
        activeWorkout = nil
        isPresentingWorkout = false
    }

    /// Saves the current draft for later. Returns false on persistence failure.
    @discardableResult
    func saveCurrentForLater() -> Bool {
        guard let workout = resumableWorkout else { return true }

        guard workoutManager.saveWorkoutSafely(workout) else {
            return false
        }

        stateManager.markWorkoutAsSaved(workout.id)
        isPresentingWorkout = false
        return true
    }

    /// Deletes the current draft. Returns false on persistence failure.
    @discardableResult
    func discardCurrent() -> Bool {
        guard let workout = resumableWorkout else { return true }

        guard workoutManager.deleteWorkoutSafely(workout) else {
            return false
        }

        stateManager.markWorkoutAsDiscarded(workout.id)
        activeWorkout = nil
        isPresentingWorkout = false
        return true
    }
}
