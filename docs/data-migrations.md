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
`UserSettings.autoStartRestTimerEnabled`, `UserSettings.weeklyWorkoutGoal`,
`Exercise.isArchived`, `ExerciseSet.loadValue` / `loadUnitRaw`,
`ExerciseSet.relabeledFromPounds` and `ExerciseSet.loggedUnitRaw` reached
existing users.

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

Units are the worked example. `ExerciseSet.weight` shipped as whole pounds
and still is: a set logged in pounds is stored exactly as it always was. A
set logged in kilograms keeps its exact value in the new optional
`loadValue` with its unit in `loadUnitRaw`, and `weight` holds the nearest
whole pound. Nothing that existed was retyped, and no existing row is
rewritten when the lifter changes unit.

## Rewriting stored values

A change that rewrites rows a lifter already logged needs the same care as
a schema change, because there is no copy to go back to. There is one such
place: `LoadHistoryRelabeler`, for lifters who typed kilograms while RPT
only knew pounds. It is the pattern to follow.

- It runs only when the lifter asks, never at launch or on a unit switch.
- A row says for itself what was done to it. Each relabeled set keeps the
  whole-pound number it held in `ExerciseSet.relabeledFromPounds`, saved in
  the same transaction as the new load, so an undo is exact and cannot be
  separated from the data it describes. A flag in `UserDefaults` that
  changed how rows are read would be lost on a reset and would silently
  reinterpret every row.
- It only touches rows it can identify from the store itself: a bare
  whole number with no unit, entered before the lifter first logged a set
  with RPT set to kilograms. A set that carries kilograms is never a
  candidate. Neither is a pound set logged after that first kilogram
  session, which is stored the same way as an old one and told apart by
  its date.
- "Trained in kilograms" is recorded where it happens: each log stamps
  the unit in use on the set (`ExerciseSet.loggedUnitRaw`). The unit a
  load is stored in is not evidence, because a row planned while the
  picker read kg can be checked off after the lifter has gone back to
  pounds.
- That line is read from the store each time, never kept in a setting.
  An earlier version recorded the first time the unit picker read kg. One
  look at the picker then shut a lifter out for good, and a wrong device
  clock or a lost setting moved the line. Evidence that is in the rows
  cannot go missing or disagree with them. The cost is that deleting the
  workout that holds the first kilogram log moves the line later, so a
  pound session before the next one is offered again. It is only an
  offer: nothing is rewritten unless the lifter says yes.
- Whatever another screen left unsaved is saved first, then the rewrite
  is one save. If that fails, the rollback discards only the rewrite and
  every row and stored total is put back.
- Logging a relabeled set takes it out of the relabel
  (`ExerciseSet.markLogged(at:)`): a planned set performed at the kilogram
  load it showed is the lifter's own entry.
- The undo leaves alone any row edited or logged since.

## What enforces this

- `tests/test_rpt_store_migration_static.py` holds the stored shape as of
  RPT 2.2.1 and fails if a shipped property is renamed, retyped or removed,
  if a new property is neither optional nor defaulted, if a stored enum
  loses a case, or if a migration plan appears.
- `RPTTests/StoreMigrationTests.swift` writes a real on-disk store using a
  frozen copy of the 2.2.1 models, reopens it with the current models, and
  checks that workouts, sets, templates, settings and the user profile all
  come back intact and that new attributes take their defaults.

- `tests/test_rpt_kilogram_relabel_static.py`, `LoadHistoryRelabelerTests`
  and `KilogramRelabelTests` hold the rules above for the one bulk rewrite:
  which rows it may touch, that it runs only from the lifter's answer, and
  that an undo is exact. `StoreMigrationTests` relabels and restores a
  store written by the shipped models, and `KilogramRelabelUITests` drives
  the Settings path end to end.

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
