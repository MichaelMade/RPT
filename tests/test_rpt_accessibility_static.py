import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
COMPONENTS = ROOT / "RPT" / "DesignSystem" / "Components.swift"
EXERCISE_FORM = ROOT / "RPT" / "Views" / "Exercises" / "ExerciseFormView.swift"
EXERCISE_DETAIL = ROOT / "RPT" / "Views" / "Exercises" / "ExerciseDetailView.swift"
ONBOARDING = ROOT / "RPT" / "Views" / "Onboarding" / "OnboardingView.swift"
ABOUT = ROOT / "RPT" / "Views" / "Settings" / "AboutView.swift"
EXERCISE_SECTION = ROOT / "RPT" / "Views" / "Workout" / "ExerciseSectionView.swift"
ACTIVE_WORKOUT = ROOT / "RPT" / "Views" / "Workout" / "ActiveWorkoutView.swift"


class RPTAccessibilityStaticTests(unittest.TestCase):
    def test_filter_and_muscle_group_selections_expose_selected_trait(self):
        components = COMPONENTS.read_text()
        filter_chip = components.split("struct FilterChip", 1)[1].split(
            "// MARK: - Empty State", 1
        )[0]
        muscle_grid = EXERCISE_FORM.read_text().split("struct MuscleGroupGrid", 1)[1]

        selected_trait = (
            ".accessibilityAddTraits(isSelected ? [.isSelected] : [])"
        )
        self.assertIn(selected_trait, filter_chip)
        self.assertIn(selected_trait, muscle_grid)

    def test_decorative_onboarding_symbols_are_hidden_from_voiceover(self):
        onboarding = ONBOARDING.read_text()

        self.assertGreaterEqual(onboarding.count(".accessibilityHidden(true)"), 2)
        self.assertIn("Image(systemName: page.icon)", onboarding)
        self.assertIn(
            'Image(systemName: "figure.strengthtraining.traditional")', onboarding
        )

    def test_email_link_has_email_specific_accessibility_hint(self):
        about = ABOUT.read_text()

        self.assertIn('accessibilityHint: "Opens your email app"', about)
        self.assertIn('accessibilityHint: String = "Opens in Safari"', about)
        self.assertIn(".accessibilityHint(accessibilityHint)", about)

    def test_strength_chart_exposes_a_spoken_summary(self):
        detail = EXERCISE_DETAIL.read_text()

        self.assertIn(
            '.accessibilityLabel("Estimated one-rep max trend")', detail
        )
        self.assertIn(".accessibilityValue(e1rmAccessibilitySummary)", detail)
        self.assertIn("Latest \\(OneRepMax.formatted(latest.value))", detail)
        self.assertIn("Best \\(OneRepMax.formatted(bestE1RM))", detail)

    def test_focused_workout_controls_have_44_point_hit_regions(self):
        components = COMPONENTS.read_text()
        stepper = components.split("struct ValueStepperControl", 1)[1]
        exercise_section = EXERCISE_SECTION.read_text()
        active_workout = ACTIVE_WORKOUT.read_text()

        self.assertGreaterEqual(
            stepper.count(".frame(width: 44, height: 44)"), 2
        )
        self.assertIn(
            ".frame(minWidth: 44, minHeight: 44)", exercise_section
        )
        self.assertIn("static let badge: CGFloat = 44", exercise_section)
        self.assertGreaterEqual(
            active_workout.count(".frame(width: 44, height: 44)"), 2
        )


if __name__ == "__main__":
    unittest.main()
