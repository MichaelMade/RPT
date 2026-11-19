"""Guards the on-disk shape of the SwiftData store.

RPT has no SchemaMigrationPlan; existing stores are carried forward by
SwiftData's automatic lightweight migration. That only works while model
changes are additive. These checks fail a change that an existing user's
store could not absorb. See docs/data-migrations.md.
"""

import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
MODELS = ROOT / "RPT" / "Models"
DATA_MANAGER = ROOT / "RPT" / "Managers" / "DataManager.swift"
MIGRATION_TESTS = ROOT / "RPTTests" / "StoreMigrationTests.swift"
MIGRATION_DOC = ROOT / "docs" / "data-migrations.md"

# Stored properties of every model as shipped in RPT 2.2.1 (build 5).
# Frozen: do not edit this to make a failing check pass.
SHIPPED_MODELS = {
    "Exercise": {
        "name": "String",
        "category": "ExerciseCategory",
        "primaryMuscleGroups": "[MuscleGroup]",
        "secondaryMuscleGroups": "[MuscleGroup]",
        "instructions": "String",
        "isCustom": "Bool",
        "sets": "[ExerciseSet]",
    },
    "ExerciseSet": {
        "weight": "Int",
        "reps": "Int",
        "completedAt": "Date",
        "isWarmup": "Bool",
        "rpe": "Int?",
        "notes": "String",
        "orderIndex": "Int",
        "exercise": "Exercise?",
        "workout": "Workout?",
    },
    "Workout": {
        "date": "Date",
        "name": "String",
        "notes": "String",
        "duration": "TimeInterval",
        "isCompleted": "Bool",
        "startedFromTemplate": "String?",
        "startedFromTemplateID": "String?",
        "sets": "[ExerciseSet]",
        "user": "User?",
    },
    "WorkoutTemplate": {
        "id": "String",
        "name": "String",
        "exercises": "[TemplateExercise]",
        "notes": "String",
    },
    "UserSettings": {
        "restTimerDuration": "Int",
        "defaultRPTPercentageDropsString": "String",
        "showRPE": "Bool",
        "darkModePreference": "DarkModePreference",
        "autoStartRestTimerEnabled": "Bool",
        "weeklyWorkoutGoal": "Int",
    },
    "User": {
        "id": "UUID",
        "username": "String",
        "email": "String",
        "dateJoined": "Date",
        "height": "Double?",
        "weight": "Double?",
        "birthdate": "Date?",
        "profileImageName": "String?",
        "settings": "UserSettings?",
        "lastActive": "Date",
        "workoutStreak": "Int",
        "totalWorkouts": "Int",
        "totalVolume": "Double",
        "personalBests": "[String: Int]",
        "workouts": "[Workout]",
    },
}

# Codable values stored inside models. They are part of the stored shape too.
SHIPPED_STRUCTS = {
    "TemplateExercise": {
        "id": None,  # declared as `var id = UUID()`
        "exerciseName": "String",
        "suggestedSets": "Int",
        "repRanges": "[TemplateRepRange]",
        "notes": "String",
    },
    "TemplateRepRange": {
        "setNumber": "Int",
        "minReps": "Int",
        "maxReps": "Int",
        "percentageOfFirstSet": "Double?",
    },
}

SHIPPED_ENUM_CASES = {
    "ExerciseCategory": ["compound", "isolation", "bodyweight", "cardio", "other"],
    "MuscleGroup": [
        "chest", "back", "shoulders", "biceps", "triceps", "quadriceps",
        "hamstrings", "glutes", "calves", "forearms", "abs", "obliques",
        "traps", "lowerBack", "other",
    ],
    "DarkModePreference": ["light", "dark", "system"],
}

STORED_PROPERTY = re.compile(
    r"^\s*(?:@Attribute\([^)]*\)\s*)?var\s+(?P<name>\w+)"
    r"(?:\s*:\s*(?P<type>[^={]+?))?"
    r"\s*(?:=\s*(?P<default>[^{]+?))?\s*$"
)


def _strip_comment(line):
    return re.sub(r"\s*//.*$", "", line)


def _body(source, header_pattern):
    """Returns the text between the braces that follow `header_pattern`."""
    match = re.search(header_pattern, source)
    if match is None:
        return None
    start = source.index("{", match.end() - 1)
    depth = 0
    for index in range(start, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start + 1:index]
    raise AssertionError(f"unbalanced braces after {header_pattern}")


def _stored_properties(body):
    """Stored `var` declarations at the top level of a type body.

    Returns {name: (declared_type or None, has_inline_default)}.
    Computed properties (a `{` on the declaration line) and statics are
    skipped, as is anything nested inside a method or initializer.
    """
    properties = {}
    depth = 0
    for raw_line in body.splitlines():
        line = _strip_comment(raw_line)
        if depth == 0 and not re.match(r"^\s*(static|private static|nonisolated)\b", line):
            match = STORED_PROPERTY.match(line)
            if match:
                declared_type = match.group("type")
                properties[match.group("name")] = (
                    declared_type.strip() if declared_type else None,
                    match.group("default") is not None,
                )
        depth += line.count("{") - line.count("}")
    return properties


def _all_model_sources():
    return {path: path.read_text() for path in sorted(MODELS.glob("*.swift"))}


def _model_bodies():
    bodies = {}
    for source in _all_model_sources().values():
        for match in re.finditer(r"@Model\s+(?:final\s+)?class\s+(\w+)", source):
            name = match.group(1)
            bodies[name] = _body(source, r"@Model\s+(?:final\s+)?class\s+" + name + r"\b[^{]*{")
    return bodies


def _type_body(kind, name):
    for source in _all_model_sources().values():
        body = _body(source, kind + r"\s+" + name + r"\b[^{]*{")
        if body is not None:
            return body
    raise AssertionError(f"{kind} {name} not found under RPT/Models")


class RPTStoreMigrationStaticTests(unittest.TestCase):
    HELP = " See docs/data-migrations.md."

    def test_every_shipped_model_still_exists(self):
        self.assertEqual(
            sorted(set(SHIPPED_MODELS) - set(_model_bodies())),
            [],
            "A shipped @Model class was removed or renamed; its rows would be dropped." + self.HELP,
        )

    def test_shipped_properties_keep_their_name_and_type(self):
        bodies = _model_bodies()
        for model, shipped in SHIPPED_MODELS.items():
            current = _stored_properties(bodies[model])
            for name, shipped_type in shipped.items():
                with self.subTest(model=model, property=name):
                    self.assertIn(
                        name,
                        current,
                        f"{model}.{name} shipped and is gone. A rename reads as delete plus add, "
                        "which loses every stored value." + self.HELP,
                    )
                    self.assertEqual(
                        current[name][0],
                        shipped_type,
                        f"{model}.{name} changed type. Lightweight migration cannot convert it." + self.HELP,
                    )

    def test_properties_added_since_shipping_are_optional_or_defaulted(self):
        for model, body in _model_bodies().items():
            shipped = SHIPPED_MODELS.get(model, {})
            for name, (declared_type, has_default) in _stored_properties(body).items():
                if name in shipped:
                    continue
                with self.subTest(model=model, property=name):
                    is_optional = bool(declared_type) and declared_type.endswith("?")
                    self.assertTrue(
                        is_optional or has_default,
                        f"{model}.{name} is new, non-optional, and has no inline default, so an "
                        "existing store has no value to give it and will fail to open." + self.HELP,
                    )

    def test_stored_structs_only_grow_by_optional_fields(self):
        for struct, shipped in SHIPPED_STRUCTS.items():
            current = _stored_properties(_type_body("struct", struct))
            for name, shipped_type in shipped.items():
                with self.subTest(struct=struct, property=name):
                    self.assertIn(name, current, f"{struct}.{name} shipped and is gone." + self.HELP)
                    self.assertEqual(current[name][0], shipped_type, f"{struct}.{name} changed type." + self.HELP)
            for name, (declared_type, _) in current.items():
                if name in shipped:
                    continue
                with self.subTest(struct=struct, property=name):
                    self.assertTrue(
                        bool(declared_type) and declared_type.endswith("?"),
                        f"{struct}.{name} is new and not optional. Values saved before it existed "
                        "have no such field, and a default does not help a synthesized decoder." + self.HELP,
                    )

    def test_stored_enums_keep_every_shipped_case(self):
        for enum, shipped_cases in SHIPPED_ENUM_CASES.items():
            body = _type_body("enum", enum)
            current_cases = re.findall(r"^\s*case\s+(\w+)\s*$", body, flags=re.MULTILINE)
            with self.subTest(enum=enum):
                self.assertRegex(
                    "\n".join(_all_model_sources().values()),
                    r"enum\s+" + enum + r"\s*:\s*String\b",
                    f"{enum} must stay String-backed; its raw values are what is stored.",
                )
                self.assertEqual(
                    [case for case in shipped_cases if case not in current_cases],
                    [],
                    f"{enum} lost a case that existing rows hold. They would no longer decode." + self.HELP,
                )

    def test_schema_registers_every_model_and_declares_no_migration_plan(self):
        data_manager = DATA_MANAGER.read_text()
        schema_body = _body(data_manager, r"static func makeSchema\(\) -> Schema\s*{")
        self.assertIsNotNone(schema_body, "DataManager.makeSchema() is what the migration tests open the store with")
        for model in _model_bodies():
            with self.subTest(model=model):
                self.assertIn(f"{model}.self", schema_body)

        app_sources = "\n".join(path.read_text() for path in (ROOT / "RPT").rglob("*.swift"))
        self.assertNotRegex(
            app_sources,
            r":\s*(SchemaMigrationPlan|VersionedSchema)\b",
            "Stores in the field carry no schema version, so a migration plan must name every "
            "shipped shape or the store will not open. Read docs/data-migrations.md and extend "
            "StoreMigrationTests before introducing one.",
        )

    def test_migration_regression_test_and_doc_stay_in_place(self):
        self.assertTrue(MIGRATION_DOC.exists())
        migration_tests = MIGRATION_TESTS.read_text()
        self.assertIn("enum ShippedSchema_2_2_1", migration_tests)
        self.assertIn("DataManager.makeSchema()", migration_tests)
        self.assertIn("docs/data-migrations.md", DATA_MANAGER.read_text())

        frozen = _body(migration_tests, r"enum ShippedSchema_2_2_1\s*{")
        for model, shipped in SHIPPED_MODELS.items():
            frozen_properties = _stored_properties(_body(frozen, r"final class " + model + r"\b[^{]*{"))
            with self.subTest(model=model):
                self.assertEqual(
                    sorted(frozen_properties),
                    sorted(shipped),
                    "The frozen copy in StoreMigrationTests must stay the shipped 2.2.1 shape.",
                )


if __name__ == "__main__":
    unittest.main()
