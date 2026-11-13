//
//  SystemRestAlertCenter.swift
//  RPT
//
//  The real notification centre behind `RestAlertManager`. Local
//  notifications only: nothing is registered for remote push.
//

import Foundation
import UserNotifications

@MainActor
final class SystemRestAlertCenter: RestAlertNotificationCenter {
    private var center: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }

    func restAlertPermission() async -> RestAlertPermission {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .granted
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func requestRestAlertPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func scheduleRestAlert(identifier: String, title: String, body: String, after interval: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Reusing the identifier replaces any alert still pending, so there
        // is never more than one.
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: max(RestAlertPolicy.minimumLeadTime, interval),
                repeats: false
            )
        )
        center.add(request, withCompletionHandler: nil)
    }

    func cancelRestAlert(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
