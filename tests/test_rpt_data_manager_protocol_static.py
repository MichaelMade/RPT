import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
DATA_MANAGER = ROOT / "RPT" / "Managers" / "DataManager.swift"
MANAGER_PATHS = [
    ROOT / "RPT" / "Managers" / "WorkoutManager.swift",
    ROOT / "RPT" / "Managers" / "SettingsManager.swift",
    ROOT / "RPT" / "Managers" / "ExerciseManager.swift",
    ROOT / "RPT" / "Managers" / "TemplateManager.swift",
]


class RPTDataManagerProtocolStaticTests(unittest.TestCase):
    def test_shared_data_manager_conforms_to_dependency_protocol(self):
        source = DATA_MANAGER.read_text()

        self.assertIn("protocol DataManaging", source)
        self.assertRegex(
            source,
            r"@MainActor\s+(?:final\s+)?class\s+DataManager\s*:\s*DataManaging\s*{",
        )
        self.assertIn("func getModelContext() -> ModelContext", source)
        self.assertIn("func saveChanges() throws", source)

    def test_manager_default_dependencies_can_use_data_manager_shared(self):
        for path in MANAGER_PATHS:
            source = path.read_text()
            with self.subTest(manager=path.name):
                self.assertIn("DataManaging", source)
                self.assertIn("DataManager.shared", source)

    def test_data_manager_has_balanced_delimiters_after_protocol_change(self):
        source = DATA_MANAGER.read_text()
        delimiters = {"(": ")", "[": "]", "{": "}"}
        closers = {v: k for k, v in delimiters.items()}
        stack = []

        for char in re.sub(r'"(?:\\.|[^"\\])*"', '""', source):
            if char in delimiters:
                stack.append(char)
            elif char in closers:
                self.assertTrue(stack, f"Unexpected closing delimiter {char}")
                self.assertEqual(stack.pop(), closers[char])

        self.assertEqual([], stack)


if __name__ == "__main__":
    unittest.main()
