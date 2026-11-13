"""The rest-end alert is an opt-in local notification.

These checks keep it that way: no remote push, no permission prompt the
lifter did not ask for, and disclosures that match what the binary does.
"""

import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP = ROOT / "RPT"
SYSTEM_CENTER = APP / "Managers" / "SystemRestAlertCenter.swift"
MANAGER = APP / "Managers" / "RestAlertManager.swift"
POLICY = APP / "Utilities" / "RestAlertPolicy.swift"
REST_TIMER = APP / "Views" / "Workout" / "RestTimerView.swift"
SETTINGS = APP / "Views" / "Settings" / "SettingsView.swift"
APP_ENTRY = APP / "App" / "RPTTrainerApp.swift"
PRIVACY_POLICY = ROOT / "Privacy Policy"
PRIVACY_ANSWERS = ROOT / "docs" / "app-store-privacy-answers.md"
README = ROOT / "README.md"
SUPPORT_DOC = ROOT / "SUPPORT.md"


def _app_sources():
    return {path: path.read_text() for path in APP.rglob("*.swift")}


class RPTRestAlertStaticTests(unittest.TestCase):
    def test_user_notifications_stays_behind_one_wrapper(self):
        importers = sorted(
            path.relative_to(ROOT).as_posix()
            for path, source in _app_sources().items()
            if re.search(r"^\s*import\s+UserNotifications\b", source, flags=re.MULTILINE)
        )
        self.assertEqual(importers, ["RPT/Managers/SystemRestAlertCenter.swift"])

    def test_only_local_alert_and_sound_are_requested(self):
        source = SYSTEM_CENTER.read_text()
        self.assertEqual(
            re.findall(r"requestAuthorization\(options:\s*(\[[^\]]*\])", source),
            ["[.alert, .sound]"],
        )
        self.assertNotIn(".badge", source)
        self.assertNotIn(".provisional", source.split("func requestRestAlertPermission")[1].split("func ")[0])
        self.assertIn("UNTimeIntervalNotificationTrigger", source)
        self.assertIn("repeats: false", source)

    def test_app_never_registers_for_remote_push(self):
        for path, source in _app_sources().items():
            with self.subTest(file=path.name):
                self.assertNotIn("registerForRemoteNotifications", source)
                self.assertNotIn("didRegisterForRemoteNotifications", source)

        entitlements = list(ROOT.glob("**/*.entitlements"))
        for entitlement in entitlements:
            with self.subTest(file=entitlement.name):
                self.assertNotIn("aps-environment", entitlement.read_text())

        project = (ROOT / "RPT.xcodeproj" / "project.pbxproj").read_text()
        self.assertNotIn("aps-environment", project)
        self.assertNotIn("remote-notification", project)

    def test_permission_is_requested_only_from_an_explicit_opt_in(self):
        manager = MANAGER.read_text()
        self.assertEqual(
            manager.count("center.requestRestAlertPermission()"),
            1,
            "enable() is the only path to the system prompt",
        )
        enable_body = manager.split("func enable() async -> EnableResult {")[1].split("\n    }\n")[0]
        self.assertIn("center.requestRestAlertPermission()", enable_body)

        callers = {
            path.relative_to(ROOT).as_posix()
            for path, source in _app_sources().items()
            if re.search(r"restAlerts\.enable\(\)|RestAlertManager\.shared\.enable\(\)", source)
        }
        self.assertEqual(
            callers,
            {"RPT/Views/Settings/SettingsView.swift", "RPT/Views/Workout/RestTimerView.swift"},
        )

        rest_timer = REST_TIMER.read_text()
        self.assertIn('Button("Turn On")', rest_timer)
        self.assertIn('Button("Not Now", role: .cancel)', rest_timer)
        self.assertLess(
            rest_timer.index('Button("Turn On")'),
            rest_timer.index("await restAlerts.enable()"),
            "the dock asks first; the system prompt only follows a yes",
        )
        self.assertIn("restAlerts.declineDockOffer()", rest_timer)

    def test_alert_is_scheduled_only_while_the_app_is_out_of_the_foreground(self):
        rest_timer = REST_TIMER.read_text()
        scene_handler = rest_timer.split(".onChange(of: scenePhase)")[1].split(".alert(")[0]

        background = scene_handler.split("case .background:")[1].split("case .active:")[0]
        active = scene_handler.split("case .active:")[1].split("default:")[0]

        self.assertEqual(rest_timer.count("restAlerts.scheduleRestEnd("), 1)
        self.assertIn("restAlerts.scheduleRestEnd(at: endDate)", background)
        self.assertIn("if !didComplete", background)
        self.assertIn("restAlerts.cancelRestEnd()", active)
        self.assertLess(
            active.index("syncRemaining()"),
            active.index("restAlerts.cancelRestEnd()"),
            "the dock must see whether the alert already fired before it is cleared",
        )

        completion = rest_timer.split("if newRemaining <= 0 {")[1].split("private func adjust")[0]
        self.assertIn("restAlerts.scheduledAlertHasFired(asOf: now)", completion)
        self.assertIn("SoundManager.shared.playTimerComplete()", completion)

    def test_stale_alert_is_cleared_at_launch(self):
        self.assertIn("RestAlertManager.shared.cancelRestEnd()", APP_ENTRY.read_text())

    def test_settings_offers_the_toggle_and_a_way_out_when_blocked(self):
        settings = SETTINGS.read_text()
        self.assertIn('Text("Alert when rest ends")', settings)
        self.assertIn("get: { restAlerts.isActive }", settings)
        self.assertIn("restAlerts.disable()", settings)
        self.assertIn("UIApplication.openNotificationSettingsURLString", settings)
        self.assertIn('"Notifications Are Off for RPT"', settings)

    def test_notification_text_is_fixed_and_carries_no_workout_data(self):
        policy = POLICY.read_text()
        self.assertIn('static let notificationTitle = "Rest complete"', policy)
        self.assertIn('static let notificationBody = "Time for your next set."', policy)
        self.assertNotIn("\\(", policy.split("static let enabledDefaultsKey")[0])

    def test_disclosures_describe_the_alert(self):
        policy = PRIVACY_POLICY.read_text()
        self.assertIn("RPT sends notifications only if you turn on the rest-end alert", policy)
        self.assertIn("RPT does not use remote push notifications", policy)
        self.assertIn("it contains no workout data", policy)

        answers = PRIVACY_ANSWERS.read_text()
        self.assertIn("## Notifications", answers)
        self.assertIn("opt-in and uses local notifications only", answers)
        self.assertIn("no `aps-environment` entitlement", answers)

        readme = README.read_text()
        self.assertIn("Alert when rest ends", readme)
        self.assertNotIn("does not yet alert you when the phone is locked", readme)
        self.assertNotIn("location, notifications, or tracking permissions", readme)

        self.assertIn("## Rest timer alerts", SUPPORT_DOC.read_text())


if __name__ == "__main__":
    unittest.main()
