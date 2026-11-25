"""Relabeling earlier workouts as kilograms.

It is the one place RPT rewrites logged loads in bulk, for lifters who
typed kilograms while the app only knew pounds. These checks keep it from
ever running without the lifter asking, from touching a set it should not,
and from losing the way back.

Statements are compared with whitespace collapsed, so reflowing a line does
not fail a check. Changing what a line does will.
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
VIEW_MODEL = APP / "ViewModels" / "ActiveWorkoutViewModel.swift"
UI_TEST_SUPPORT = APP / "App" / "UITestSupport.swift"
DATA_MANAGER = APP / "Managers" / "DataManager.swift"
APP_ENTRY = APP / "App" / "RPTTrainerApp.swift"
RELABELER_TESTS = ROOT / "RPTTests" / "LoadHistoryRelabelerTests.swift"
MIGRATION_TESTS = ROOT / "RPTTests" / "StoreMigrationTests.swift"
UI_TESTS = ROOT / "RPTUITests" / "KilogramRelabelUITests.swift"
MIGRATION_DOC = ROOT / "docs" / "data-migrations.md"
SUPPORT = ROOT / "SUPPORT.md"

HOOK_CONDITION = "#if DEBUG && targetEnvironment(simulator)"


def _strip_comments(source):
    return re.sub(r"//[^\n]*", "", source)


def _flat(text):
    """`text` with every run of whitespace collapsed to one space."""
    return " ".join(text.split())


def _code(path):
    return _strip_comments(path.read_text())


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
    def assertStatement(self, statement, block, message=None):
        self.assertIn(_flat(statement), _flat(block), message)

    def assertBefore(self, first, second, block, message=None):
        flat = _flat(block)
        self.assertIn(_flat(first), flat)
        self.assertIn(_flat(second), flat)
        self.assertLess(flat.index(_flat(first)), flat.index(_flat(second)), message)

    # MARK: - The mark

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

    # MARK: - Which sets

    def test_a_set_that_carries_a_unit_is_never_a_candidate(self):
        model = _code(EXERCISE_SET)
        bare = _block(model, "var holdsUnlabeledWholePounds: Bool {")
        for condition in (
            "weight > 0",
            "Double(weight) <= WeightUnit.kilograms.maximumLoad",
            "loadValue == nil",
            "loadUnitRaw == nil",
            "relabeledFromPounds == nil",
        ):
            with self.subTest(condition=condition):
                self.assertStatement(condition, bare)
        self.assertNotIn("||", bare, "every condition has to hold")

        relabel = _block(model, "func relabelAsKilograms() -> Bool {")
        self.assertBefore(
            "guard holdsUnlabeledWholePounds else { return false }",
            "setLoad(Double(original), in: .kilograms)",
            relabel,
        )
        self.assertStatement("guard loadUnit == .kilograms, loadValue == Double(original) else {", relabel)
        self.assertBefore(
            "setLoad(Double(original), in: .kilograms)",
            "relabeledFromPounds = original",
            relabel,
            "the mark is only recorded once the load really was stored as that many kilograms",
        )

    def test_only_numbers_entered_before_the_first_kilogram_log_are_candidates(self):
        """A pound set logged today is stored exactly like a set from the
        pound-only days. What tells them apart is whether the lifter had
        already logged a set in kilograms."""
        model = _code(EXERCISE_SET)
        candidate = _block(
            model,
            "func canBeRelabeledAsKilograms(beforeFirstKilogramLog firstKilogramLog: Date?) -> Bool {",
        )
        self.assertStatement("guard holdsUnlabeledWholePounds else { return false }", candidate)
        self.assertStatement("guard let firstKilogramLog else { return true }", candidate)
        self.assertStatement("return loadEnteredAt < firstKilogramLog", candidate)

        entered = _block(model, "var loadEnteredAt: Date {")
        self.assertStatement("if completedAt != .distantPast { return completedAt }", entered)
        self.assertStatement("return workout?.date ?? .distantPast", entered)

        evidence = _block(model, "var isLoggedInKilograms: Bool {")
        self.assertStatement(
            "completedAt != .distantPast && loadUnit == .kilograms && relabeledFromPounds == nil",
            evidence,
            "planned rows and relabeled history are not evidence of training in kilograms",
        )

        relabeler = _code(RELABELER)
        candidates = _block(relabeler, "private func unlabeledSets() throws -> [ExerciseSet] {")
        self.assertStatement("let firstLog = try firstKilogramLog()", candidates)
        self.assertStatement(
            ".filter { $0.canBeRelabeledAsKilograms(beforeFirstKilogramLog: firstLog) }", candidates
        )

        first_log = _block(relabeler, "private func firstKilogramLog() throws -> Date? {")
        self.assertStatement("sortBy: [SortDescriptor(\\.completedAt)]", first_log, "the earliest, not the latest")
        self.assertNotIn("order:", first_log)
        self.assertStatement(".first(where: \\.isLoggedInKilograms)?.completedAt", first_log)

    def test_the_line_is_drawn_by_the_store_and_never_by_a_recorded_moment(self):
        """Recording 'the first time the unit was kg' shut a lifter out for
        good after one look at the picker. The evidence is the sets."""
        relabeler = _code(RELABELER)
        self.assertNotIn("Date()", relabeler)
        self.assertNotRegex(relabeler, r"defaults\.object\(")
        for name, source in _app_sources().items():
            with self.subTest(file=name):
                self.assertNotRegex(source, r"kilogramsFirstChosenAt|firstKilogramChoice")

    def test_the_fetches_never_narrow_or_cap_which_sets_are_rewritten(self):
        """The predicates are a second place that picks rows. They are
        pinned so none can quietly leave part of a history behind."""
        relabeler = _code(RELABELER)
        predicates = [_flat(match) for match in re.findall(r"#Predicate<ExerciseSet> \{[^}]*\}", relabeler)]
        self.assertEqual(
            predicates,
            [
                "#Predicate<ExerciseSet> { $0.loadUnitRaw == nil && $0.weight > 0 }",
                "#Predicate<ExerciseSet> { $0.loadUnitRaw == kilograms && $0.relabeledFromPounds == nil"
                " && $0.completedAt > neverLogged }",
                "#Predicate<ExerciseSet> { $0.relabeledFromPounds != nil }",
            ],
        )

        # Only the lookup of the single earliest kilogram set may stop
        # early. The two fetches that decide what is rewritten may not.
        rewritten = (
            _block(relabeler, "private func unlabeledSets() throws -> [ExerciseSet] {")
            + _block(relabeler, "private var relabeledSetsDescriptor: FetchDescriptor<ExerciseSet> {")
            + _block(relabeler, "private func relabeledSets() throws -> [ExerciseSet] {")
        )
        for cap in ("fetchLimit", ".prefix(", ".first", "fetchOffset", ".dropFirst(", ".dropLast(", ".suffix("):
            with self.subTest(cap=cap):
                self.assertNotIn(cap, rewritten)

    # MARK: - Undo, and sets logged since

    def test_undo_only_puts_back_a_set_still_holding_the_relabeled_load(self):
        model = _code(EXERCISE_SET)
        undo = _block(model, "func undoKilogramRelabel() -> Bool {")
        self.assertStatement("guard let original = relabeledFromPounds else { return false }", undo)
        self.assertStatement("loadUnit == .kilograms", undo)
        self.assertStatement("abs(loadValue - Double(original)) < 0.001", undo)
        self.assertBefore("relabeledFromPounds = nil", "setWholePounds(original)", undo)

    def test_logging_a_relabeled_set_takes_it_out_of_the_relabel(self):
        """A planned set relabeled to 100 kg, then performed and checked
        off, is the lifter's own entry. An undo must not make it 100 lb."""
        model = _code(EXERCISE_SET)
        logged = _block(model, "func markLogged(at date: Date) {")
        self.assertStatement("completedAt = date", logged)
        self.assertStatement("relabeledFromPounds = nil", logged)

        restore = _block(model, "func restoreLogState(_ state: LogState) {")
        self.assertStatement("completedAt = state.completedAt", restore)
        self.assertStatement("relabeledFromPounds = state.relabeledFromPounds", restore)

        toggle = _block(_code(VIEW_MODEL), "func toggleSetLogged(_ set: ExerciseSet) throws -> SetLogResult {")
        self.assertStatement("set.markLogged(at: Date())", toggle)
        self.assertBefore("let originalLogState = set.logState", "set.markLogged(at: Date())", toggle)
        self.assertStatement("set.restoreLogState(originalLogState)", _block(toggle, "} catch {"))
        self.assertNotRegex(toggle, r"completedAt\s*=\s*Date\(\)", "a log has to go through markLogged")

    # MARK: - The rewrite

    def test_the_rewrite_puts_everything_back_on_failure(self):
        relabeler = _code(RELABELER)
        rewrite = _block(
            relabeler,
            "private func rewrite(_ sets: [ExerciseSet], using change: (ExerciseSet) -> Bool) -> Outcome {",
        )
        self.assertEqual(
            rewrite.count("dataManager.saveChanges()"),
            2,
            "one save for whatever another screen left pending, one for the rewrite",
        )

        # A rollback discards everything unsaved in the shared context, so
        # pending work is saved before the first set is changed.
        pending = _block(rewrite, "if modelContext.hasChanges {")
        self.assertStatement("try dataManager.saveChanges()", pending)
        self.assertStatement("return .failed", pending)
        self.assertNotIn("rollback", pending, "a refused start must not discard the other screen's work")
        self.assertBefore("if modelContext.hasChanges {", "for set in sets {", rewrite)

        failure = _block(rewrite[rewrite.index("for set in sets {"):], "} catch {")
        for step in (
            "modelContext.rollback()",
            "touched.forEach { $0.restore() }",
            "userSnapshots.forEach { $0.restore() }",
            "return .failed",
        ):
            with self.subTest(step=step):
                self.assertStatement(step, failure)

        self.assertLess(
            rewrite.rindex("return .failed"),
            rewrite.index("KilogramRelabelPolicy.revisionDefaultsKey"),
            "the tabs are only told to rebuild after a save that went through",
        )
        self.assertBefore(
            "let userSnapshots = corrections.keys.map(UserSnapshot.init)",
            "user.correctLoadTotals(",
            rewrite,
            "stored totals are captured before they are corrected",
        )

        relabel = _block(relabeler, "func relabelEarlierSetsAsKilograms() -> Outcome {")
        self.assertStatement("if case .changed = outcome { recordPromptAnswered() }", relabel)

    # MARK: - Only when the lifter asks

    def test_the_bulk_rewrite_runs_only_from_the_lifters_two_answers(self):
        callers = {
            name: source
            for name, source in _app_sources().items()
            if name != "RPT/Managers/LoadHistoryRelabeler.swift"
            and re.search(r"\.(relabelEarlierSetsAsKilograms|undoRelabel)\(", source)
        }
        self.assertEqual(sorted(callers), ["RPT/Views/Settings/SettingsView.swift"])

        settings = _code(SETTINGS)
        self.assertEqual(len(re.findall(r"\.relabelEarlierSetsAsKilograms\(", settings)), 1)
        self.assertEqual(len(re.findall(r"\.undoRelabel\(", settings)), 1)
        self.assertStatement(
            "historyRelabeler.relabelEarlierSetsAsKilograms()",
            _block(settings, "private func relabelEarlierWorkouts() {"),
        )
        self.assertStatement(
            "historyRelabeler.undoRelabel()",
            _block(settings, "private func undoEarlierWorkoutsRelabel() {"),
        )

        # Each is called exactly once, from the button that names it.
        self.assertEqual(len(re.findall(r"(?<!func )\brelabelEarlierWorkouts\(\)", settings)), 1)
        self.assertEqual(len(re.findall(r"(?<!func )\bundoEarlierWorkoutsRelabel\(\)", settings)), 1)
        self.assertStatement(
            "relabelEarlierWorkouts()",
            _block(settings, "Button(KilogramRelabelPolicy.relabelAnswer) {"),
        )
        self.assertStatement(
            "undoEarlierWorkoutsRelabel()",
            _block(settings, "Button(KilogramRelabelPolicy.undoAnswer, role: .destructive) {"),
        )

    def test_switching_units_asks_and_never_rewrites(self):
        settings = _code(SETTINGS)
        on_switch = _block(settings, ".onChange(of: weightUnit) { _, newUnit in")
        self.assertStatement(
            "relabelQuestion = historyRelabeler.question(afterSwitchingTo: newUnit)", on_switch
        )
        self.assertNotRegex(on_switch, r"relabelEarlier|undoEarlier|undoRelabel")

        on_appear = _block(settings, ".onAppear {")
        self.assertStatement("refreshEarlierWorkoutsStatus()", on_appear)
        self.assertNotRegex(on_appear, r"relabelQuestion|relabelEarlier|undoEarlier")

    def test_the_question_has_both_answers_and_keeping_pounds_is_the_safe_one(self):
        settings = _code(SETTINGS)
        self.assertIn("KilogramRelabelPolicy.questionTitle,", settings)
        self.assertIn("Text(KilogramRelabelPolicy.questionMessage(for: preview))", settings)
        keep = _block(settings, "Button(KilogramRelabelPolicy.keepAnswer, role: .cancel) {")
        self.assertStatement("historyRelabeler.recordPromptAnswered()", keep)
        self.assertNotRegex(keep, r"relabelEarlier|undoEarlier")

        policy = POLICY.read_text()
        self.assertIn('static let questionTitle = "Were your earlier workouts logged in kilograms?"', policy)
        self.assertIn("You can undo this here in Settings.", policy)

    def test_the_question_is_worded_from_what_is_stored(self):
        policy = POLICY.read_text()
        message = _block(policy, "static func questionMessage(for preview: Preview) -> String {")
        self.assertIn('"RPT stored \\(preview.setCount) earlier sets as pounds."', message)
        # It is shown to lifters with every kind of history, so it must not
        # assume one.
        for assumption in ("until now", "your last", "all along"):
            with self.subTest(assumption=assumption):
                self.assertNotIn(assumption, policy)

    def test_a_pound_lifter_is_never_asked(self):
        policy = _code(POLICY)
        status = _block(
            policy,
            "static func status(unit: WeightUnit, relabeledSetCount: Int, preview: Preview?) -> Status {",
        )
        self.assertStatement("guard unit == .kilograms, let preview, preview.setCount > 0 else {", status)

        question = _block(policy, "static func question(hasAnswered: Bool, status: Status) -> Preview? {")
        self.assertStatement("guard !hasAnswered, case .readAsPounds(let preview) = status else {", question)

        settings = _code(SETTINGS)
        row = _block(settings, "private var earlierWorkoutsRow: some View {")
        self.assertStatement("case .nothingToOffer: EmptyView()", row)
        refresh = _block(settings, "private func refreshEarlierWorkoutsStatus() {")
        self.assertStatement("earlierWorkoutsStatus = historyRelabeler.status(for: weightUnit)", refresh)

    # MARK: - The other screens

    def test_other_tabs_are_rebuilt_after_a_relabel(self):
        content = CONTENT_VIEW.read_text()
        self.assertIn(
            "@AppStorage(KilogramRelabelPolicy.revisionDefaultsKey) private var loadHistoryRevision = 0",
            content,
        )
        identity = _block(content, "private var loadIdentity: String {")
        self.assertIn("loadHistoryRevision", identity)
        self.assertEqual(content.count(".id(loadIdentity)"), 4)

        settings = _code(SETTINGS)
        finish = _block(settings, "private func finishEarlierWorkoutsChange() {")
        self.assertStatement("exportURL = nil", finish, "an export made before the change holds the old loads")

    # MARK: - Tests and the test hook

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

    def test_the_settings_path_is_driven_end_to_end_by_a_ui_test(self):
        ui_test = UI_TESTS.read_text()
        for touched in (
            '"--uiTestPoundHistory"',
            '"kg"',
            '"lb"',
            '"Were your earlier workouts logged in kilograms?"',
            '"They Were Kilograms"',
            '"They Were Pounds"',
            '"Undo the kilogram relabel?"',
            '"Undo Relabel"',
            '"earlierWorkoutsRelabelRow"',
            '"earlierWorkoutsUndoRow"',
            '"950 kg"',
            '"431 kg"',
        ):
            with self.subTest(touched=touched):
                self.assertIn(touched, ui_test)

        settings = SETTINGS.read_text()
        self.assertIn('.accessibilityIdentifier("earlierWorkoutsRelabelRow")', settings)
        self.assertIn('.accessibilityIdentifier("earlierWorkoutsUndoRow")', settings)

    def test_the_ui_test_hook_exists_only_in_simulator_debug_builds(self):
        """The hook resets the unit choice. It must not exist in a release
        build, or in any build that can run on a lifter's phone."""
        support = [line.strip() for line in _code(UI_TEST_SUPPORT).splitlines() if line.strip()]
        self.assertEqual(support[0], HOOK_CONDITION, "the whole file is compiled out everywhere else")
        self.assertEqual(support[-1], "#endif")

        for path in (DATA_MANAGER, APP_ENTRY):
            lines = _code(path).splitlines()
            uses = [index for index, line in enumerate(lines) if re.search(r"\bUITestSupport\.", line)]
            with self.subTest(file=path.name):
                self.assertTrue(uses)
                for index in uses:
                    directives = [
                        line.strip() for line in lines[:index] if line.strip().startswith(("#if", "#else", "#endif"))
                    ]
                    self.assertTrue(directives)
                    self.assertEqual(
                        directives[-1],
                        HOOK_CONDITION,
                        "every use sits directly inside the simulator-debug condition, with no #else",
                    )

        # The store it swaps in never touches the lifter's file.
        factory = _code(DATA_MANAGER).split("if UITestSupport.wantsPoundHistory {")[1].split("#endif")[0]
        self.assertStatement("ModelConfiguration(isStoredInMemoryOnly: true, allowsSave: true)", factory)

    # MARK: - Docs

    def test_support_page_tells_a_kilogram_lifter_what_to_do(self):
        support = SUPPORT.read_text()
        self.assertIn("Were your earlier workouts logged in kilograms?", support)
        self.assertIn("Undo", support)
        self.assertIn(
            "set **Weight unit** to **kg**",
            support,
            "the relabel is only offered while the unit is kilograms, and the page has to say so",
        )

        doc = MIGRATION_DOC.read_text()
        for enforcer in (
            "tests/test_rpt_kilogram_relabel_static.py",
            "LoadHistoryRelabelerTests",
            "KilogramRelabelUITests",
        ):
            with self.subTest(enforcer=enforcer):
                self.assertIn(enforcer, doc)


if __name__ == "__main__":
    unittest.main()
