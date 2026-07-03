import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
STATS_VIEW = ROOT / "RPT" / "Views" / "Stats" / "StatsView.swift"
README = ROOT / "README.md"
ROADMAP = ROOT / "ROADMAP.md"


class RPTStatsMonetizationStaticTests(unittest.TestCase):
    def setUp(self):
        self.stats_view = STATS_VIEW.read_text()

    def test_stats_body_routes_advanced_sections_through_monetization_gate(self):
        body_completed_branch = re.search(
            r"summaryTiles\s+premiumPreviewCard\s+heatmapSection\s+advancedAnalyticsContent",
            self.stats_view,
        )
        self.assertIsNotNone(body_completed_branch)

        for direct_section in [
            "volumeSection",
            "muscleSection",
            "recordsSection",
        ]:
            self.assertIn(direct_section, self.stats_view)

    def test_advanced_analytics_require_unlocked_rpt_pro(self):
        gate_match = re.search(
            r"private var advancedAnalyticsContent: some View \{(?P<body>.*?)\n    \}\n\n    private var advancedAnalyticsLockedCard",
            self.stats_view,
            re.S,
        )
        self.assertIsNotNone(gate_match)
        if gate_match is None:
            self.fail("advancedAnalyticsContent gate was not found")
        gate_body = gate_match.group("body")

        self.assertIn("if purchaseManager.isUnlocked", gate_body)
        for advanced_section in ["volumeSection", "muscleSection", "recordsSection"]:
            self.assertIn(advanced_section, gate_body)
        self.assertIn("advancedAnalyticsLockedCard", gate_body)

    def test_locked_card_promotes_pro_without_hiding_basic_stats(self):
        self.assertIn('PillTag(text: "Advanced Analytics"', self.stats_view)
        self.assertIn("Weekly volume charts, muscle-balance breakdowns, and personal-record leaderboards", self.stats_view)
        self.assertIn("Unlock RPT Pro for \\(purchaseManager.displayPrice)", self.stats_view)

        # Free-tier users should still see the core/basic stat surface before the Pro gate.
        self.assertIn("summaryTiles", self.stats_view)
        self.assertIn("heatmapSection", self.stats_view)

    def test_release_docs_reflect_stats_pro_gate(self):
        readme = README.read_text()
        roadmap = ROADMAP.read_text()

        self.assertIn("advanced Stats analytics gating", readme)
        self.assertIn("reserves weekly volume charts, muscle-balance breakdowns, and personal-record leaderboards", roadmap)

    def test_stats_view_has_balanced_delimiters_after_gate_change(self):
        delimiters = {"(": ")", "[": "]", "{": "}"}
        closers = {v: k for k, v in delimiters.items()}
        stack = []
        stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', self.stats_view)

        for char in stripped:
            if char in delimiters:
                stack.append(char)
            elif char in closers:
                self.assertTrue(stack, f"Unexpected closing delimiter {char}")
                self.assertEqual(stack.pop(), closers[char])

        self.assertEqual([], stack)


if __name__ == "__main__":
    unittest.main()
