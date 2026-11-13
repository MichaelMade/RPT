//
//  RestAlertManagerTests.swift
//  RPTTests
//
//  The rest-end alert against a fake notification centre: permission,
//  scheduling, and cleanup, without touching the system or the app's
//  defaults.
//

import XCTest
@testable import RPT

@MainActor
final class RestAlertManagerTests: XCTestCase {
    @MainActor
    private final class FakeCenter: RestAlertNotificationCenter {
        struct Scheduled: Equatable {
            let identifier: String
            let title: String
            let body: String
            let interval: TimeInterval
        }

        var permission: RestAlertPermission
        /// What the lifter answers when the system prompt appears.
        var answerToPrompt: RestAlertPermission = .granted

        private(set) var promptCount = 0
        private(set) var scheduled: [Scheduled] = []
        private(set) var cancelled: [String] = []
        /// Every scheduling call in order, to check what is pending at the end.
        private(set) var log: [String] = []

        init(permission: RestAlertPermission) {
            self.permission = permission
        }

        var hasPendingAlert: Bool {
            log.last == "schedule"
        }

        func restAlertPermission() async -> RestAlertPermission {
            permission
        }

        func requestRestAlertPermission() async -> Bool {
            promptCount += 1
            permission = answerToPrompt
            return permission == .granted
        }

        func scheduleRestAlert(identifier: String, title: String, body: String, after interval: TimeInterval) {
            scheduled.append(Scheduled(identifier: identifier, title: title, body: body, interval: interval))
            log.append("schedule")
        }

        func cancelRestAlert(identifier: String) {
            cancelled.append(identifier)
            log.append("cancel")
        }
    }

    private var suiteName = ""
    private var defaults: UserDefaults!
    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    override func setUp() {
        super.setUp()
        suiteName = "rpt.tests.rest-alert.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeManager(_ center: FakeCenter) -> RestAlertManager {
        RestAlertManager(center: center, defaults: defaults)
    }

    /// A manager whose lifter has turned the alert on and iOS allows it.
    private func makeActiveManager(_ center: FakeCenter) async -> RestAlertManager {
        let manager = makeManager(center)
        let result = await manager.enable()
        XCTAssertEqual(result, .enabled)
        return manager
    }

    // MARK: - Opt-in

    func testAlertIsOffUntilTheLifterTurnsItOn() async {
        let center = FakeCenter(permission: .granted)
        let manager = makeManager(center)
        await manager.refreshPermission()

        XCTAssertFalse(manager.isEnabled)
        XCTAssertFalse(manager.isActive)
        XCTAssertFalse(manager.scheduleRestEnd(at: now.addingTimeInterval(180), now: now))
        XCTAssertTrue(center.scheduled.isEmpty, "iOS allowing notifications is not the lifter asking for them")
        XCTAssertEqual(center.promptCount, 0)
    }

    func testTurningItOnAsksIOSOnceAndRemembersTheChoice() async {
        let center = FakeCenter(permission: .notDetermined)
        let manager = makeManager(center)

        let result = await manager.enable()

        XCTAssertEqual(result, .enabled)
        XCTAssertEqual(center.promptCount, 1)
        XCTAssertTrue(manager.isEnabled)
        XCTAssertTrue(manager.isActive)

        let nextLaunch = makeManager(center)
        XCTAssertTrue(nextLaunch.isEnabled, "The choice must survive a relaunch")

        _ = await nextLaunch.enable()
        XCTAssertEqual(center.promptCount, 1, "iOS already has an answer; do not ask again")
    }

    func testTurningItOnStaysOffWhenTheLifterDeclinesThePrompt() async {
        let center = FakeCenter(permission: .notDetermined)
        center.answerToPrompt = .denied
        let manager = makeManager(center)

        let result = await manager.enable()

        XCTAssertEqual(result, .permissionDenied)
        XCTAssertFalse(manager.isEnabled)
        XCTAssertFalse(manager.isActive)
        XCTAssertEqual(manager.permission, .denied)
    }

    func testTurningItOnDoesNotPromptWhenIOSAlreadyRefused() async {
        let center = FakeCenter(permission: .denied)
        let manager = makeManager(center)

        let result = await manager.enable()

        XCTAssertEqual(result, .permissionDenied)
        XCTAssertEqual(center.promptCount, 0, "The system prompt cannot be shown twice; Settings is the only way back")
        XCTAssertFalse(manager.isEnabled)
    }

    func testPermissionRevokedInSettingsStopsAlerts() async {
        let center = FakeCenter(permission: .notDetermined)
        let manager = await makeActiveManager(center)

        center.permission = .denied
        await manager.refreshPermission()

        XCTAssertFalse(manager.isActive)
        XCTAssertFalse(manager.scheduleRestEnd(at: now.addingTimeInterval(180), now: now))
        XCTAssertTrue(center.scheduled.isEmpty)
    }

    func testTurningItOffCancelsAnAlertAlreadyScheduled() async {
        let center = FakeCenter(permission: .notDetermined)
        let manager = await makeActiveManager(center)
        XCTAssertTrue(manager.scheduleRestEnd(at: now.addingTimeInterval(180), now: now))

        manager.disable()

        XCTAssertFalse(manager.isEnabled)
        XCTAssertFalse(center.hasPendingAlert)
        XCTAssertFalse(makeManager(center).isEnabled, "Off must survive a relaunch too")
    }

    // MARK: - Scheduling

    func testLeavingTheAppMidRestSchedulesOneAlertForTheEndOfRest() async {
        let center = FakeCenter(permission: .notDetermined)
        let manager = await makeActiveManager(center)

        XCTAssertTrue(manager.scheduleRestEnd(at: now.addingTimeInterval(137), now: now))

        XCTAssertEqual(
            center.scheduled,
            [
                FakeCenter.Scheduled(
                    identifier: RestAlertPolicy.notificationIdentifier,
                    title: "Rest complete",
                    body: "Time for your next set.",
                    interval: 137
                )
            ]
        )
        XCTAssertTrue(center.hasPendingAlert)
    }

    func testNoAlertForARestThatAlreadyEnded() async {
        let center = FakeCenter(permission: .notDetermined)
        let manager = await makeActiveManager(center)

        XCTAssertFalse(manager.scheduleRestEnd(at: now.addingTimeInterval(-5), now: now))
        XCTAssertFalse(manager.scheduleRestEnd(at: .distantFuture, now: now))

        XCTAssertTrue(center.scheduled.isEmpty)
        XCTAssertFalse(manager.scheduledAlertHasFired(asOf: now.addingTimeInterval(600)))
    }

    func testComingBackBeforeRestEndsTakesTheAlertBack() async {
        let center = FakeCenter(permission: .notDetermined)
        let manager = await makeActiveManager(center)
        XCTAssertTrue(manager.scheduleRestEnd(at: now.addingTimeInterval(180), now: now))

        let returnedAt = now.addingTimeInterval(60)
        XCTAssertFalse(manager.scheduledAlertHasFired(asOf: returnedAt), "Rest is still running; the dock will chime itself")
        manager.cancelRestEnd()

        XCTAssertFalse(center.hasPendingAlert)
        XCTAssertEqual(center.cancelled, [RestAlertPolicy.notificationIdentifier])
        XCTAssertFalse(
            manager.scheduledAlertHasFired(asOf: now.addingTimeInterval(600)),
            "A cancelled alert never fired, so the dock must still chime when rest ends in the foreground"
        )
    }

    func testComingBackAfterTheAlertFiredIsNotAnnouncedTwice() async {
        let center = FakeCenter(permission: .notDetermined)
        let manager = await makeActiveManager(center)
        XCTAssertTrue(manager.scheduleRestEnd(at: now.addingTimeInterval(180), now: now))

        XCTAssertTrue(manager.scheduledAlertHasFired(asOf: now.addingTimeInterval(180)))
        XCTAssertTrue(manager.scheduledAlertHasFired(asOf: now.addingTimeInterval(400)))

        manager.cancelRestEnd()
        XCTAssertEqual(
            center.cancelled,
            [RestAlertPolicy.notificationIdentifier],
            "Returning clears the delivered banner so it does not sit in Notification Center"
        )
    }

    func testLeavingAgainAfterComingBackReschedulesForTheTimeLeft() async {
        let center = FakeCenter(permission: .notDetermined)
        let manager = await makeActiveManager(center)
        let restEnds = now.addingTimeInterval(180)

        XCTAssertTrue(manager.scheduleRestEnd(at: restEnds, now: now))
        manager.cancelRestEnd()
        XCTAssertTrue(manager.scheduleRestEnd(at: restEnds, now: now.addingTimeInterval(100)))

        XCTAssertEqual(center.scheduled.map(\.interval), [180, 80])
        XCTAssertTrue(center.hasPendingAlert)
        XCTAssertFalse(manager.scheduledAlertHasFired(asOf: now.addingTimeInterval(170)))
        XCTAssertTrue(manager.scheduledAlertHasFired(asOf: restEnds))
    }

    func testCancellingWithNothingScheduledStillClearsLeftovers() {
        let center = FakeCenter(permission: .granted)
        let manager = makeManager(center)

        manager.cancelRestEnd()

        XCTAssertEqual(
            center.cancelled,
            [RestAlertPolicy.notificationIdentifier],
            "Launch cleanup relies on this to remove an alert from a previous run"
        )
    }

    // MARK: - Dock offer

    func testDockOfferIsMadeForAFewRestsThenStops() async {
        let center = FakeCenter(permission: .notDetermined)
        let manager = makeManager(center)
        await manager.refreshPermission()

        let offers = (0..<RestAlertPolicy.maxDockOffers + 3).map { _ in manager.claimDockOffer() }

        XCTAssertEqual(offers.filter { $0 }.count, RestAlertPolicy.maxDockOffers)
        XCTAssertEqual(Array(offers.prefix(RestAlertPolicy.maxDockOffers)), Array(repeating: true, count: RestAlertPolicy.maxDockOffers))
        XCTAssertFalse(makeManager(center).claimDockOffer(), "The count must survive a relaunch")
    }

    func testNotNowEndsTheDockOffer() async {
        let center = FakeCenter(permission: .notDetermined)
        let manager = makeManager(center)
        await manager.refreshPermission()
        XCTAssertTrue(manager.claimDockOffer())

        manager.declineDockOffer()

        XCTAssertFalse(manager.claimDockOffer())
        XCTAssertEqual(center.promptCount, 0, "Declining RPT's own question must not burn the one system prompt")
    }

    func testDockOfferIsNotMadeOnceTheAlertIsOnOrIOSHasRefused() async {
        let granted = FakeCenter(permission: .notDetermined)
        let enabled = await makeActiveManager(granted)
        XCTAssertFalse(enabled.claimDockOffer())

        defaults.removePersistentDomain(forName: suiteName)
        let refused = FakeCenter(permission: .denied)
        let blocked = makeManager(refused)
        await blocked.refreshPermission()
        XCTAssertFalse(blocked.claimDockOffer())
    }
}
