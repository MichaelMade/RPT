import XCTest
@testable import RPT

@MainActor
final class WorkoutStateManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        WorkoutStateManager.shared.clearDiscardedState()
    }

    override func tearDown() {
        WorkoutStateManager.shared.clearDiscardedState()
        super.tearDown()
    }

    func testMarkWorkoutAsSaved_clearsDiscardFlagAndTimestamp() {
        let manager = WorkoutStateManager.shared

        manager.markWorkoutAsDiscarded("draft-workout")
        XCTAssertTrue(manager.wasAnyWorkoutDiscarded(), "Sanity check: discard flag should be set before saving")
        XCTAssertNotNil(manager.discardTimestamp, "Sanity check: discard timestamp should be recorded before saving")

        manager.markWorkoutAsSaved("draft-workout")

        XCTAssertFalse(manager.wasAnyWorkoutDiscarded(), "Saving a workout for later should clear discard state")
        XCTAssertNil(manager.discardTimestamp, "Saving a workout for later should clear discard timestamp")
        XCTAssertNil(manager.lastDiscardedWorkoutId, "Saving a workout for later should clear the remembered discarded workout id")
    }

    func testFirstResumableWorkout_skipsDiscardedNewestDraftAndReturnsNextEligible() {
        let manager = WorkoutStateManager.shared
        let discardTime = Date()
        let discardedNewestDraft = Workout(date: discardTime.addingTimeInterval(-60), name: "Discarded Draft", isCompleted: false)
        let newerEligibleDraft = Workout(date: discardTime.addingTimeInterval(60), name: "Eligible Draft", isCompleted: false)

        manager.markWorkoutAsDiscarded(discardedNewestDraft.id)
        manager.discardTimestamp = discardTime

        let resumable = manager.firstResumableWorkout(in: [discardedNewestDraft, newerEligibleDraft])

        XCTAssertTrue(resumable === newerEligibleDraft, "Resume selection should skip the discarded draft and keep scanning for a valid one")
    }

    func testShouldResume_keepsOlderSavedDraftAfterAnotherWorkoutIsDiscarded() {
        let manager = WorkoutStateManager.shared
        let savedDraft = Workout(date: Date().addingTimeInterval(-60 * 60), name: "Saved For Later", isCompleted: false)
        let discardedDraft = Workout(date: Date(), name: "Started By Mistake", isCompleted: false)

        manager.markWorkoutAsDiscarded(discardedDraft.id)

        XCTAssertFalse(manager.shouldResume(discardedDraft), "The workout that was discarded must not come back")
        XCTAssertTrue(
            manager.shouldResume(savedDraft),
            "A draft saved before the discard holds logged sets and must stay reachable"
        )
        XCTAssertTrue(manager.firstResumableWorkout(in: [discardedDraft, savedDraft]) === savedDraft)
    }

    func testShouldResume_failsOpenWhenTheDiscardedIdentityIsNotInMemory() {
        let manager = WorkoutStateManager.shared
        let savedDraft = Workout(date: Date().addingTimeInterval(-60 * 60), name: "Saved For Later", isCompleted: false)

        // After a relaunch only the persisted flag and text id survive. The
        // discarded workout was deleted before it was marked, so every
        // draft still in the store is a different workout.
        manager.markWorkoutAsDiscarded("identifier-from-a-previous-launch")

        XCTAssertTrue(manager.wasAnyWorkoutDiscarded())
        XCTAssertTrue(manager.shouldResume(savedDraft))
    }

    func testShouldResume_rejectsCompletedWorkouts() {
        let manager = WorkoutStateManager.shared
        let completedWorkout = Workout(date: Date(), name: "Completed", isCompleted: true)

        XCTAssertFalse(manager.shouldResume(completedWorkout), "Completed workouts should never be treated as resumable drafts")
    }

    func testResolvedResumableWorkout_prefersCurrentBindingWhenEligible() {
        let manager = WorkoutStateManager.shared
        let currentBinding = Workout(date: Date(), name: "Current Draft", isCompleted: false)
        let fallbackWorkout = Workout(date: Date().addingTimeInterval(60), name: "Fallback Draft", isCompleted: false)

        let resolved = manager.resolvedResumableWorkout(
            currentBinding: currentBinding,
            fallbackWorkouts: [fallbackWorkout]
        )

        XCTAssertTrue(resolved === currentBinding, "Current in-memory draft should win when it is still resumable")
    }

    func testResolvedResumableWorkout_fallsBackToPersistedEligibleDraft() {
        let manager = WorkoutStateManager.shared
        let completedBinding = Workout(date: Date(), name: "Completed Binding", isCompleted: true)
        let persistedDraft = Workout(date: Date().addingTimeInterval(60), name: "Persisted Draft", isCompleted: false)

        let resolved = manager.resolvedResumableWorkout(
            currentBinding: completedBinding,
            fallbackWorkouts: [persistedDraft]
        )

        XCTAssertTrue(resolved === persistedDraft, "Persisted incomplete drafts should still be protected when the current binding is missing or no longer resumable")
    }
}
