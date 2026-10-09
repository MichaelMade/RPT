import XCTest
@testable import RPT

@MainActor
final class FunnelAnalyticsTests: XCTestCase {
    func testEventSchemaUsesRequiredFunnelNames() {
        XCTAssertEqual(FunnelEventName.install.rawValue, "install")
        XCTAssertEqual(FunnelEventName.onboardingComplete.rawValue, "onboarding_complete")
        XCTAssertEqual(FunnelEventName.paywallView.rawValue, "paywall_view")
        XCTAssertEqual(FunnelEventName.purchaseStart.rawValue, "purchase_start")
        XCTAssertEqual(FunnelEventName.purchaseSuccess.rawValue, "purchase_success")
        XCTAssertEqual(FunnelEventName.purchaseFail.rawValue, "purchase_fail")
        XCTAssertEqual(FunnelEventName.restore.rawValue, "restore")
        XCTAssertEqual(FunnelEventName.allCases.count, 7)
    }

    func testPaywallAndPurchaseEventsCarrySourceGateReasonAndPrice() {
        let analytics = FunnelAnalytics.makeIsolatedForTesting()

        analytics.trackPaywallView(
            source: .templates,
            gateReason: .templateLimit,
            price: "$9.99"
        )
        analytics.trackPurchaseStart(price: "$9.99")
        analytics.trackPurchaseSuccess(price: "$9.99")
        analytics.trackRestore(price: "$9.99")

        let events = analytics.recordedEvents()
        XCTAssertEqual(events.map(\.name), [
            .paywallView,
            .purchaseStart,
            .purchaseSuccess,
            .restore
        ])

        for event in events {
            XCTAssertEqual(event.source, .templates)
            XCTAssertEqual(event.gateReason, .templateLimit)
            XCTAssertEqual(event.price, "$9.99")
        }
    }

    func testPurchaseFailKeepsPaywallContextAndStoresReason() throws {
        let analytics = FunnelAnalytics.makeIsolatedForTesting()
        analytics.trackPaywallView(
            source: .stats,
            gateReason: .advancedStats,
            price: "$9.99"
        )
        analytics.trackPurchaseStart(price: "$9.99")
        analytics.trackPurchaseFail(price: "$9.99", detail: "user_cancelled")

        let failed = try XCTUnwrap(analytics.recordedEvents().last)
        XCTAssertEqual(failed?.name, .purchaseFail)
        XCTAssertEqual(failed?.source, .stats)
        XCTAssertEqual(failed?.gateReason, .advancedStats)
        XCTAssertEqual(failed?.price, "$9.99")
        XCTAssertEqual(failed?.detail, "user_cancelled")
    }

    func testInstallFiresOnceForFreshOnboardingAndSkipsExistingUsers() {
        let fresh = FunnelAnalytics.makeIsolatedForTesting()
        fresh.trackInstallIfNeeded(hasCompletedOnboarding: false)
        fresh.trackInstallIfNeeded(hasCompletedOnboarding: false)
        XCTAssertEqual(fresh.recordedEvents().map(\.name), [.install])

        let existing = FunnelAnalytics.makeIsolatedForTesting()
        existing.trackInstallIfNeeded(hasCompletedOnboarding: true)
        existing.trackInstallIfNeeded(hasCompletedOnboarding: false)
        XCTAssertTrue(existing.recordedEvents().isEmpty)
    }

    func testOnboardingCompleteFiresOnceWithActivationSource() {
        let analytics = FunnelAnalytics.makeIsolatedForTesting()
        analytics.trackOnboardingComplete(source: .onboardingStarter)
        analytics.trackOnboardingComplete(source: .onboardingBrowse)

        XCTAssertEqual(analytics.recordedEvents().map(\.name), [.onboardingComplete])
        XCTAssertEqual(analytics.recordedEvents().first?.source, .onboardingStarter)
    }

    func testReportCountsLast7And30Days() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = InMemoryFunnelEventStore()
        let analytics = FunnelAnalytics(
            store: store,
            sink: NoOpFunnelSink(),
            defaults: UserDefaults(suiteName: "rpt.funnel.report.\(UUID().uuidString)") ?? .standard
        )

        analytics.track(FunnelEvent(name: .install, timestamp: now.addingTimeInterval(-2 * 24 * 60 * 60)))
        analytics.track(FunnelEvent(name: .paywallView, timestamp: now.addingTimeInterval(-8 * 24 * 60 * 60), source: .settings, price: "$9.99"))
        analytics.track(FunnelEvent(name: .purchaseSuccess, timestamp: now.addingTimeInterval(-10 * 24 * 60 * 60), source: .settings, price: "$9.99"))
        analytics.track(FunnelEvent(name: .restore, timestamp: now.addingTimeInterval(-31 * 24 * 60 * 60)))

        let report = analytics.report(now: now)
        XCTAssertEqual(report.last7.install, 1)
        XCTAssertEqual(report.last7.paywallView, 0)
        XCTAssertEqual(report.last7.purchaseSuccess, 0)
        XCTAssertEqual(report.last7.restore, 0)

        XCTAssertEqual(report.last30.install, 1)
        XCTAssertEqual(report.last30.paywallView, 1)
        XCTAssertEqual(report.last30.purchaseSuccess, 1)
        XCTAssertEqual(report.last30.restore, 0)
        XCTAssertEqual(report.last30.purchaseSuccessPerPaywall, 1.0)
        XCTAssertNil(report.last7.purchaseSuccessPerPaywall)
    }

    func testRemoteSinkStaysDisabledWithoutAppIDAndNoOpWhenConfigured() {
        let disabled = ConfigurableRemoteFunnelSink(appID: "")
        XCTAssertFalse(disabled.isConfigured)
        XCTAssertFalse(ConfigurableRemoteFunnelSink(appID: "   ").isConfigured)
        XCTAssertEqual(FunnelRemoteConfig.telemetryDeckAppID, "")

        let configured = ConfigurableRemoteFunnelSink(appID: "td-test-app")
        XCTAssertTrue(configured.isConfigured)
        configured.send(
            FunnelEvent(name: .restore, source: .settings, price: "$9.99")
        )
    }

    func testSimulatedPurchaseAndRestoreProduceExpectedFunnelEvents() {
        let analytics = FunnelAnalytics.makeIsolatedForTesting()

        analytics.trackInstallIfNeeded(hasCompletedOnboarding: false)
        analytics.trackOnboardingComplete(source: .onboardingEmptyWorkout)
        analytics.trackPaywallView(
            source: .settings,
            gateReason: .csvExport,
            price: "$9.99"
        )
        analytics.trackPurchaseStart(price: "$9.99")
        analytics.trackPurchaseSuccess(price: "$9.99")
        analytics.trackRestore(price: "$9.99")

        XCTAssertEqual(
            analytics.recordedEvents().map(\.name),
            [
                .install,
                .onboardingComplete,
                .paywallView,
                .purchaseStart,
                .purchaseSuccess,
                .restore
            ]
        )

        let report = analytics.report()
        XCTAssertEqual(report.last7.install, 1)
        XCTAssertEqual(report.last7.onboardingComplete, 1)
        XCTAssertEqual(report.last7.paywallView, 1)
        XCTAssertEqual(report.last7.purchaseStart, 1)
        XCTAssertEqual(report.last7.purchaseSuccess, 1)
        XCTAssertEqual(report.last7.restore, 1)
        XCTAssertEqual(report.last30.purchaseSuccess, 1)
    }

    func testUserDefaultsStorePersistsAndCapsEvents() throws {
        let suiteName = "rpt.funnel.store.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = UserDefaultsFunnelEventStore(defaults: defaults)

        store.append(FunnelEvent(name: .install))
        XCTAssertEqual(store.allEvents().map(\.name), [.install])

        for index in 0..<UserDefaultsFunnelEventStore.maxEventCount {
            store.append(FunnelEvent(name: .restore, detail: "\(index)"))
        }

        let events = store.allEvents()
        XCTAssertEqual(events.count, UserDefaultsFunnelEventStore.maxEventCount)
        XCTAssertEqual(events.first?.name, .restore)
        XCTAssertEqual(events.last?.detail, "\(UserDefaultsFunnelEventStore.maxEventCount - 1)")
    }
}
