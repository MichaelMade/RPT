"""Units: every load the lifter sees or types goes through WeightUnit.

Loads used to be whole pounds with "lb" written into views. These checks
keep a pound-only shortcut from creeping back into a screen, where a
kilogram lifter would see or log the wrong number.
"""

import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP = ROOT / "RPT"
VIEWS = APP / "Views"
EXERCISE_SET = APP / "Models" / "ExerciseSet.swift"
WEIGHT_UNIT = APP / "Utilities" / "WeightUnit.swift"
CONTENT_VIEW = APP / "App" / "ContentView.swift"
SETTINGS = VIEWS / "Settings" / "SettingsView.swift"
ONBOARDING = VIEWS / "Onboarding" / "OnboardingView.swift"
EXERCISE_SECTION = VIEWS / "Workout" / "ExerciseSectionView.swift"
CSV_EXPORTER = APP / "Utilities" / "WorkoutCSVExporter.swift"


def _strip_comments(source):
    return re.sub(r"//[^\n]*", "", source)


def _sources(*roots):
    files = {}
    for root in roots:
        for path in sorted(root.rglob("*.swift")):
            files[path.relative_to(ROOT).as_posix()] = _strip_comments(path.read_text())
    return files


class RPTWeightUnitStaticTests(unittest.TestCase):
    def test_no_screen_writes_pounds_into_its_text(self):
        # A string literal that ends a number with "lb" is a hard-coded
        # unit. The only places allowed to spell a unit are the unit type
        # itself, the picker labels, barbell names, and the legacy
        # whole-pound formatter kept for old call sites.
        allowed = {
            "RPT/Utilities/WeightUnit.swift",
            "RPT/Managers/PlateCalculator.swift",
        }
        # An interpolation (one level of nested parentheses is enough for
        # `\(Int(volume))`) or a digit, then the unit.
        interpolation = r"\\\((?:[^()\"\n]|\([^()\"\n]*\))*\)"
        pattern = re.compile(r'"[^"\n]*(?:' + interpolation + r'|\d)\s*(?:lb|lbs|pounds?)\b[^"\n]*"')
        offenders = []
        for name, source in _sources(APP).items():
            if name in allowed:
                continue
            for match in pattern.finditer(source):
                text = match.group(0)
                if name == "RPT/Models/ExerciseSet.swift" and "safeWeight" in text:
                    continue
                offenders.append(f"{name}: {text}")
        self.assertEqual(offenders, [], "Use WeightUnit.formatted / .short instead of writing the unit out.")

    def test_unit_symbols_are_spelled_in_one_place(self):
        source = WEIGHT_UNIT.read_text()
        self.assertIn('case .pounds: return "lb"', source)
        self.assertIn('case .kilograms: return "kg"', source)
        self.assertIn('static let defaultsKey = "training.weightUnit"', source)
        self.assertIn("static let kilogramsPerPound = 0.45359237", source)

    def test_screens_do_not_use_the_pound_only_shortcuts(self):
        shortcuts = [
            r"roundToNearest5\(",
            r"plan\(topSetWeight:",
            r"suggestion\(\s*lastWeight:",
            r"estimate\(weight:",
            r"updateSetSafely\([^)]*weight:",
            r"addWarmupSetSafely\([^)]*weight:",
            r"previousWeight:",
            r"WarmupPlanner\.barWeight",
            r"SetInputParser\.weight\(",
        ]
        view_sources = _sources(VIEWS)
        view_sources.update(
            {
                name: source
                for name, source in _sources(APP / "ViewModels").items()
                if not name.endswith("ActiveWorkoutViewModel.swift")
            }
        )
        for name, source in view_sources.items():
            for shortcut in shortcuts:
                with self.subTest(file=name, shortcut=shortcut):
                    self.assertNotRegex(source, shortcut)

    def test_a_sets_weight_is_only_written_through_its_load_setters(self):
        offenders = []
        for name, source in _sources(APP).items():
            if name in ("RPT/Models/ExerciseSet.swift", "RPT/Models/User.swift"):
                continue
            for match in re.finditer(r"\b\w+\??\.weight\s*=[^=]", source):
                offenders.append(f"{name}: {match.group(0).strip()}")
        self.assertEqual(
            offenders,
            [],
            "Writing ExerciseSet.weight directly leaves a stale exact load behind. Use setLoad(_:in:).",
        )

        model = EXERCISE_SET.read_text()
        self.assertIn("var loadValue: Double? = nil", model)
        self.assertIn("var loadUnitRaw: String? = nil", model)
        self.assertIn("func setLoad(_ value: Double, in unit: WeightUnit)", model)

    def test_set_editor_types_and_saves_in_the_lifters_unit(self):
        source = EXERCISE_SECTION.read_text()
        self.assertIn('Text("Weight (\\(unit.short))")', source)
        self.assertIn("SetInputParser.load(from: weightText, unit: unit)", source)
        self.assertIn("showValidation(unit.entryValidationMessage)", source)
        self.assertIn(".keyboardType(unit.entryFractionDigits > 0 ? .decimalPad : .numberPad)", source)
        self.assertIn("weightText = set.loadEntryText(in: unit)", source)
        self.assertIn("let onSave: (Double, Int) -> Void", source)

        apply = source.split("private func applyEditedValues(")[1].split("\n    }\n")[0]
        self.assertLess(
            apply.index("let previousLoad = set.load(in: weightUnit)"),
            apply.index("viewModel.updateSetSafely(set, load: load, unit: weightUnit"),
            "the old load has to be read before the save overwrites it",
        )
        self.assertIn("previousLoad: previousLoad, unit: weightUnit", apply)

        # RPE edits must not pass the load back through a whole-pound API.
        self.assertIn("viewModel.updateRPESafely(set, rpe: rpe)", source)

    def test_settings_offers_the_unit_and_the_other_tabs_follow_it(self):
        settings = SETTINGS.read_text()
        self.assertIn("@AppStorage(WeightUnit.defaultsKey) private var weightUnit: WeightUnit = .pounds", settings)
        self.assertIn('Picker("Weight unit", selection: $weightUnit)', settings)
        self.assertIn("weightUnitRow", settings.split('settingsGroup("Training") {')[1].split("}")[0])

        content = CONTENT_VIEW.read_text()
        self.assertIn("@AppStorage(WeightUnit.defaultsKey) private var weightUnit: WeightUnit = .pounds", content)
        for tab in ("HomeView()", "TemplatesListView()", "ExercisesView()", "StatsView()"):
            with self.subTest(tab=tab):
                self.assertRegex(content, re.escape(tab) + r"\n\s*\.id\(weightUnit\)")
        self.assertNotRegex(
            content,
            r"SettingsView\(\)\n\s*\.id\(weightUnit\)",
            "Settings holds the picker; rebuilding it on change would reset the screen under the lifter's thumb",
        )

    def test_existing_lifters_stay_in_pounds_and_new_ones_get_their_regions_unit(self):
        unit = WEIGHT_UNIT.read_text()
        self.assertIn("return stored(in: .standard) ?? .pounds", unit)

        # The test-only override must not exist in a release build.
        override = unit.split("static var overrideForTesting: WeightUnit?")[0].rsplit("#if DEBUG", 1)
        self.assertEqual(len(override), 2, "overrideForTesting must sit inside #if DEBUG")
        self.assertNotIn("#endif", override[1])
        app_entry = (APP / "App" / "RPTTrainerApp.swift").read_text()
        pin = app_entry.split("WeightUnit.overrideForTesting = .pounds")[0].rsplit("#if DEBUG", 1)
        self.assertEqual(len(pin), 2, "the app may only pin the unit in a debug build")
        self.assertNotIn("#endif", pin[1])
        self.assertIn('environment["XCTestConfigurationFilePath"] != nil', pin[1])

        callers = [
            name
            for name, source in _sources(APP).items()
            if "adoptSuggestedIfUnset()" in source and not name.endswith("WeightUnit.swift")
        ]
        self.assertEqual(
            callers,
            ["RPT/Views/Onboarding/OnboardingView.swift"],
            "Only a first launch may pick a unit for the lifter",
        )

        onboarding = ONBOARDING.read_text()

        # Every way out of onboarding picks the unit, and before a workout
        # is created so the starter workout is planned in it.
        exits = {
            "completeOnboarding(using plan: OnboardingLaunchPlan)": "createWorkoutFromTemplate",
            "completeOnboardingByBrowsing()": "hasCompletedOnboarding = true",
        }
        for signature, later in exits.items():
            with self.subTest(exit=signature):
                body = onboarding.split(f"private func {signature} {{")[1].split("\n    }\n")[0]
                self.assertIn("adoptRegionalUnitIfNew()", body)
                self.assertLess(body.index("adoptRegionalUnitIfNew()"), body.index(later))

        # Someone with workouts already logged was using pounds, whatever
        # the onboarding flag says.
        adopt = onboarding.split("private func adoptRegionalUnitIfNew() {")[1].split("\n    }\n")[0]
        self.assertIn("guard !hasHistory else { return }", adopt)
        self.assertLess(adopt.index("guard !hasHistory"), adopt.index("WeightUnit.adoptSuggestedIfUnset()"))

    def test_screens_convert_what_they_show(self):
        sources = _sources(VIEWS)

        # Totals and records are held in pounds. A screen that prints one
        # with Int(...) or plots it raw shows pounds under a "kg" label.
        raw_reads = [
            r"Int\([^()\n]*totalVolume[^()\n]*\)",
            r"Int\(safeVolume\)",
            r"record\.weight\b",
            r'\.value\("e1RM", point\.value\)',
            r'\.value\("Volume", point\.volume\)',
            r"Int\(lastBest",
        ]
        for name, source in sources.items():
            for pattern in raw_reads:
                with self.subTest(file=name, pattern=pattern):
                    self.assertNotRegex(source, pattern)

        home = (VIEWS / "Home" / "HomeView.swift").read_text()
        card = (VIEWS / "Home" / "WorkoutCard.swift").read_text()
        stats = (VIEWS / "Stats" / "StatsView.swift").read_text()
        self.assertIn("unit.wholeNumber(forPounds: volume)", home)
        self.assertIn("unit.wholeNumber(forPounds: workout.totalVolume)", card)

        compact = stats.split("private func compactVolume(_ volume: Double) -> String {")[1].split("\n    }\n")[0]
        self.assertIn("unit.wholeNumber(forPounds: pounds)", compact)
        self.assertNotIn("Int(safe)", compact, "truncating a converted total prints 959 for a 960 kg week")
        self.assertIn('y: .value("Volume", chartUnit.converting(point.volume, from: .pounds))', stats)
        self.assertIn("record.writtenLoad", stats)

        detail = (VIEWS / "Exercises" / "ExerciseDetailView.swift").read_text()
        self.assertEqual(detail.count('y: .value("e1RM", chartValue(point))'), 2)

    def test_workout_sheets_open_in_the_lifters_unit(self):
        section = EXERCISE_SECTION.read_text()
        self.assertIn("topSetLoad: topWorkingSet?.loadableLoad(in: weightUnit) ?? 0", section)
        self.assertIn("unit: weightUnit", section.split("WarmupPlanView(")[1].split(") { steps in")[0])
        self.assertIn("load: step.load, unit: weightUnit", section)
        self.assertIn("initialUnit: weightUnit", section.split("PlateCalculatorView(")[1].split(")\n")[0])

        plates = (VIEWS / "Workout" / "PlateCalculatorView.swift").read_text()
        on_appear = plates.split(".onAppear {")[1].split("\n            }\n")[0]
        self.assertIn("unit = initialUnit", on_appear, "a 102.5 kg target must not be plated as 102.5 lb")
        self.assertIn("targetText = initialUnit.string(for: initialTargetLoad)", on_appear)
        self.assertIn("WeightUnit.plainString(for: value)", plates, "a 1.25 kg plate must not read 1.2")
        self.assertNotIn('String(format: "%.1f", value)', plates)

    def test_export_made_before_a_unit_switch_is_dropped(self):
        settings = SETTINGS.read_text()
        self.assertRegex(
            settings,
            r"\.onChange\(of: weightUnit\) \{ _, _ in\n(?:\s*//[^\n]*\n)*\s*exportURL = nil",
        )

    def test_csv_names_the_unit_in_its_columns(self):
        source = CSV_EXPORTER.read_text()
        self.assertIn("weight_\\(unit.short),reps,rpe,volume_\\(unit.short)", source)
        self.assertIn("unit: WeightUnit = .current", source)
        self.assertIn("let weightField = set.writtenLoad(in: unit)", source)


if __name__ == "__main__":
    unittest.main()
