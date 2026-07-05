import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
WORKOUT_DETAIL = ROOT / "RPT" / "Views" / "Home" / "WorkoutDetailView.swift"
ROADMAP = ROOT / "ROADMAP.md"


class RPTWorkoutDetailTemplateMonetizationStaticTests(unittest.TestCase):
    def setUp(self):
        self.swift = WORKOUT_DETAIL.read_text()

    def test_save_as_template_uses_same_pro_limit_as_template_creation(self):
        save_body = self._function_body("saveAsTemplate")

        self.assertIn("WorkoutTemplateBuilder.templateExercises(from: workout)", save_body)
        self.assertIn("MonetizationPlan.canCreateTemplate", save_body)
        self.assertIn("existingCount: templateManager.fetchAllTemplates().count", save_body)
        self.assertIn("isUnlocked: purchaseManager.isUnlocked", save_body)
        self.assertIn("showingUpgrade = true", save_body)
        self.assertIn("return", save_body)
        self.assertLess(
            save_body.index("MonetizationPlan.canCreateTemplate"),
            save_body.index("templateManager.createTemplate"),
            "the Pro limit must gate before a new template is persisted",
        )

    def test_workout_detail_can_present_upgrade_sheet_and_refresh_entitlement(self):
        self.assertIn("@ObservedObject private var purchaseManager = StoreKitPurchaseManager.shared", self.swift)
        self.assertIn("@State private var showingUpgrade = false", self.swift)
        self.assertIn(".sheet(isPresented: $showingUpgrade)", self.swift)
        self.assertIn("UpgradeView()", self.swift)
        self.assertIn("Button(\"Close\") { showingUpgrade = false }", self.swift)
        self.assertIn("await purchaseManager.start()", self.swift)

    def test_roadmap_records_the_save_as_template_gate(self):
        roadmap = ROADMAP.read_text()
        self.assertIn("Save as Template", roadmap)
        self.assertIn("respects the free-tier template limit", roadmap)
        self.assertIn("routes over-limit users to the RPT Pro upgrade", roadmap)

    def test_workout_detail_has_balanced_delimiters_after_sheet_change(self):
        stack = []
        delimiters = {"(": ")", "[": "]", "{": "}"}
        closers = {v: k for k, v in delimiters.items()}

        for char in re.sub(r'"(?:\\.|[^"\\])*"', '""', self.swift):
            if char in delimiters:
                stack.append(char)
            elif char in closers:
                self.assertTrue(stack, f"Unexpected closing delimiter {char}")
                self.assertEqual(stack.pop(), closers[char])

        self.assertEqual([], stack)

    def _function_body(self, function_name):
        marker = f"private func {function_name}() {{"
        start = self.swift.index(marker)
        open_brace = self.swift.index("{", start)
        depth = 0
        for index in range(open_brace, len(self.swift)):
            char = self.swift[index]
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    return self.swift[open_brace:index + 1]
        self.fail(f"Could not find body for {function_name}")


if __name__ == "__main__":
    unittest.main()
