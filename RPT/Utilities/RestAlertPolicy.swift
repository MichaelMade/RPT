//
//  RestAlertPolicy.swift
//  RPT
//
//  The decisions behind the rest-end alert, kept free of UserNotifications
//  so they can be tested without the system.
//

import Foundation

/// What iOS currently lets RPT do with notifications.
enum RestAlertPermission: Equatable {
    /// The system prompt has never been answered.
    case notDetermined
    case denied
    case granted
}

enum RestAlertPolicy {
    static let notificationIdentifier = "rpt.rest-timer.complete"
    static let notificationTitle = "Rest complete"
    static let notificationBody = "Time for your next set."

    static let enabledDefaultsKey = "restTimer.endAlertEnabled"
    static let dockOfferCountDefaultsKey = "restTimer.endAlertDockOfferCount"

    /// How many rests carry the in-dock offer before RPT stops asking. The
    /// setting stays available after that.
    static let maxDockOffers = 5

    /// A rest that is over in less than this is not worth an alert, and the
    /// system rejects a trigger that is not in the future.
    static let minimumLeadTime: TimeInterval = 1

    /// No rest runs this long. Anything further out is a countdown that was
    /// never started, not a rest to announce.
    static let maximumLeadTime: TimeInterval = 60 * 60

    /// Reads iOS's notification settings as one answer: can an alert from
    /// RPT actually reach the lifter?
    ///
    /// Being authorized is not enough. With sound off and no banner or
    /// lock-screen alert, iOS files the notification silently, which tells
    /// nobody that rest is over. That counts as refused, so the toggle reads
    /// off and the dock keeps announcing rest itself.
    static func permission(
        hasBeenAsked: Bool,
        isAuthorized: Bool,
        playsSound: Bool,
        showsAlert: Bool
    ) -> RestAlertPermission {
        guard hasBeenAsked else { return .notDetermined }
        guard isAuthorized else { return .denied }
        return (playsSound || showsAlert) ? .granted : .denied
    }

    /// How long from `now` the alert should fire, or nil when none should
    /// be scheduled.
    static func leadTime(
        untilRestEndsAt endDate: Date,
        now: Date,
        isEnabled: Bool,
        permission: RestAlertPermission
    ) -> TimeInterval? {
        guard isEnabled, permission == .granted else { return nil }

        let remaining = endDate.timeIntervalSince(now)
        guard remaining.isFinite, (minimumLeadTime...maximumLeadTime).contains(remaining) else { return nil }

        return remaining
    }

    /// Whether the rest dock should offer to turn alerts on. Only while the
    /// system prompt is still unanswered: once iOS has an answer, asking
    /// again from the dock could do nothing but nag.
    static func offersAlertInDock(
        isEnabled: Bool,
        permission: RestAlertPermission,
        offersShown: Int
    ) -> Bool {
        !isEnabled && permission == .notDetermined && offersShown < maxDockOffers
    }
}
