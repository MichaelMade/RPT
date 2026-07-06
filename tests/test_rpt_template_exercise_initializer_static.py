import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
WORKOUT_TEMPLATE = ROOT / "RPT" / "Models" / "WorkoutTemplate.swift"
TEMPLATE_SEARCH_TESTS = ROOT / "RPTTests" / "TemplateViewModelSearchTests.swift"


class RPTTemplateExerciseInitializerStaticTests(unittest.TestCase):
    def setUp(self):
        self.model = WORKOUT_TEMPLATE.read_text()

    def test_template_exercise_keeps_test_friendly_defaults(self):
        self.assertIn(
            "init(id: UUID = UUID(), exerciseName: String, suggestedSets: Int = 3, repRanges: [TemplateRepRange] = [], notes: String = \"\")",
            self.model,
        )
        self.assertIn("normalizedRepRanges(for: normalizedSets, from: repRanges)", self.model)

    def test_template_search_tests_use_shorthand_template_exercise_initializer(self):
        tests = TEMPLATE_SEARCH_TESTS.read_text()
        self.assertIn("TemplateExercise(exerciseName:", tests)

    def test_workout_template_has_balanced_delimiters_after_initializer_change(self):
        delimiters = {"(": ")", "[": "]", "{": "}"}
        closers = {v: k for k, v in delimiters.items()}
        stack = []

        for char in re.sub(r'"(?:\\.|[^"\\])*"', '""', self.model):
            if char in delimiters:
                stack.append(char)
            elif char in closers:
                self.assertTrue(stack, f"Unexpected closing delimiter {char}")
                self.assertEqual(stack.pop(), closers[char])

        self.assertEqual([], stack)


if __name__ == "__main__":
    unittest.main()
