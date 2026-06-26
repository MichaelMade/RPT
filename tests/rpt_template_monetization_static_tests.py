#!/usr/bin/env python3
"""Static regression checks for the RPT custom-template monetization hook.

The cron runner is Linux-only, so these tests assert the launch-critical Swift
wiring that cannot be compiled here: the freemium template limit, the template
screen's Pro upsell path, and the docs/roadmap release wording.
"""

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


class TemplateMonetizationStaticTests(unittest.TestCase):
    def test_monetization_plan_defines_template_limit_copy(self) -> None:
        plan = read("RPT/App/MonetizationPlan.swift")

        self.assertIn('static let freeCustomTemplateLimit = 1', plan)
        self.assertIn('static let starterTemplateName = "Upper Body RPT"', plan)
        self.assertIn('static let templateLimitTitle = "Unlock Unlimited Templates"', plan)
        self.assertIn('RPT Free includes the starter template plus one custom routine', plan)
        self.assertIn('RPT Pro unlocks unlimited custom templates', plan)

    def test_view_model_counts_custom_templates_against_starter_template(self) -> None:
        view_model = read("RPT/ViewModels/TemplateViewModel.swift")

        self.assertIn('@Published private(set) var customTemplateCount = 0', view_model)
        self.assertIn('customTemplateCount = templates.filter(Self.isCustomTemplate).count', view_model)
        self.assertIn('MonetizationPlan.freeCustomTemplateLimit - customTemplateCount', view_model)
        self.assertIn('func canCreateTemplate(isProUnlocked: Bool) -> Bool', view_model)
        self.assertIn('isProUnlocked || remainingFreeCustomTemplates > 0', view_model)
        self.assertIsNotNone(
            re.search(
                r'private static func isCustomTemplate\(_ template: WorkoutTemplate\).*?TemplateManager\.namesCollide\(template\.name, MonetizationPlan\.starterTemplateName\)',
                view_model,
                re.S,
            )
        )

    def test_template_screen_routes_create_and_duplicate_to_upgrade_when_limited(self) -> None:
        template_list = read("RPT/Views/Template/TemplatesListView.swift")

        self.assertIn('@ObservedObject private var purchaseManager = StoreKitPurchaseManager.shared', template_list)
        self.assertIn('@State private var showingUpgrade = false', template_list)
        self.assertIn('templateLimitCard', template_list)
        self.assertIn('NavigationStack {\n                    UpgradeView()', template_list)
        self.assertIn('await purchaseManager.start()', template_list)
        self.assertIn('private func requestCreateTemplate()', template_list)
        self.assertIn('viewModel.canCreateTemplate(isProUnlocked: purchaseManager.isUnlocked)', template_list)
        self.assertIn('showingUpgrade = true', template_list)
        self.assertIn('Label("View RPT Pro", systemImage: "arrow.up.circle.fill")', template_list)

        duplicate_guard = re.search(
            r'Button \{\s*guard viewModel\.canCreateTemplate\(isProUnlocked: purchaseManager\.isUnlocked\) else \{\s*showingUpgrade = true\s*return\s*\}\s*if !viewModel\.duplicateTemplate',
            template_list,
            re.S,
        )
        self.assertIsNotNone(duplicate_guard)

    def test_release_docs_describe_template_upgrade_hook(self) -> None:
        readme = read("README.md")
        roadmap = read("ROADMAP.md")

        self.assertIn('first unlimited-template upgrade hook', readme)
        self.assertIn('routes the second custom-template action into the RPT Pro upgrade screen', roadmap)
        self.assertIn('custom-template creation now has a launch-ready RPT Free limit', roadmap)

    def test_modified_swift_files_have_balanced_delimiters(self) -> None:
        for relative in [
            "RPT/App/MonetizationPlan.swift",
            "RPT/ViewModels/TemplateViewModel.swift",
            "RPT/Views/Template/TemplatesListView.swift",
        ]:
            source = read(relative)
            with self.subTest(file=relative):
                self.assertEqual(source.count("{"), source.count("}"))
                self.assertEqual(source.count("("), source.count(")"))
                self.assertEqual(source.count("["), source.count("]"))


if __name__ == "__main__":
    unittest.main()
