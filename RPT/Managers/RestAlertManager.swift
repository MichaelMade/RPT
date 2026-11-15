//
//  RestAlertManager.swift
//  RPT
//
//  Lets the lifter know rest is over when RPT cannot: with the phone locked
//  or another app in front, the in-app chime never plays. A local
//  notification covers that gap. Nothing leaves the device, and the alert
//  is opt-in.
//

import Foundation
import Combine

/// The slice of the system notification centre the rest alert needs.
@MainActor
protocol RestAlertNotificationCenter: AnyObject {
    func restAlertPermission() async -> RestAlertPermission
    /// Shows the system permission prompt if it has not been answered yet.
    func requestRestAlertPermission() async -> Bool
    func scheduleRestAlert(identifier: String, title: String, body: String, after interval: TimeInterval)
    /// Removes the alert whether it is still pending or already delivered.
    func cancelRestAlert(identifier: String)
}

@MainActor
final class RestAlertManager: ObservableObject {
    static let shared = RestAlertManager()

    enum EnableResult: Equatable {
        case enabled
        case permissionDenied
    }

    /// The lifter's own choice. Delivery also needs iOS to allow it; see
    /// `isActive`.
    @Published private(set) var isEnabled: Bool
    @Published private(set) var permission: RestAlertPermission = .notDetermined

    private let center: RestAlertNotificationCenter
    private let defaults: UserDefaults

    /// When the alert that is currently scheduled will fire, if one is.
    private var scheduledFireDate: Date?

    /// The rest the dock is counting down right now. Logging the next set
    /// mid-rest replaces the dock, and the old one is still on screen for
    /// the length of its exit animation; it must not schedule an alert for
    /// a deadline that no longer applies.
    private var currentRestID: UUID?

    init(center: RestAlertNotificationCenter? = nil, defaults: UserDefaults = .standard) {
        self.center = center ?? SystemRestAlertCenter()
        self.defaults = defaults
        self.isEnabled = defaults.bool(forKey: RestAlertPolicy.enabledDefaultsKey)
    }

    /// Alerts will really be delivered: the lifter asked for them and iOS
    /// allows them.
    var isActive: Bool {
        isEnabled && permission == .granted
    }

    func refreshPermission() async {
        permission = await center.restAlertPermission()
    }

    /// Turns the alert on, asking iOS for permission the first time.
    @discardableResult
    func enable() async -> EnableResult {
        await refreshPermission()

        if permission == .notDetermined {
            _ = await center.requestRestAlertPermission()
            await refreshPermission()
        }

        guard permission == .granted else {
            setEnabled(false)
            return .permissionDenied
        }

        setEnabled(true)
        return .enabled
    }

    func disable() {
        setEnabled(false)
        cancelRestEnd()
    }

    // MARK: - Dock offer

    /// Call once per rest, after `refreshPermission()`. Returns whether this
    /// rest's dock should offer the alert, and counts the offer.
    func claimDockOffer() -> Bool {
        let offersShown = defaults.integer(forKey: RestAlertPolicy.dockOfferCountDefaultsKey)
        guard RestAlertPolicy.offersAlertInDock(
            isEnabled: isEnabled,
            permission: permission,
            offersShown: offersShown
        ) else {
            return false
        }

        defaults.set(offersShown + 1, forKey: RestAlertPolicy.dockOfferCountDefaultsKey)
        return true
    }

    /// "Not now" is an answer: stop offering from the dock.
    func declineDockOffer() {
        defaults.set(RestAlertPolicy.maxDockOffers, forKey: RestAlertPolicy.dockOfferCountDefaultsKey)
    }

    // MARK: - Scheduling

    /// Call when a rest countdown starts. Only that rest can schedule an
    /// alert from then on.
    func beginRest(_ restID: UUID) {
        currentRestID = restID
    }

    /// Schedules the alert for a rest ending at `endDate`. Call when RPT
    /// leaves the foreground; while it is in front the dock handles the end
    /// of rest itself. Returns whether an alert was scheduled.
    @discardableResult
    func scheduleRestEnd(at endDate: Date, for restID: UUID, now: Date = Date()) -> Bool {
        guard restID == currentRestID else { return false }

        guard let leadTime = RestAlertPolicy.leadTime(
            untilRestEndsAt: endDate,
            now: now,
            isEnabled: isEnabled,
            permission: permission
        ) else {
            return false
        }

        center.scheduleRestAlert(
            identifier: RestAlertPolicy.notificationIdentifier,
            title: RestAlertPolicy.notificationTitle,
            body: RestAlertPolicy.notificationBody,
            after: leadTime
        )
        scheduledFireDate = now.addingTimeInterval(leadTime)
        return true
    }

    /// Whether the scheduled alert has already gone off, in which case the
    /// lifter has been told and the dock should not chime a second time.
    func scheduledAlertHasFired(asOf now: Date = Date()) -> Bool {
        guard let scheduledFireDate else { return false }
        return scheduledFireDate <= now
    }

    /// For a rest whose alert time has already passed: whether iOS had
    /// stopped allowing the alert by then, in which case nothing told the
    /// lifter and the dock still has to. Permission can be withdrawn in the
    /// Settings app while RPT is in the background.
    func scheduledAlertWasBlocked() async -> Bool {
        await refreshPermission()
        return permission != .granted
    }

    /// Clears the alert, pending or delivered. Safe to call when none is
    /// scheduled; that also clears one left over from a previous launch.
    func cancelRestEnd() {
        scheduledFireDate = nil
        center.cancelRestAlert(identifier: RestAlertPolicy.notificationIdentifier)
    }

    private func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: RestAlertPolicy.enabledDefaultsKey)
        if isEnabled != enabled {
            isEnabled = enabled
        }
    }
}
