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
}
