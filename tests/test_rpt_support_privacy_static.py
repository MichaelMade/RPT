import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
ABOUT_VIEW = ROOT / "RPT" / "Views" / "Settings" / "AboutView.swift"
PRIVACY_POLICY = ROOT / "Privacy Policy"
PRIVACY_ANSWERS = ROOT / "docs" / "app-store-privacy-answers.md"
ROADMAP = ROOT / "ROADMAP.md"


class RPTSupportPrivacyStaticTests(unittest.TestCase):
    def test_about_screen_exposes_support_and_privacy_surface(self):
        about = ABOUT_VIEW.read_text()

        self.assertIn('Text("Support & Privacy")', about)
        self.assertIn('mailto:moorem88@gmail.com?subject=RPT%20Support', about)
        self.assertIn('title: "Email the Developer"', about)
        self.assertIn('AppStoreReleasePlan.supportURL', about)
        self.assertIn('AppStoreReleasePlan.privacyURL', about)
        self.assertIn('title: "Privacy Policy"', about)
        self.assertIn('no accounts, analytics, ads, tracking SDKs', about)
        self.assertIn('StoreKit handles RPT Pro purchases through Apple', about)

    def test_privacy_policy_matches_local_first_release_claims(self):
        policy = PRIVACY_POLICY.read_text()

        required_claims = [
            "RPT does not require an account",
            "We do not run third-party analytics",
            "The app does not track you across apps or websites",
            "stored locally on your device",
            "RPT creates a CSV file locally and opens the iOS share sheet",
            "RPT Pro purchase and restore actions are handled by Apple's StoreKit",
            "the developer does not collect data from the app",
            "does not integrate Apple Health, location services, contacts, camera, photo library",
        ]
        for claim in required_claims:
            with self.subTest(claim=claim):
                self.assertIn(claim, policy)

        contradicted_release_claims = [
            "we may collect certain information automatically",
            "App usage statistics and interaction data",
            "Apple Health, if enabled by you",
            "We may use third-party Service Providers to monitor and analyze",
            "Crash reporting tools: Collect information",
        ]
        for phrase in contradicted_release_claims:
            with self.subTest(phrase=phrase):
                self.assertNotIn(phrase, policy)

    def test_app_store_privacy_answers_and_roadmap_stay_in_sync(self):
        answers = PRIVACY_ANSWERS.read_text()
        roadmap = ROADMAP.read_text()

        for claim in [
            "Data collected by the developer:** No",
            "Tracking:** No",
            "Third-party analytics SDKs:** No",
            "CSV export creates a local file and opens the iOS share sheet",
            "rpt.pro.lifetime",
        ]:
            with self.subTest(claim=claim):
                self.assertIn(claim, answers)

        self.assertIn("docs/app-store-privacy-answers.md", roadmap)
        self.assertIn("a direct developer email path", roadmap)

    def test_about_view_has_balanced_delimiters_after_support_card_change(self):
        swift = ABOUT_VIEW.read_text()
        delimiters = {
            "(": ")",
            "[": "]",
            "{": "}",
        }
        closers = {v: k for k, v in delimiters.items()}
        stack = []

        # Lightweight lexical balance check; enough to catch common static edit slips on Linux.
        for char in re.sub(r'"(?:\\.|[^"\\])*"', '""', swift):
            if char in delimiters:
                stack.append(char)
            elif char in closers:
                self.assertTrue(stack, f"Unexpected closing delimiter {char}")
                self.assertEqual(stack.pop(), closers[char])

        self.assertEqual([], stack)


if __name__ == "__main__":
    unittest.main()
