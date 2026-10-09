import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
FUNNEL = ROOT / "RPT" / "App" / "FunnelAnalytics.swift"
PURCHASE_MANAGER = ROOT / "RPT" / "App" / "StoreKitPurchaseManager.swift"
APP = ROOT / "RPT" / "App" / "RPTTrainerApp.swift"
ONBOARDING = ROOT / "RPT" / "Views" / "Onboarding" / "OnboardingView.swift"
UPGRADE = ROOT / "RPT" / "Views" / "Settings" / "UpgradeView.swift"
ABOUT = ROOT / "RPT" / "Views" / "Settings" / "AboutView.swift"
README = ROOT / "README.md"
PRIVACY_ANSWERS = ROOT / "docs" / "app-store-privacy-answers.md"
PRIVACY_POLICY = ROOT / "Privacy Policy"
PROJECT = ROOT / "RPT.xcodeproj" / "project.pbxproj"


class RPTFunnelAnalyticsStaticTests(unittest.TestCase):
    def test_event_schema_is_defined(self):
        source = FUNNEL.read_text()
        for name in [
            'case install',
            'case onboardingComplete = "onboarding_complete"',
            'case paywallView = "paywall_view"',
            'case purchaseStart = "purchase_start"',
            'case purchaseSuccess = "purchase_success"',
            'case purchaseFail = "purchase_fail"',
            'case restore',
        ]:
            with self.subTest(name=name):
                self.assertIn(name, source)

        self.assertIn("protocol FunnelAnalyticsClient", source)
        self.assertIn("protocol FunnelEventStore", source)
        self.assertIn("protocol FunnelEventSink", source)
        self.assertIn("ConfigurableRemoteFunnelSink", source)
        self.assertIn('static let telemetryDeckAppID = ""', source)

    def test_events_are_wired_through_install_onboarding_paywall_and_storekit(self):
        app = APP.read_text()
        onboarding = ONBOARDING.read_text()
        upgrade = UPGRADE.read_text()
        manager = PURCHASE_MANAGER.read_text()

        self.assertIn("trackInstallIfNeeded", app)
        self.assertIn("trackOnboardingComplete(source: plan.funnelSource)", onboarding)
        self.assertIn("trackOnboardingComplete(source: .onboardingBrowse)", onboarding)
        self.assertIn("trackPaywallView", upgrade)
        self.assertIn("trackPurchaseStart", manager)
        self.assertIn("trackPurchaseSuccess", manager)
        self.assertIn("trackPurchaseFail", manager)
        self.assertIn("trackRestore", manager)

    def test_readme_explains_how_to_read_the_funnel(self):
        readme = README.read_text()
        self.assertIn("## How to read the funnel", readme)
        self.assertIn("Settings → About RPT → On-device funnel", readme)
        self.assertIn("last 7 days", readme)
        self.assertIn("last 30 days", readme)
        self.assertIn("FunnelRemoteConfig.telemetryDeckAppID", readme)

    def test_about_exposes_on_device_report_without_dropping_privacy_copy(self):
        about = ABOUT.read_text()
        self.assertIn("FunnelReportView()", about)
        self.assertIn('Text("On-device funnel")', about)
        self.assertIn("no accounts, analytics, ads, tracking SDKs", about)

    def test_privacy_docs_keep_no_sdk_and_no_developer_collection(self):
        answers = PRIVACY_ANSWERS.read_text()
        policy = PRIVACY_POLICY.read_text()

        self.assertIn("Data collected by the developer:** No", answers)
        self.assertIn("Third-party analytics SDKs:** No", answers)
        self.assertIn("anonymous conversion-funnel events", answers)
        self.assertIn("We do not run third-party analytics", policy)
        self.assertIn("the developer does not collect data from the app", policy)
        self.assertIn("stored only on your device", policy)

    def test_version_and_build_number_are_unchanged(self):
        project = PROJECT.read_text()
        self.assertIn("MARKETING_VERSION = 2.2.1;", project)
        self.assertRegex(
            project,
            r"CURRENT_PROJECT_VERSION = 5;",
        )

    def test_funnel_sources_compile_as_balanced_swift(self):
        for path in [FUNNEL, UPGRADE, ABOUT]:
            with self.subTest(path=path.name):
                self._assert_balanced(path.read_text())

    def _assert_balanced(self, swift: str) -> None:
        delimiters = {"(": ")", "[": "]", "{": "}"}
        closers = {v: k for k, v in delimiters.items()}
        stack = []
        stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', swift)
        for char in stripped:
            if char in delimiters:
                stack.append(char)
            elif char in closers:
                self.assertTrue(stack, f"Unexpected closing delimiter {char}")
                self.assertEqual(stack.pop(), closers[char])
        self.assertEqual([], stack)


if __name__ == "__main__":
    unittest.main()
