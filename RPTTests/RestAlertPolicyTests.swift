//
//  RestAlertPolicyTests.swift
//  RPTTests
//
//  When a rest-end alert is scheduled, and when the dock offers one.
//

import XCTest
@testable import RPT

final class RestAlertPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    private func leadTime(
        secondsLeft: TimeInterval,
        isEnabled: Bool = true,
        permission: RestAlertPermission = .granted
    ) -> TimeInterval? {
        RestAlertPolicy.leadTime(
            untilRestEndsAt: now.addingTimeInterval(secondsLeft),
            now: now,
            isEnabled: isEnabled,
            permission: permission
        )
    }

    // MARK: - Scheduling

    func testAlertFiresWhenTheRestEnds() {
        XCTAssertEqual(leadTime(secondsLeft: 180), 180)
        XCTAssertEqual(leadTime(secondsLeft: 42.5), 42.5)
    }

    func testNoAlertUnlessTheLifterTurnedItOn() {
        XCTAssertNil(leadTime(secondsLeft: 180, isEnabled: false))
    }

    func testNoAlertUnlessIOSAllowsIt() {
        XCTAssertNil(leadTime(secondsLeft: 180, permission: .notDetermined))
        XCTAssertNil(leadTime(secondsLeft: 180, permission: .denied))
    }

    func testNoAlertForARestThatIsOverOrAboutToBe() {
        XCTAssertNil(leadTime(secondsLeft: 0))
        XCTAssertNil(leadTime(secondsLeft: -30))
        XCTAssertNil(leadTime(secondsLeft: 0.4))
        XCTAssertEqual(leadTime(secondsLeft: RestAlertPolicy.minimumLeadTime), RestAlertPolicy.minimumLeadTime)
    }

    func testNoAlertForACountdownThatWasNeverStarted() {
        XCTAssertNil(
            RestAlertPolicy.leadTime(
                untilRestEndsAt: .distantFuture,
                now: now,
                isEnabled: true,
                permission: .granted
            ),
            "The dock's placeholder deadline must never become a notification"
        )
        XCTAssertNil(leadTime(secondsLeft: RestAlertPolicy.maximumLeadTime + 1))
        XCTAssertNotNil(leadTime(secondsLeft: 300 + 20 * 15), "The longest preset plus many +15s taps is still a rest")
    }

    // MARK: - Dock offer

    func testDockOffersTheAlertWhileIOSHasNotBeenAsked() {
        XCTAssertTrue(
            RestAlertPolicy.offersAlertInDock(isEnabled: false, permission: .notDetermined, offersShown: 0)
        )
        XCTAssertTrue(
            RestAlertPolicy.offersAlertInDock(
                isEnabled: false,
                permission: .notDetermined,
                offersShown: RestAlertPolicy.maxDockOffers - 1
            )
        )
    }

    func testDockStopsOfferingAfterTheLimit() {
        XCTAssertFalse(
            RestAlertPolicy.offersAlertInDock(
                isEnabled: false,
                permission: .notDetermined,
                offersShown: RestAlertPolicy.maxDockOffers
            )
        )
    }

    func testDockDoesNotOfferOnceIOSHasAnAnswer() {
        XCTAssertFalse(RestAlertPolicy.offersAlertInDock(isEnabled: false, permission: .denied, offersShown: 0))
        XCTAssertFalse(RestAlertPolicy.offersAlertInDock(isEnabled: false, permission: .granted, offersShown: 0))
    }

    func testDockDoesNotOfferWhatIsAlreadyOn() {
        XCTAssertFalse(RestAlertPolicy.offersAlertInDock(isEnabled: true, permission: .notDetermined, offersShown: 0))
        XCTAssertFalse(RestAlertPolicy.offersAlertInDock(isEnabled: true, permission: .granted, offersShown: 0))
    }

    // MARK: - Copy

    func testNotificationCopyNamesNoWorkoutData() {
        XCTAssertEqual(RestAlertPolicy.notificationTitle, "Rest complete")
        XCTAssertEqual(RestAlertPolicy.notificationBody, "Time for your next set.")
    }
}
