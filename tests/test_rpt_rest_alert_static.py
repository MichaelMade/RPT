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
        # Matches plain, attributed (`@preconcurrency import`) and scoped
        # imports, and ignores commented-out lines.
        importers = sorted(
            path.relative_to(ROOT).as_posix()
            for path, source in _app_sources().items()
            if re.search(
                r"^(?!\s*//).*\bimport\s+(?:\w+\s+)?UserNotifications\b",
                source,
                flags=re.MULTILINE,
            )
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

    def test_system_wrapper_reports_refusal_and_clears_both_pending_and_delivered(self):
        source = SYSTEM_CENTER.read_text()

        # A refusal read as permission would turn the toggle on and silence
        # the dock while iOS delivers nothing. The wrapper only gathers
        # facts; RestAlertPolicy.permission (unit-tested) decides.
        self.assertRegex(
            source,
            r"case \.denied:\n\s*hasBeenAsked = true\n\s*isAuthorized = false",
        )
        self.assertRegex(
            source,
            r"@unknown default:\n\s*hasBeenAsked = true\n\s*isAuthorized = false",
        )
        self.assertRegex(
            source,
            r"case \.notDetermined:\n\s*hasBeenAsked = false\n\s*isAuthorized = false",
        )
        self.assertIn("return RestAlertPolicy.permission(", source)
        self.assertIn("playsSound: settings.soundSetting == .enabled", source)
        self.assertIn(
            "showsAlert: settings.alertSetting == .enabled || settings.lockScreenSetting == .enabled",
            source,
        )
        self.assertEqual(source.count("return ."), 0, "no permission is decided outside the policy")

        cancel = source.split("func cancelRestAlert(identifier: String) {")[1].split("\n    }\n")[0]
        self.assertIn("removePendingNotificationRequests(withIdentifiers: [identifier])", cancel)
        self.assertIn(
            "removeDeliveredNotifications(withIdentifiers: [identifier])",
            cancel,
            "a delivered banner must not be left in Notification Center after the lifter is back",
        )

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

        # enable() is called exactly twice in the app, each time from inside
        # a control the lifter has to act on. Counting every `.enable()`
        # keeps this honest however the manager is referenced.
        sources = _app_sources()
        self.assertEqual(sum(source.count(".enable()") for source in sources.values()), 2)

        settings = SETTINGS.read_text()
        toggle_binding = settings.split("private var restAlertBinding: Binding<Bool> {")[1].split("\n    }\n")[0]
        self.assertEqual(toggle_binding.count(".enable()"), 1)

        rest_timer = REST_TIMER.read_text()
        turn_on = rest_timer.split('Button("Turn On") {')[1].split('Button("Not Now"')[0]
        self.assertEqual(turn_on.count(".enable()"), 1, "the dock asks first; the system prompt only follows a yes")

        not_now = rest_timer.split('Button("Not Now", role: .cancel) {')[1].split("} message:")[0]
        self.assertIn(".declineDockOffer()", not_now)
        self.assertNotIn(".enable()", not_now)

        # The offer is only ever raised by tapping the bell.
        self.assertEqual(rest_timer.count("showingRestAlertOffer = true"), 1)

    def test_alert_is_scheduled_only_while_the_app_is_out_of_the_foreground(self):
        rest_timer = REST_TIMER.read_text()

        # The hand-off follows the app's own lifecycle notifications. The
        # dock sits in a full-screen cover, where `scenePhase` is not a
        # dependable signal for going to the background.
        receivers = dict(
            re.findall(
                r"\.onReceive\(NotificationCenter\.default\.publisher\(for: UIApplication\.(\w+)\)\) \{ _ in\n(.*?)\n        \}",
                rest_timer,
                flags=re.DOTALL,
            )
        )
        # Taken back on becoming active, not on entering the foreground: the
        # catch-up chime and haptic need an active app, as they did before.
        self.assertEqual(
            sorted(receivers),
            ["didBecomeActiveNotification", "didEnterBackgroundNotification"],
        )

        self.assertEqual(rest_timer.count(".scheduleRestEnd("), 1)
        background = receivers["didEnterBackgroundNotification"]
        self.assertIn("restAlerts.scheduleRestEnd(at: endDate, for: restID)", background)
        self.assertIn("restAlerts.beginRest(restID)", rest_timer.split(".onAppear {")[1].split(".task {")[0])
        self.assertIn("if !didComplete", background)

        self.assertIn("reclaimRestAlert()", receivers["didBecomeActiveNotification"])

        reclaim = rest_timer.split("private func reclaimRestAlert() {")[1].split("\n    }\n")[0]
        self.assertLess(
            reclaim.index("guard restAlerts.isCurrentRest(restID) else { return }"),
            reclaim.index("syncRemaining()"),
            "a dock that was replaced must not clear the live rest's alert",
        )
        self.assertLess(
            reclaim.index("syncRemaining()"),
            reclaim.index("restAlerts.cancelRestEnd()"),
            "the dock must see whether the alert already fired before it is cleared",
        )

        scene_handler = rest_timer.split(".onChange(of: scenePhase)")[1].split(".onReceive(")[0]
        self.assertNotIn("scheduleRestEnd", scene_handler)

    def test_a_rest_ends_when_it_is_skipped_or_its_screen_is_put_away(self):
        rest_timer = REST_TIMER.read_text()

        skip = rest_timer.split('Button("Skip") {')[1].split(".buttonStyle(")[0]
        self.assertLess(
            skip.index("restAlerts.endRest(restID)"),
            skip.index("onSkip()"),
            "the rest must be over before the dock starts its exit animation",
        )

        disappear = rest_timer.split(".onDisappear {")[1].split("\n        }\n")[0]
        self.assertIn("restAlerts.endRest(restID)", disappear)
        self.assertNotIn("cancelRestEnd", disappear, "a replaced dock leaving must not cancel the new rest's alert")

        content = (APP / "App" / "ContentView.swift").read_text()
        put_away = content.split(".onChange(of: session.isPresentingWorkout)")[1].split(".onAppear {")[0]
        self.assertRegex(
            put_away,
            r"if !isPresenting \{\n\s*RestAlertManager\.shared\.endCurrentRest\(\)",
        )

    def test_dock_chimes_unless_a_delivered_notification_already_announced_rest(self):
        rest_timer = REST_TIMER.read_text()
        completion = rest_timer.split("if newRemaining <= 0 {")[1].split("private func reclaimRestAlert")[0]

        # A dock that is only animating out announces nothing.
        self.assertLess(
            completion.index("guard restAlerts.isCurrentRest(restID) else { return }"),
            completion.index("SoundManager.shared.playTimerComplete()"),
        )

        # Fired while away: quiet, unless iOS had stopped allowing the alert.
        # Otherwise (every rest that ends with RPT in front): chime.
        self.assertRegex(
            completion,
            r"if restAlerts\.scheduledAlertHasFired\(asOf: now\) \{\n"
            r"(?:\s*//[^\n]*\n)*"
            r"\s*Task \{\n"
            r"\s*if await restAlerts\.scheduledAlertWasBlocked\(\) \{\n"
            r"\s*SoundManager\.shared\.playTimerComplete\(\)\n"
            r"\s*\}\n"
            r"\s*\}\n"
            r"\s*\} else \{\n"
            r"(?:\s*//[^\n]*\n)*"
            r"\s*SoundManager\.shared\.playTimerComplete\(\)\n"
            r"\s*\}",
        )
        self.assertEqual(rest_timer.count("SoundManager.shared.playTimerComplete()"), 2)

    def test_stale_alert_is_cleared_at_launch(self):
        self.assertIn("RestAlertManager.shared.cancelRestEnd()", APP_ENTRY.read_text())

    def test_settings_offers_the_toggle_and_a_way_out_when_blocked(self):
        settings = SETTINGS.read_text()
        self.assertIn('Text("Alert when rest ends")', settings)
        self.assertIn("get: { restAlerts.isActive }", settings)
        self.assertIn("UIApplication.openNotificationSettingsURLString", settings)
        self.assertIn('"Notifications Are Off for RPT"', settings)

        toggle_binding = settings.split("private var restAlertBinding: Binding<Bool> {")[1].split("\n    }\n")[0]
        self.assertIn("restAlerts.disable()", toggle_binding)

    def test_reset_to_defaults_turns_the_alert_off(self):
        settings = SETTINGS.read_text()
        reset = settings.split('Button("Reset to Defaults", role: .destructive) {')[1].split('Button("Cancel"')[0]
        self.assertRegex(
            reset,
            r"if settingsManager\.resetToDefaultsSafely\(\) \{\n(?:\s*//[^\n]*\n)*\s*restAlerts\.disable\(\)",
            "the dialog promises the rest timer group goes back to its defaults, and the alert's default is off",
        )

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
