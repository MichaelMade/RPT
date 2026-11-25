"""Relabeling earlier workouts as kilograms.

It is the one place RPT rewrites logged loads in bulk, for lifters who
typed kilograms while the app only knew pounds. These checks keep it from
ever running without the lifter asking, from touching a set that already
carries a unit, and from losing the way back.
"""

import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP = ROOT / "RPT"
EXERCISE_SET = APP / "Models" / "ExerciseSet.swift"
RELABELER = APP / "Managers" / "LoadHistoryRelabeler.swift"
POLICY = APP / "Utilities" / "KilogramRelabelPolicy.swift"
SETTINGS = APP / "Views" / "Settings" / "SettingsView.swift"
CONTENT_VIEW = APP / "App" / "ContentView.swift"
RELABELER_TESTS = ROOT / "RPTTests" / "LoadHistoryRelabelerTests.swift"
UI_TESTS = ROOT / "RPTUITests" / "KilogramRelabelUITests.swift"
UI_TEST_SUPPORT = APP / "App" / "UITestSupport.swift"
DATA_MANAGER = APP / "Managers" / "DataManager.swift"
APP_ENTRY = APP / "App" / "RPTTrainerApp.swift"
MIGRATION_TESTS = ROOT / "RPTTests" / "StoreMigrationTests.swift"
MIGRATION_DOC = ROOT / "docs" / "data-migrations.md"
SUPPORT = ROOT / "SUPPORT.md"


def _strip_comments(source):
    return re.sub(r"//[^\n]*", "", source)


def _app_sources():
    return {
        path.relative_to(ROOT).as_posix(): _strip_comments(path.read_text())
        for path in sorted(APP.rglob("*.swift"))
    }


def _block(source, opening):
    """The braces-balanced block that starts at `opening` (which ends in `{`)."""
    start = source.index(opening) + len(opening) - 1
    depth = 0
    for index in range(start, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start + 1:index]
    raise AssertionError(f"unbalanced braces after {opening!r}")


class RPTKilogramRelabelStaticTests(unittest.TestCase):
    def test_the_mark_is_an_optional_attribute_an_existing_store_can_absorb(self):
        self.assertIn("var relabeledFromPounds: Int? = nil", EXERCISE_SET.read_text())
        self.assertIn(
            "sets.allSatisfy { $0.relabeledFromPounds == nil }",
            MIGRATION_TESTS.read_text(),
            "the migration test must prove no set comes back from an old store already marked",
        )
        self.assertIn("ExerciseSet.relabeledFromPounds", MIGRATION_DOC.read_text())

    def test_only_the_set_and_the_relabeler_write_the_mark(self):
        writers = sorted(
            name
            for name, source in _app_sources().items()
            if re.search(r"\brelabeledFromPounds\s*=[^=]", source)
        )
        self.assertEqual(
            writers,
            ["RPT/Managers/LoadHistoryRelabeler.swift", "RPT/Models/ExerciseSet.swift"],
            "The mark is what makes an undo exact. Nothing else may set or clear it.",
        )

    def test_a_set_that_carries_a_unit_is_never_a_candidate(self):
        model = _strip_comments(EXERCISE_SET.read_text())
        candidate = _block(model, "var holdsUnlabeledWholePounds: Bool {")
        for condition in (
            "weight > 0",
            "Double(weight) <= WeightUnit.kilograms.maximumLoad",
            "loadValue == nil",
            "loadUnitRaw == nil",
            "relabeledFromPounds == nil",
        ):
            with self.subTest(condition=condition):
                self.assertIn(condition, candidate)
        self.assertNotIn("||", candidate, "every condition has to hold")

        relabel = _block(model, "func relabelAsKilograms() -> Bool {")
        self.assertLess(
            relabel.index("guard holdsUnlabeledWholePounds else { return false }"),
            relabel.index("setLoad(Double(original), in: .kilograms)"),
        )
        self.assertIn("guard loadUnit == .kilograms, loadValue == Double(original) else {", relabel)
        self.assertLess(
            relabel.index("setLoad(Double(original), in: .kilograms)"),
            relabel.index("relabeledFromPounds = original"),
            "the mark is only recorded once the load really was stored as that many kilograms",
        )

    def test_undo_only_puts_back_a_set_still_holding_the_relabeled_load(self):
        model = _strip_comments(EXERCISE_SET.read_text())
        undo = _block(
            model,
            "func undoKilogramRelabel(keepingLoadsEnteredAfter firstKilogramChoice: Date? = nil) -> Bool {",
        )
        self.assertIn("guard let original = relabeledFromPounds else { return false }", undo)
        self.assertIn("loadUnit == .kilograms", undo)
        self.assertIn("abs(loadValue - Double(original)) < 0.001", undo)
        self.assertIn("setWholePounds(original)", undo)
        self.assertLess(
            undo.index("relabeledFromPounds = nil"),
            undo.index("setWholePounds(original)"),
        )

        # A set logged since the lifter had kilograms is theirs: it is
        # ruled out before the load is touched.
        kept = "if let firstKilogramChoice, loadEnteredAt > firstKilogramChoice {\n            return false"
        self.assertIn(kept, undo)
        self.assertLess(undo.index(kept), undo.index("setWholePounds(original)"))

        relabeler = _strip_comments(RELABELER.read_text())
        undo_all = _block(relabeler, "func undoRelabel() -> Outcome {")
        self.assertIn("$0.undoKilogramRelabel(keepingLoadsEnteredAfter: firstChoice)", undo_all)

    def test_only_numbers_entered_before_the_lifter_had_kilograms_are_candidates(self):
        """A pound set logged today is stored exactly like a set from the
        pound-only days. The date it was entered is what tells them apart."""
        model = _strip_comments(EXERCISE_SET.read_text())
        candidate = _block(model, "func canBeRelabeledAsKilograms(enteredBy firstKilogramChoice: Date) -> Bool {")
        self.assertIn("holdsUnlabeledWholePounds && loadEnteredAt <= firstKilogramChoice", candidate)

        entered = _block(model, "var loadEnteredAt: Date {")
        self.assertIn("if completedAt != .distantPast {\n            return completedAt", entered)
        self.assertIn("return workout?.date ?? .distantPast", entered)

        relabeler = _strip_comments(RELABELER.read_text())
        fetch = _block(relabeler, "private func unlabeledSets(enteredBy firstChoice: Date) throws -> [ExerciseSet] {")
        self.assertIn(".filter { $0.canBeRelabeledAsKilograms(enteredBy: firstChoice) }", fetch)

        first_choice = _block(relabeler, "private func firstKilogramChoice(observing unit: WeightUnit) -> Date? {")
        self.assertLess(
            first_choice.index("if let recorded = defaults.object(forKey: key) as? Date {\n            return recorded"),
            first_choice.index("defaults.set(moment, forKey: key)"),
            "the first choice is recorded once and never moved",
        )
        self.assertIn("guard unit == .kilograms else {\n            return nil", first_choice)

        # The recorded moment decides what a relabel may touch. It must
        # never become a way of reading stored sets.
        readers = sorted(
            name
            for name, source in _app_sources().items()
            if "firstKilogramChoiceDefaultsKey" in source
        )
        self.assertEqual(
            readers,
            [
                "RPT/App/UITestSupport.swift",
                "RPT/Managers/LoadHistoryRelabeler.swift",
                "RPT/Utilities/KilogramRelabelPolicy.swift",
            ],
        )

    def test_the_fetch_never_narrows_or_caps_which_sets_are_rewritten(self):
        """The predicates are a second place that picks rows. They are
        pinned so neither can quietly leave part of a history behind."""
        relabeler = _strip_comments(RELABELER.read_text())
        self.assertEqual(
            re.findall(r"#Predicate<ExerciseSet> \{[^}]*\}", relabeler),
            [
                "#Predicate<ExerciseSet> { $0.loadUnitRaw == nil && $0.weight > 0 }",
                "#Predicate<ExerciseSet> { $0.relabeledFromPounds != nil }",
            ],
        )
        for cap in ("fetchLimit", ".prefix(", ".first(", "fetchOffset", ".dropFirst(", ".dropLast("):
            with self.subTest(cap=cap):
                self.assertNotIn(cap, relabeler)

    def test_the_rewrite_saves_once_and_puts_everything_back_on_failure(self):
        relabeler = _strip_comments(RELABELER.read_text())
        rewrite = _block(relabeler, "private func rewrite(_ sets: [ExerciseSet], using change: (ExerciseSet) -> Bool) -> Outcome {")
        self.assertEqual(
            rewrite.count("dataManager.saveChanges()"),
            2,
            "one save for whatever another screen left pending, one for the rewrite",
        )

        # A rollback discards everything unsaved in the shared context, so
        # pending work is saved before the first set is changed.
        pending = _block(rewrite, "if modelContext.hasChanges {")
        self.assertIn("try dataManager.saveChanges()", pending)
        self.assertIn("return .failed", pending)
        self.assertLess(rewrite.index("if modelContext.hasChanges {"), rewrite.index("for set in sets {"))

        failure = _block(rewrite[rewrite.index("for set in sets {"):], "} catch {")
        for step in (
            "modelContext.rollback()",
            "touched.forEach { $0.restore() }",
            "userSnapshots.forEach { $0.restore() }",
            "return .failed",
        ):
            with self.subTest(step=step):
                self.assertIn(step, failure)

        self.assertLess(
            rewrite.rindex("return .failed"),
            rewrite.index("KilogramRelabelPolicy.revisionDefaultsKey"),
            "the tabs are only told to rebuild after a save that went through",
        )
        self.assertLess(
            rewrite.index("let userSnapshots = corrections.keys.map(UserSnapshot.init)"),
            rewrite.index("user.correctLoadTotals("),
            "stored totals are captured before they are corrected",
        )

        relabel = _block(relabeler, "func relabelEarlierSetsAsKilograms() -> Outcome {")
        self.assertIn("if case .changed = outcome {\n            recordPromptAnswered()", relabel)

    def test_the_bulk_rewrite_runs_only_from_the_lifters_two_answers(self):
        callers = {
            name: source
            for name, source in _app_sources().items()
            if name != "RPT/Managers/LoadHistoryRelabeler.swift"
            and re.search(r"\.(relabelEarlierSetsAsKilograms|undoRelabel)\(", source)
        }
        self.assertEqual(sorted(callers), ["RPT/Views/Settings/SettingsView.swift"])

        settings = _strip_comments(SETTINGS.read_text())
        self.assertEqual(len(re.findall(r"\.relabelEarlierSetsAsKilograms\(", settings)), 1)
        self.assertEqual(len(re.findall(r"\.undoRelabel\(", settings)), 1)
        self.assertIn(
            "historyRelabeler.relabelEarlierSetsAsKilograms()",
            _block(settings, "private func relabelEarlierWorkouts() {"),
        )
        self.assertIn(
            "historyRelabeler.undoRelabel()",
            _block(settings, "private func undoEarlierWorkoutsRelabel() {"),
        )

        # Each is called exactly once, from the button that names it.
        self.assertEqual(len(re.findall(r"(?<!func )\brelabelEarlierWorkouts\(\)", settings)), 1)
        self.assertEqual(len(re.findall(r"(?<!func )\bundoEarlierWorkoutsRelabel\(\)", settings)), 1)
        self.assertIn(
            "relabelEarlierWorkouts()",
            _block(settings, "Button(KilogramRelabelPolicy.relabelAnswer) {"),
        )
        self.assertIn(
            "undoEarlierWorkoutsRelabel()",
            _block(settings, "Button(KilogramRelabelPolicy.undoAnswer, role: .destructive) {"),
        )

    def test_switching_units_asks_and_never_rewrites(self):
        settings = _strip_comments(SETTINGS.read_text())
        on_switch = _block(settings, ".onChange(of: weightUnit) { _, newUnit in")
        self.assertIn("relabelQuestion = historyRelabeler.question(afterSwitchingTo: newUnit)", on_switch)
        self.assertNotRegex(on_switch, r"relabelEarlier|undoEarlier|undoRelabel")

        on_appear = _block(settings, ".onAppear {")
        self.assertIn("refreshEarlierWorkoutsStatus()", on_appear)
        self.assertNotRegex(on_appear, r"relabelQuestion|relabelEarlier|undoEarlier")

    def test_the_question_has_both_answers_and_keeping_pounds_is_the_safe_one(self):
        settings = _strip_comments(SETTINGS.read_text())
        self.assertIn("KilogramRelabelPolicy.questionTitle,", settings)
        self.assertIn("Text(KilogramRelabelPolicy.questionMessage(for: preview))", settings)
        keep = _block(settings, "Button(KilogramRelabelPolicy.keepAnswer, role: .cancel) {")
        self.assertIn("historyRelabeler.recordPromptAnswered()", keep)
        self.assertNotRegex(keep, r"relabelEarlier|undoEarlier")

        policy = POLICY.read_text()
        self.assertIn('static let questionTitle = "Were your earlier workouts logged in kilograms?"', policy)
        self.assertIn("You can undo this here in Settings.", policy)

    def test_a_pound_lifter_is_never_asked(self):
        policy = _strip_comments(POLICY.read_text())
        status = _block(policy, "static func status(unit: WeightUnit, relabeledSetCount: Int, preview: Preview?) -> Status {")
        self.assertIn("guard unit == .kilograms, let preview, preview.setCount > 0 else {", status)

        question = _block(policy, "static func question(hasAnswered: Bool, status: Status) -> Preview? {")
        self.assertIn("guard !hasAnswered, case .readAsPounds(let preview) = status else {", question)

        settings = _strip_comments(SETTINGS.read_text())
        row = _block(settings, "private var earlierWorkoutsRow: some View {")
        self.assertIn("case .nothingToOffer:\n            EmptyView()", row)
        refresh = _block(settings, "private func refreshEarlierWorkoutsStatus() {")
        self.assertIn("earlierWorkoutsStatus = historyRelabeler.status(for: weightUnit)", refresh)

    def test_other_tabs_are_rebuilt_after_a_relabel(self):
        content = CONTENT_VIEW.read_text()
        self.assertIn(
            "@AppStorage(KilogramRelabelPolicy.revisionDefaultsKey) private var loadHistoryRevision = 0",
            content,
        )
        identity = _block(content, "private var loadIdentity: String {")
        self.assertIn("loadHistoryRevision", identity)
        self.assertEqual(content.count(".id(loadIdentity)"), 4)

        settings = _strip_comments(SETTINGS.read_text())
        finish = _block(settings, "private func finishEarlierWorkoutsChange() {")
        self.assertIn("exportURL = nil", finish, "an export made before the change holds the old loads")

    def test_tests_keep_out_of_the_apps_own_defaults(self):
        for path in (RELABELER_TESTS, MIGRATION_TESTS):
            source = path.read_text()
            with self.subTest(file=path.name):
                self.assertIn("UserDefaults(suiteName:", source)
                constructions = source.split("LoadHistoryRelabeler(")[1:]
                self.assertTrue(constructions)
                for following in constructions:
                    self.assertIn(
                        "defaults: defaults",
                        following[:200],
                        "The tab shell watches a key in the standard defaults; a test writing it "
                        "would rebuild the host app's screens.",
                    )

    def test_the_question_is_worded_from_what_is_stored(self):
        policy = POLICY.read_text()
        message = _block(policy, "static func questionMessage(for preview: Preview) -> String {")
        self.assertIn('"RPT stored \\(preview.setCount) earlier sets as pounds."', message)
        # It is shown to lifters with every kind of history, so it must not
        # assume one.
        for assumption in ("until now", "your last", "all along"):
            with self.subTest(assumption=assumption):
                self.assertNotIn(assumption, policy)

    def test_the_settings_path_is_driven_end_to_end_by_a_ui_test(self):
        ui_test = UI_TESTS.read_text()
        for step in (
            '"--uiTestPoundHistory"',
            'app.buttons["kg"]',
            'app.alerts["Were your earlier workouts logged in kilograms?"]',
            'question.buttons["They Were Kilograms"].tap()',
            'app.buttons["earlierWorkoutsUndoRow"]',
            'undoQuestion.buttons["Undo Relabel"].tap()',
            'app.buttons["earlierWorkoutsRelabelRow"]',
            'question.buttons["They Were Pounds"].tap()',
            '"950 kg"',
            '"431 kg"',
        ):
            with self.subTest(step=step):
                self.assertIn(step, ui_test)

        settings = SETTINGS.read_text()
        self.assertIn('.accessibilityIdentifier("earlierWorkoutsRelabelRow")', settings)
        self.assertIn('.accessibilityIdentifier("earlierWorkoutsUndoRow")', settings)

    def test_the_ui_test_hook_exists_only_in_debug_builds(self):
        support = UI_TEST_SUPPORT.read_text()
        code = "\n".join(
            line for line in support.splitlines() if line.strip() and not line.strip().startswith("//")
        )
        self.assertTrue(code.startswith("#if DEBUG"), "the whole file is compiled out of a release build")
        self.assertTrue(code.rstrip().endswith("#endif"))
        self.assertEqual(code.count("#if"), 1)

        for path in (DATA_MANAGER, APP_ENTRY):
            source = path.read_text()
            with self.subTest(file=path.name):
                uses = [match.start() for match in re.finditer(r"\bUITestSupport\.", source)]
                self.assertTrue(uses)
                for position in uses:
                    opened = source.rfind("#if DEBUG", 0, position)
                    closed = source.rfind("#endif", 0, position)
                    self.assertGreater(opened, closed, "every use sits inside #if DEBUG")

        # The store it swaps in never touches the lifter's file.
        factory = DATA_MANAGER.read_text().split("if UITestSupport.wantsPoundHistory {")[1].split("#endif")[0]
        self.assertIn("ModelConfiguration(isStoredInMemoryOnly: true, allowsSave: true)", factory)

    def test_support_page_tells_a_kilogram_lifter_what_to_do(self):
        support = SUPPORT.read_text()
        self.assertIn("Were your earlier workouts logged in kilograms?", support)
        self.assertIn("Undo", support)
        self.assertIn(
            "set **Weight unit** to **kg**",
            support,
            "the Earlier workouts row only shows while the unit is kilograms, and the page has to say so",
        )

        doc = MIGRATION_DOC.read_text()
        for enforcer in ("tests/test_rpt_kilogram_relabel_static.py", "LoadHistoryRelabelerTests", "KilogramRelabelUITests"):
            with self.subTest(enforcer=enforcer):
                self.assertIn(enforcer, doc)


if __name__ == "__main__":
    unittest.main()
