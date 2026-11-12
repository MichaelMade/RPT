# Changing the data model

RPT stores everything a lifter has logged in one on-device SwiftData store.
There is no server copy and no account, so a store that fails to open after
an update is unrecoverable data loss for that user. This page is the rule
set for changing a `@Model` class without causing that.

## How existing stores are migrated today

RPT does not declare a `SchemaMigrationPlan` or any `VersionedSchema`. Each
launch opens the store with the current models (`DataManager.makeSchema()`),
and SwiftData's automatic lightweight migration carries an older store
forward. That is how `ExerciseSet.orderIndex`,
`UserSettings.autoStartRestTimerEnabled`, `UserSettings.weeklyWorkoutGoal`
and `Exercise.isArchived` reached existing users.

Lightweight migration only handles additive changes. Anything else makes
`ModelContainer` throw at launch, and the app shows the storage-unavailable
screen instead of the user's history.

## Why there is no migration plan

A migration plan identifies a store by matching it to one of the plan's
versioned schemas. Stores in the field were written by several shipped
versions, none of which declared a schema version. A plan would have to
reproduce every one of those shapes exactly; any store it does not
recognize fails to open with an unknown model version error. The shapes of
the oldest shipped builds were never recorded, so that cannot be done
safely from here.

If a change ever truly needs a custom migration, the path is:

1. Freeze the current shape as `SchemaV1` and ship that release with a plan
   that has no stages, so stores in the field gain a known version.
2. Wait until that release has reached the installed base.
3. Add `SchemaV2` and the custom stage in a later release.

Extend `StoreMigrationTests` for each step before shipping it.

## Rules

Allowed without a plan:

- Add a stored property that is optional, or has an inline default
  (`var isArchived: Bool = false`). A default assigned only in `init` does
  not count: migration never calls `init`.
- Add a new `@Model` class, registered in `DataManager.makeSchema()`.
- Add a case to a stored enum.
- Add an optional field to a stored `Codable` struct.
- Add, change or remove computed properties, methods and initializers.

Not allowed without a plan:

- Rename a stored property or a model class. Lightweight migration reads a
  rename as delete plus add, and every stored value is dropped.
- Change a stored property's type, including optional to non-optional.
- Remove a stored property that still holds data users care about.
- Add a non-optional stored property with no inline default.
- Remove or rename a case of a stored enum (`ExerciseCategory`,
  `MuscleGroup`, `DarkModePreference`). Raw values are what is on disk.
- Add a non-optional field to `TemplateExercise` or `TemplateRepRange`.
- Add a uniqueness constraint to a property that already has duplicates in
  the field.

When a value needs a new representation, add a new property beside the old
one and keep reading the old one. Never repurpose a shipped property.

## What enforces this

- `tests/test_rpt_store_migration_static.py` holds the stored shape as of
  RPT 2.2.1 and fails if a shipped property is renamed, retyped or removed,
  if a new property is neither optional nor defaulted, if a stored enum
  loses a case, or if a migration plan appears.
- `RPTTests/StoreMigrationTests.swift` writes a real on-disk store using a
  frozen copy of the 2.2.1 models, reopens it with the current models, and
  checks that workouts, sets, templates, settings and the user profile all
  come back intact and that new attributes take their defaults.

Neither list of shipped shapes is edited to make a failing check pass. When
a release ships with new stored properties, add a new frozen schema
(`ShippedSchema_x_y_z`) and a test that migrates from it, and keep the
older ones.

## Checklist for a model change

1. Confirm the change is in the allowed list above.
2. Run `python3 -m unittest discover -s tests -p 'test_*.py'`.
3. Add an assertion to
   `testAttributesAddedSinceTheShippedVersionTakeTheirDefaults` for the new
   attribute.
4. Run the unit tests on a simulator (`StoreMigrationTests`).
5. Before release, install the current App Store build on a device, log a
   workout, then install the new build over it and confirm the history is
   there.
