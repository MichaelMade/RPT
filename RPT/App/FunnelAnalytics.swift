//
//  FunnelAnalytics.swift
//  RPT
//
//  Privacy-light install → paywall → purchase funnel. Events stay on
//  device. A remote sink can be swapped in later; it is a no-op until
//  a TelemetryDeck app ID is supplied.
//

import Foundation

// MARK: - Schema

enum FunnelEventName: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case install
    case onboardingComplete = "onboarding_complete"
    case paywallView = "paywall_view"
    case purchaseStart = "purchase_start"
    case purchaseSuccess = "purchase_success"
    case purchaseFail = "purchase_fail"
    case restore
}

enum FunnelSource: String, Codable, Equatable, Sendable {
    case settings
    case stats
    case templates
    case workoutDetail = "workout_detail"
    case onboardingStarter = "onboarding_starter"
    case onboardingCreateTemplate = "onboarding_create_template"
    case onboardingEmptyWorkout = "onboarding_empty_workout"
    case onboardingBrowse = "onboarding_browse"
}

enum FunnelGateReason: String, Codable, Equatable, Sendable {
    case templateLimit = "template_limit"
    case csvExport = "csv_export"
    case advancedStats = "advanced_stats"
}

struct FunnelEvent: Equatable, Codable, Sendable {
    let name: FunnelEventName
    let timestamp: Date
    let source: FunnelSource?
    let gateReason: FunnelGateReason?
    let price: String?
    let detail: String?

    init(
        name: FunnelEventName,
        timestamp: Date = Date(),
        source: FunnelSource? = nil,
        gateReason: FunnelGateReason? = nil,
        price: String? = nil,
        detail: String? = nil
    ) {
        self.name = name
        self.timestamp = timestamp
        self.source = source
        self.gateReason = gateReason
        self.price = price
        self.detail = detail
    }

    enum CodingKeys: String, CodingKey {
        case name
        case timestamp
        case source
        case gateReason = "gate_reason"
        case price
        case detail
    }
}

struct FunnelCounts: Equatable, Sendable {
    var install = 0
    var onboardingComplete = 0
    var paywallView = 0
    var purchaseStart = 0
    var purchaseSuccess = 0
    var purchaseFail = 0
    var restore = 0

    init() {}

    init(events: [FunnelEvent], since: Date, until: Date) {
        for event in events where event.timestamp >= since && event.timestamp <= until {
            increment(event.name)
        }
    }

    mutating func increment(_ name: FunnelEventName) {
        switch name {
        case .install:
            install += 1
        case .onboardingComplete:
            onboardingComplete += 1
        case .paywallView:
            paywallView += 1
        case .purchaseStart:
            purchaseStart += 1
        case .purchaseSuccess:
            purchaseSuccess += 1
        case .purchaseFail:
            purchaseFail += 1
        case .restore:
            restore += 1
        }
    }

    func count(for name: FunnelEventName) -> Int {
        switch name {
        case .install:
            return install
        case .onboardingComplete:
            return onboardingComplete
        case .paywallView:
            return paywallView
        case .purchaseStart:
            return purchaseStart
        case .purchaseSuccess:
            return purchaseSuccess
        case .purchaseFail:
            return purchaseFail
        case .restore:
            return restore
        }
    }

    /// Paid conversions per paywall view, or nil when nobody saw the paywall.
    var purchaseSuccessPerPaywall: Double? {
        guard paywallView > 0 else { return nil }
        return Double(purchaseSuccess) / Double(paywallView)
    }
}

struct FunnelReport: Equatable, Sendable {
    static let shortWindowDays = 7
    static let longWindowDays = 30

    let last7: FunnelCounts
    let last30: FunnelCounts

    static func make(events: [FunnelEvent], now: Date = Date()) -> FunnelReport {
        FunnelReport(
            last7: FunnelCounts(
                events: events,
                since: now.addingTimeInterval(-TimeInterval(shortWindowDays) * 24 * 60 * 60),
                until: now
            ),
            last30: FunnelCounts(
                events: events,
                since: now.addingTimeInterval(-TimeInterval(longWindowDays) * 24 * 60 * 60),
                until: now
            )
        )
    }
}

// MARK: - Abstraction

@MainActor
protocol FunnelAnalyticsClient: AnyObject {
    func track(_ event: FunnelEvent)
}

protocol FunnelEventStore: AnyObject {
    func append(_ event: FunnelEvent)
    func allEvents() -> [FunnelEvent]
}

protocol FunnelEventSink {
    var isConfigured: Bool { get }
    func send(_ event: FunnelEvent)
}

struct NoOpFunnelSink: FunnelEventSink {
    var isConfigured: Bool { false }

    func send(_ event: FunnelEvent) {}
}

/// Optional remote backend. Reads an app ID from `FunnelRemoteConfig`.
/// When the ID is blank the sink is a no-op so merge does not need a
/// TelemetryDeck (or other) account. When an ID is present, events are
/// still not uploaded until a concrete SDK is linked behind this type.
struct ConfigurableRemoteFunnelSink: FunnelEventSink {
    let appID: String?

    init(appID: String? = FunnelRemoteConfig.telemetryDeckAppID) {
        let trimmed = appID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.appID = trimmed.isEmpty ? nil : trimmed
    }

    var isConfigured: Bool { appID != nil }

    func send(_ event: FunnelEvent) {
        // Placeholder: no third-party SDK is linked. A future change can
        // forward `event` to TelemetryDeck (or similar) using `appID`.
        _ = event
        _ = appID
    }
}

enum FunnelRemoteConfig {
    /// TelemetryDeck app ID. Leave empty so CI and App Store builds need
    /// no secret. Michael can supply a value later; the sink stays a
    /// no-op until an SDK is also linked.
    static let telemetryDeckAppID = ""
}

// MARK: - On-device store

final class InMemoryFunnelEventStore: FunnelEventStore {
    private var events: [FunnelEvent] = []

    func append(_ event: FunnelEvent) {
        events.append(event)
    }

    func allEvents() -> [FunnelEvent] {
        events
    }
}

final class UserDefaultsFunnelEventStore: FunnelEventStore {
    static let eventsKey = "rpt.funnel.events"
    static let maxEventCount = 500

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func append(_ event: FunnelEvent) {
        var events = allEvents()
        events.append(event)
        if events.count > Self.maxEventCount {
            events = Array(events.suffix(Self.maxEventCount))
        }

        if let data = try? Self.encoder.encode(events) {
            defaults.set(data, forKey: Self.eventsKey)
        }
    }

    func allEvents() -> [FunnelEvent] {
        guard let data = defaults.data(forKey: Self.eventsKey) else {
            return []
        }
        return (try? Self.decoder.decode([FunnelEvent].self, from: data)) ?? []
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()
}

// MARK: - Client

@MainActor
final class FunnelAnalytics: FunnelAnalyticsClient {
    static let didRecordInstallKey = "rpt.funnel.didRecordInstall"
    static let didRecordOnboardingKey = "rpt.funnel.didRecordOnboardingComplete"

    static var shared = FunnelAnalytics()

    private let store: FunnelEventStore
    private let sink: FunnelEventSink
    private let defaults: UserDefaults

    private(set) var lastPaywallSource: FunnelSource?
    private(set) var lastPaywallGateReason: FunnelGateReason?

    init(
        store: FunnelEventStore? = nil,
        sink: FunnelEventSink = ConfigurableRemoteFunnelSink(),
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.store = store ?? UserDefaultsFunnelEventStore(defaults: defaults)
        self.sink = sink
    }

    var isRemoteConfigured: Bool { sink.isConfigured }

    func track(_ event: FunnelEvent) {
        store.append(event)
        sink.send(event)
    }

    func recordedEvents() -> [FunnelEvent] {
        store.allEvents()
    }

    func report(now: Date = Date()) -> FunnelReport {
        FunnelReport.make(events: store.allEvents(), now: now)
    }

    /// First launch of a fresh install. Existing users who already finished
    /// onboarding are not counted as new installs.
    func trackInstallIfNeeded(hasCompletedOnboarding: Bool) {
        guard defaults.object(forKey: Self.didRecordInstallKey) == nil else {
            return
        }
        defaults.set(true, forKey: Self.didRecordInstallKey)
        guard !hasCompletedOnboarding else {
            return
        }
        track(FunnelEvent(name: .install))
    }

    func trackOnboardingComplete(source: FunnelSource) {
        guard defaults.object(forKey: Self.didRecordOnboardingKey) == nil else {
            return
        }
        defaults.set(true, forKey: Self.didRecordOnboardingKey)
        track(FunnelEvent(name: .onboardingComplete, source: source))
    }

    func rememberPaywallContext(source: FunnelSource, gateReason: FunnelGateReason?) {
        lastPaywallSource = source
        lastPaywallGateReason = gateReason
    }

    func trackPaywallView(source: FunnelSource, gateReason: FunnelGateReason?, price: String?) {
        rememberPaywallContext(source: source, gateReason: gateReason)
        track(
            FunnelEvent(
                name: .paywallView,
                source: source,
                gateReason: gateReason,
                price: price
            )
        )
    }

    func trackPurchaseStart(price: String?) {
        track(purchaseEvent(name: .purchaseStart, price: price))
    }

    func trackPurchaseSuccess(price: String?) {
        track(purchaseEvent(name: .purchaseSuccess, price: price))
    }

    func trackPurchaseFail(price: String?, detail: String?) {
        track(purchaseEvent(name: .purchaseFail, price: price, detail: detail))
    }

    func trackRestore(price: String?) {
        track(purchaseEvent(name: .restore, price: price))
    }

    private func purchaseEvent(
        name: FunnelEventName,
        price: String?,
        detail: String? = nil
    ) -> FunnelEvent {
        FunnelEvent(
            name: name,
            source: lastPaywallSource,
            gateReason: lastPaywallGateReason,
            price: price,
            detail: detail
        )
    }

    #if DEBUG
    static func makeIsolatedForTesting() -> FunnelAnalytics {
        let suiteName = "rpt.funnel.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults()
        defaults.removePersistentDomain(forName: suiteName)
        return FunnelAnalytics(
            store: InMemoryFunnelEventStore(),
            sink: NoOpFunnelSink(),
            defaults: defaults
        )
    }

    static func replaceSharedForTesting(_ analytics: FunnelAnalytics) {
        shared = analytics
    }

    static func restoreShared() {
        shared = FunnelAnalytics()
    }
    #endif
}
