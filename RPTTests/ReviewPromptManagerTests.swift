import XCTest
@testable import RPT

@MainActor
final class ReviewPromptManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        clearReviewPromptState()
        ReviewPromptManager.resetSoftAskLatch()
    }

    override func tearDown() {
        clearReviewPromptState()
        ReviewPromptManager.resetSoftAskLatch()
        super.tearDown()
    }

    private func clearReviewPromptState() {
        UserDefaults.standard.removeObject(forKey: "reviewPrompt.completedWorkoutCount")
        UserDefaults.standard.removeObject(forKey: "reviewPrompt.lastPromptedVersion")
        UserDefaults.standard.removeObject(forKey: "reviewPrompt.lastPromptedDate")
        UserDefaults.standard.removeObject(forKey: "reviewPrompt.snoozedUntilDate")
    }

    // MARK: - Workout Count Gate

    func testNotEligibleWithZeroWorkouts() {
        XCTAssertEqual(ReviewPromptManager.completedWorkoutCount, 0)
        XCTAssertFalse(ReviewPromptManager.isEligibleForPrompt())
    }

    func testNotEligibleWithFewerThanThreeWorkouts() {
        ReviewPromptManager.completedWorkoutCount = 2
        XCTAssertFalse(ReviewPromptManager.isEligibleForPrompt())
    }

    func testEligibleAtExactlyThreeWorkouts() {
        ReviewPromptManager.completedWorkoutCount = 3
        XCTAssertTrue(ReviewPromptManager.isEligibleForPrompt())
    }

    func testEligibleAboveThreeWorkouts() {
        ReviewPromptManager.completedWorkoutCount = 10
        XCTAssertTrue(ReviewPromptManager.isEligibleForPrompt())
    }

    // MARK: - Per-Version Gate

    func testNotEligibleAfterPromptedThisVersion() {
        ReviewPromptManager.completedWorkoutCount = 5

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        UserDefaults.standard.set(currentVersion, forKey: "reviewPrompt.lastPromptedVersion")
        UserDefaults.standard.set(Date(), forKey: "reviewPrompt.lastPromptedDate")

        XCTAssertFalse(ReviewPromptManager.isEligibleForPrompt())
    }

    func testEligibleAfterVersionChange() {
        ReviewPromptManager.completedWorkoutCount = 5

        UserDefaults.standard.set("0.0.1-old", forKey: "reviewPrompt.lastPromptedVersion")
        UserDefaults.standard.set(
            Calendar.current.date(byAdding: .day, value: -91, to: Date())!,
            forKey: "reviewPrompt.lastPromptedDate"
        )

        XCTAssertTrue(ReviewPromptManager.isEligibleForPrompt())
    }

    // MARK: - Cooldown Gate

    func testNotEligibleWithinCooldownPeriod() {
        ReviewPromptManager.completedWorkoutCount = 5

        UserDefaults.standard.set("0.0.1-old", forKey: "reviewPrompt.lastPromptedVersion")
        UserDefaults.standard.set(
            Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
            forKey: "reviewPrompt.lastPromptedDate"
        )

        XCTAssertFalse(ReviewPromptManager.isEligibleForPrompt())
    }

    // MARK: - Snooze Gate

    func testNotEligibleWhileSnoozed() {
        ReviewPromptManager.completedWorkoutCount = 5
        ReviewPromptManager.snooze()

        XCTAssertFalse(ReviewPromptManager.isEligibleForPrompt())
    }

    func testEligibleAfterSnoozeExpires() {
        ReviewPromptManager.completedWorkoutCount = 5

        let expired = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        UserDefaults.standard.set(expired, forKey: "reviewPrompt.snoozedUntilDate")

        XCTAssertTrue(ReviewPromptManager.isEligibleForPrompt())
    }

    // MARK: - Workout Counter

    func testRecordCompletedWorkoutIncrements() {
        XCTAssertEqual(ReviewPromptManager.completedWorkoutCount, 0)
        ReviewPromptManager.recordCompletedWorkout()
        XCTAssertEqual(ReviewPromptManager.completedWorkoutCount, 1)
        ReviewPromptManager.recordCompletedWorkout()
        XCTAssertEqual(ReviewPromptManager.completedWorkoutCount, 2)
    }

    // MARK: - Constants

    func testMinimumWorkoutThreshold() {
        XCTAssertEqual(ReviewPromptManager.minimumCompletedWorkouts, 3)
    }

    func testCooldownDays() {
        XCTAssertEqual(ReviewPromptManager.cooldownDays, 90)
    }

    func testSnoozeDays() {
        XCTAssertEqual(ReviewPromptManager.snoozeDays, 30)
    }

    func testWriteReviewURL() {
        XCTAssertEqual(
            ReviewPromptManager.writeReviewURL.absoluteString,
            "https://apps.apple.com/app/id6745407020?action=write-review"
        )
    }

    // MARK: - Soft-Ask Latch (No Double-Prompt)

    func testClaimSoftAsk_returnsTrueOnceWhenEligible() {
        ReviewPromptManager.completedWorkoutCount = 5

        XCTAssertTrue(ReviewPromptManager.claimSoftAsk(),
                       "First caller should claim the soft-ask")
        XCTAssertFalse(ReviewPromptManager.claimSoftAsk(),
                        "Second caller in the same window must be blocked")
    }

    func testClaimSoftAsk_returnsFalseWhenNotEligible() {
        ReviewPromptManager.completedWorkoutCount = 0
        XCTAssertFalse(ReviewPromptManager.claimSoftAsk(),
                        "Should not claim when eligibility requirements are not met")
    }

    func testClaimSoftAsk_resetsAfterLatchReset() {
        ReviewPromptManager.completedWorkoutCount = 5

        XCTAssertTrue(ReviewPromptManager.claimSoftAsk())
        ReviewPromptManager.resetSoftAskLatch()
        XCTAssertTrue(ReviewPromptManager.claimSoftAsk(),
                       "After latch reset a new eligibility window should allow another claim")
    }

    func testClaimSoftAsk_blocksSecondViewEvenWhenBothEligible() {
        ReviewPromptManager.completedWorkoutCount = 10

        let homeViewClaimed = ReviewPromptManager.claimSoftAsk()
        let statsViewClaimed = ReviewPromptManager.claimSoftAsk()

        XCTAssertTrue(homeViewClaimed, "First view should win the soft-ask")
        XCTAssertFalse(statsViewClaimed,
                        "TabView sibling must not double-prompt in the same eligibility window")
    }
}
