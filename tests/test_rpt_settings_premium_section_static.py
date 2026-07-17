import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SETTINGS_VIEW = ROOT / "RPT" / "Views" / "Settings" / "SettingsView.swift"


class RPTSettingsPremiumSectionStaticTests(unittest.TestCase):
    def setUp(self):
        self.swift = SETTINGS_VIEW.read_text()

    def test_premium_section_uses_explicit_header_footer_initializers(self):
        section_body = self._property_body("premiumSection")

        self.assertIn("Section {", section_body)
        self.assertIn("NavigationLink", section_body)
        self.assertIn("UpgradeView()", section_body)
        self.assertIn('} header: {\n            Text("RPT Pro")', section_body)
        self.assertIn("} footer: {", section_body)
        self.assertNotIn('Section("RPT Pro")', section_body)

    def test_settings_view_has_balanced_delimiters_after_section_change(self):
        delimiters = {"(": ")", "[": "]", "{": "}"}
        closers = {v: k for k, v in delimiters.items()}
        stack = []

        for char in re.sub(r'"(?:\\.|[^"\\])*"', '""', self.swift):
            if char in delimiters:
                stack.append(char)
            elif char in closers:
                self.assertTrue(stack, f"Unexpected closing delimiter {char}")
                self.assertEqual(stack.pop(), closers[char])

        self.assertEqual([], stack)

    def _property_body(self, property_name):
        marker = f"private var {property_name}: some View {{"
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
        self.fail(f"Could not find body for {property_name}")


if __name__ == "__main__":
    unittest.main()
