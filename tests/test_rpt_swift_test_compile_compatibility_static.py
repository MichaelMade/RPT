import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
USER_MODEL_TESTS = ROOT / "RPTTests" / "UserModelTests.swift"
WORKOUT_MANAGER_TESTS = ROOT / "RPTTests" / "WorkoutManagerTests.swift"


class RPTSwiftTestCompileCompatibilityStaticTests(unittest.TestCase):
    def test_user_model_tests_use_current_muscle_group_case(self):
        source = USER_MODEL_TESTS.read_text()
        self.assertIn("primaryMuscleGroups: [.quadriceps]", source)
        self.assertNotIn(".quads", source)

    def test_optional_duration_assertion_is_unwrapped_for_accuracy_overload(self):
        source = WORKOUT_MANAGER_TESTS.read_text()
        self.assertIn(
            "XCTAssertEqual(manager.sanitizedCompletedWorkoutDuration(completedWorkout) ?? 0, 125, accuracy: 0.0001)",
            source,
        )


if __name__ == "__main__":
    unittest.main()
