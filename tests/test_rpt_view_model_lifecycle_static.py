import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class RPTViewModelLifecycleStaticTests(unittest.TestCase):
    def test_exercise_picker_loads_library_after_eager_init_fetch_was_removed(self):
        picker = (
            ROOT / "RPT" / "Views" / "Workout" / "ExercisePickerView.swift"
        ).read_text()

        self.assertIn("@StateObject private var viewModel = ExerciseLibraryViewModel()", picker)
        self.assertRegex(
            picker,
            r"\.onAppear\s*\{\s*viewModel\.refreshExercises\(\)\s*\}",
        )

    def test_root_restores_resumable_workout_before_rearming_presentation(self):
        content_view = (ROOT / "RPT" / "App" / "ContentView.swift").read_text()

        self.assertRegex(
            content_view,
            r"\.onAppear\s*\{\s*session\.restoreResumableWorkout\(\)"
            r"\s*session\.rearmPresentationAfterRootSwap\(\)\s*\}",
        )


if __name__ == "__main__":
    unittest.main()
