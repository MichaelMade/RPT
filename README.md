# RPT — Reverse Pyramid Training

A focused iOS strength-training app built around **reverse pyramid training**: hit your heaviest set first while you're fresh, then drop the weight and chase reps on every back-off set.

Built with SwiftUI, SwiftData, and Swift Charts. iOS 18+, iPhone and iPad. All data stays on device.

## Features

- **Template search now understands richer coaching queries** — template results can now match instruction cues from the exercise library and split multi-term intent like `bench chest`, alongside category/body-region queries such as `bodyweight`, `isolation`, `upper body`, `legs`, or `core`, and the Templates screen teaches those cues directly in the search prompt and no-match helper.

### Training
- **Live workout logging** — fast steppers, tap-to-type set editing, RPE tracking, and per-exercise completion check-offs.
- **RPT back-off suggestions** — log your top set and the app calculates every back-off weight from your configured percentage drops (default −10% / −15%), always anchored to the top set.
- **Warm-up ramp generator** — one tap builds a low-fatigue ramp (bar × 10 → 40% × 5 → 60% × 3 → 80% × 1) toward your top set.
- **Progression coaching** — double-progression targets on every exercise: hit the top of your rep range and RPT tells you to load more next session.
- **Rest timer** — progress-ring countdown with ±15s adjustments, haptic and sound cues, and optional auto-start when you check off a set.
- **Follow-up workouts** — re-run any completed session at +2.5% load with one tap.

### Planning
- **Templates** — reusable routines with per-exercise set counts and rep ranges, duplicate/edit/start in one tap, and automatic weight pre-fill from your last session.
- **Exercise library** — seeded with common barbell/bodyweight movements, fully searchable (names, muscles, categories, instructions), and extensible with custom exercises.
- **Plate calculator** — visual bar-loading math for lb/kg with multiple bar types.
- **RPT calculator** — plan a session from any top-set weight.

### Insight
- **Stats dashboard** — lifetime workouts, day streak, total volume, average duration.
- **Consistency heatmap** — GitHub-style 16-week training calendar.
- **Weekly volume chart** — 12-week trend of completed working-set volume.
- **Muscle balance** — working sets per muscle group over the last 4 weeks.
- **Personal records** — best estimated 1RM (Epley) per exercise, plus per-exercise e1RM trend charts.
- **CSV export** — every logged set, shareable from Stats or Settings.

## Architecture

```
RPT/
├── App/            Entry point + root tab shell
├── DesignSystem/   Theme (brand palette/gradients), shared components, heatmap
├── Models/         SwiftData models: Workout, Exercise, ExerciseSet, WorkoutTemplate, User, UserSettings
├── Managers/       Data layer: DataManager (container), Workout/Exercise/Template/Settings/User managers
├── ViewModels/     Screen state: WorkoutSession coordinator + per-screen view models
├── Utilities/      Pure logic: OneRepMax, WarmupPlanner, ProgressionAdvisor, WorkoutCSVExporter
└── Views/          SwiftUI screens by feature: Home, Workout, Templates, Exercises, Stats, Settings
```

- **Single in-progress workout** is coordinated by `WorkoutSession`; starting a template or follow-up while a draft is open always routes through an explicit save-or-discard handoff.
- **Persistence** uses a single SwiftData container with rollback-on-failed-save in every mutation path.
- **Pure training math** (e1RM, warm-up ramps, progression, plate math, RPT drops) lives in dependency-free utilities covered by unit tests in `RPTTests/`.

## Testing

`RPTTests/` covers manager logic, persistence/rollback behavior, model invariants, RPT back-off math (including the top-set anchoring regression test), warm-up planning, progression suggestions, plate math, CSV export, and name normalization. Run with **⌘U** in Xcode.

## Privacy

No accounts, no analytics, no network calls. Training data never leaves the device except through the export you trigger yourself. See `Privacy Policy`.
