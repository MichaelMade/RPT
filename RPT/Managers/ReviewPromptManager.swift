//
//  ReviewPromptManager.swift
//  RPT
//
//  Apple-compliant StoreKit review prompt gating. Shows the system review
//  sheet after ≥3 completed workouts, at most once per app version, with
//  a 90-day belt-and-suspenders cooldown.
//

import Foundation
import StoreKit
import SwiftUI

@MainActor
enum ReviewPromptManager {

    private static let completedWorkoutCountKey = "reviewPrompt.completedWorkoutCount"
    private static let lastPromptedVersionKey = "reviewPrompt.lastPromptedVersion"
    private static let lastPromptedDateKey = "reviewPrompt.lastPromptedDate"
    private static let snoozedUntilDateKey = "reviewPrompt.snoozedUntilDate"

    static let minimumCompletedWorkouts = 3
    static let cooldownDays = 90
    static let snoozeDays = 30

    /// In-memory latch that prevents more than one soft-ask alert per
    /// eligibility window. Multiple tab views (HomeView, StatsView) react
    /// to the same `isPresentingWorkout` change; the first to call
    /// `claimSoftAsk()` wins and the others get `false`.
    private static var softAskClaimed = false

    // MARK: - Workout Counting

    static var completedWorkoutCount: Int {
        get { UserDefaults.standard.integer(forKey: completedWorkoutCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: completedWorkoutCountKey) }
    }

    static func recordCompletedWorkout() {
        completedWorkoutCount += 1
    }

    // MARK: - Eligibility

    static func isEligibleForPrompt() -> Bool {
        guard completedWorkoutCount >= minimumCompletedWorkouts else {
            return false
        }

        guard !hasPromptedThisVersion() else {
            return false
        }

        guard !isWithinCooldown() else {
            return false
        }

        guard !isSnoozed() else {
            return false
        }

        return true
    }

    // MARK: - Soft-Ask Latch

    /// Atomically checks eligibility and claims the right to present the
    /// soft-ask alert. Returns `true` exactly once per eligibility window;
    /// all concurrent callers after the first get `false`.
    static func claimSoftAsk() -> Bool {
        guard !softAskClaimed else { return false }
        guard isEligibleForPrompt() else { return false }
        softAskClaimed = true
        return true
    }

    /// Resets the in-memory latch. Called when the prompt is actioned
    /// (either "Rate RPT" or "Not now") so a future eligibility window
    /// can fire again, and also useful in tests.
    static func resetSoftAskLatch() {
        softAskClaimed = false
    }

    // MARK: - Prompt

    static func requestReviewIfEligible() {
        guard isEligibleForPrompt() else { return }

        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else {
            return
        }

        markPrompted()
        SKStoreReviewController.requestReview(in: scene)
    }

    static func snooze() {
        let snoozedUntil = Calendar.current.date(
            byAdding: .day, value: snoozeDays, to: Date()
        ) ?? Date()
        UserDefaults.standard.set(snoozedUntil, forKey: snoozedUntilDateKey)
    }

    // MARK: - Write-Review Deep Link

    static let writeReviewURL = URL(
        string: "https://apps.apple.com/app/id6745407020?action=write-review"
    )!

    // MARK: - Internal State

    private static func hasPromptedThisVersion() -> Bool {
        let currentVersion = appVersion
        let lastVersion = UserDefaults.standard.string(forKey: lastPromptedVersionKey)
        return lastVersion == currentVersion
    }

    private static func isWithinCooldown() -> Bool {
        guard let lastDate = UserDefaults.standard.object(forKey: lastPromptedDateKey) as? Date else {
            return false
        }

        let daysSince = Calendar.current.dateComponents(
            [.day], from: lastDate, to: Date()
        ).day ?? Int.max

        return daysSince < cooldownDays
    }

    private static func isSnoozed() -> Bool {
        guard let snoozedUntil = UserDefaults.standard.object(forKey: snoozedUntilDateKey) as? Date else {
            return false
        }

        return Date() < snoozedUntil
    }

    private static func markPrompted() {
        UserDefaults.standard.set(appVersion, forKey: lastPromptedVersionKey)
        UserDefaults.standard.set(Date(), forKey: lastPromptedDateKey)
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }
}
