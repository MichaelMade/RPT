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

        XCTAssertTrue(resumable === newerEligibleDraft, "Resume selection should skip drafts older than the discard timestamp and keep scanning for a valid newer draft")
    }

    func testShouldResume_rejectsCompletedWorkouts() {
        let manager = WorkoutStateManager.shared
        let completedWorkout = Workout(date: Date(), name: "Completed", isCompleted: true)

        XCTAssertFalse(manager.shouldResume(completedWorkout), "Completed workouts should never be treated as resumable drafts")
    }
}
