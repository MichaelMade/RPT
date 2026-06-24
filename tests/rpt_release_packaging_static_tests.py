#!/usr/bin/env python3
"""Static release-prep checks for RPT's App Store packaging surface.

These are intentionally stdlib-only so the Linux cron runner can verify the
release metadata and in-app support/privacy wiring even when Xcode is not
available.
"""

from pathlib import Path
import re
import unittest
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
MONETIZATION = ROOT / "RPT" / "App" / "MonetizationPlan.swift"
ABOUT = ROOT / "RPT" / "Views" / "Settings" / "AboutView.swift"
README = ROOT / "README.md"
ROADMAP = ROOT / "ROADMAP.md"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def quoted_array(source: str, name: str) -> list[str]:
    match = re.search(rf"static let {name} = \[(.*?)\]\n", source, re.S)
    if not match:
        raise AssertionError(f"Could not find static array {name}")
    return re.findall(r'"([^"]+)"', match.group(1))


def release_url(source: str, name: str) -> str:
    match = re.search(rf'static let {name} = URL\(string: "([^"]+)"\)!', source)
    if not match:
        raise AssertionError(f"Could not find URL {name}")
    return match.group(1)


class RPTReleasePackagingStaticTests(unittest.TestCase):
    def test_release_metadata_matches_freemium_product(self):
        source = read(MONETIZATION)

        self.assertIn('static let subtitle = "Reverse pyramid training log"', source)
        self.assertIn("heavy top sets first", source)
        self.assertIn("private on-device workout history", source)
        self.assertIn("one-time lifetime upgrade", source)
        self.assertIn(MonetizationProduct.product_id(), source)

    def test_keyword_set_stays_within_app_store_connect_limit(self):
        source = read(MONETIZATION)
        keywords = quoted_array(source, "keywordPhrases")
        keyword_count = len(",".join(keywords))

        self.assertIn("rpt", keywords)
        self.assertIn("progressive overload", keywords)
        self.assertLessEqual(keyword_count, 100)
        self.assertIn("hasAppStoreSafeKeywordLength", source)

    def test_screenshot_story_covers_release_critical_screens(self):
        source = read(MONETIZATION)
        self.assertEqual(source.count("AppStoreScreenshotShot("), 5)
        for target in [
            "Active workout logging",
            "Templates and workout tools",
            "Stats dashboard",
            "Settings and export",
            "RPT Pro upgrade",
        ]:
            self.assertIn(target, source)

    def test_about_view_exposes_support_and_privacy_links(self):
        about = read(ABOUT)

        self.assertIn("Support & Privacy", about)
        self.assertIn("Get Support", about)
        self.assertIn("Privacy Policy", about)
        self.assertIn("Link(destination: url)", about)
        self.assertIn("AppStoreReleasePlan.supportURL", about)
        self.assertIn("AppStoreReleasePlan.privacyURL", about)
        self.assertIn('accessibilityHint("Opens in Safari")', about)

    def test_docs_track_release_packaging_status(self):
        readme = read(README)
        roadmap = read(ROADMAP)

        self.assertIn("Release packaging plan", readme)
        self.assertIn("[x] Build the App Store packaging plan", roadmap)
        self.assertIn("support URL", roadmap)
        self.assertIn("privacy URL", roadmap)

    def test_release_urls_are_live(self):
        source = read(MONETIZATION)
        urls = [release_url(source, "supportURL"), release_url(source, "privacyURL")]

        for url in urls:
            with self.subTest(url=url):
                request = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "Hermes-RPT-release-check"})
                try:
                    response = urllib.request.urlopen(request, timeout=15)
                    status = response.status
                except Exception:
                    request = urllib.request.Request(url, method="GET", headers={"User-Agent": "Hermes-RPT-release-check"})
                    response = urllib.request.urlopen(request, timeout=15)
                    status = response.status
                self.assertLess(status, 400)


class MonetizationProduct:
    @staticmethod
    def product_id() -> str:
        return "rpt.pro.lifetime"


if __name__ == "__main__":
    unittest.main(verbosity=2)
