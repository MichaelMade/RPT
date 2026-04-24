# RPT

Reverse Pyramid Training (RPT) iOS App

RPT is a SwiftUI-based iOS application designed to help athletes plan and track strength workouts using the Reverse Pyramid Training methodology. The app leverages SwiftData for local persistence and follows a modular MVVM architecture.

## Features

- **RPT Templates**: Create and customize Reverse Pyramid workout templates with top set weight, target reps, and percentage drops.
- **Workout Generation**: Automatically generate your workout sets based on RPT logic.
- **Performance Tracking**: Log your completed sets, weights, and reps to track progress over time.
- **Exercise Management**: Tag exercises by muscle group and filter your library.
- **Dark & Light Mode**: Full support for both iOS appearances.

## Requirements

- **iOS**: 17.0 or later
- **Xcode**: 15.0 or later
- **Swift**: 6 or later

## Installation

1. **Clone** the repository:
   ```bash
   git clone https://github.com/MichaelMade/RPT.git
   cd RPT
   ```
2. **Open** `RPT.xcodeproj` in Xcode.
3. **Build & Run** on a simulator or device.

## Architecture & Folder Structure

```plaintext
RPT/
├── App/
│   ├── RPTTrainerApp.swift      # App entry point
│   └── ContentView.swift        # Root TabView
├── Managers/
│   ├── DataManager.swift
│   ├── ExerciseManager.swift
│   └── WorkoutManager.swift     # Core RPT logic
├── Models/
│   ├── Exercise.swift           # SwiftData entity
│   ├── Workout.swift            # SwiftData entity
│   ├── ExerciseSet.swift        # SwiftData entity
│   └── WorkoutTemplate.swift    # SwiftData entity
├── ViewModels/
│   └── ...                      # MVVM view models
├── Views/
│   └── ...                      # SwiftUI views
└── Utilities/
    └── ...                      # Shared utilities and extensions
```

## Usage

1. **Create** a new RPT template in the Templates tab.
2. **Configure** your top set weight, target reps, and percentage drops.
3. **Start** a workout session to see your generated sets.
4. **Log** your performance and review history in the History tab.

## Recent Improvements

- Fixed lifetime stats/PB integrity in `User.updateStats(with:)`: workout volume accumulation and `personalBests` updates now use only completed working sets (`!isWarmup`, `weight > 0`, `reps > 0`, `completedAt != .distantPast`), preventing warmups or incomplete placeholder sets from inflating all-time totals or setting premature PRs; added regression coverage in `UserModelTests`.
- Fixed template workout autofill quality in `ActiveWorkoutViewModel.populateWithPreviousWeights`: previous-set carry-forward now uses only completed working sets (`!isWarmup`, `weight > 0`, `reps > 0`, `completedAt != .distantPast`) when choosing source history. This prevents warmup or placeholder sets from being copied into new template sessions; added regression coverage in `ActiveWorkoutViewModelTests`.
- Fixed Stats data accuracy by counting only completed working sets in `StatsViewModel` for muscle-group distribution and PR detection (`weight > 0`, `reps > 0`, non-warmup, and `completedAt != .distantPast`). This prevents placeholder/planned sets from inflating training-balance charts or surfacing premature PRs.
- Fixed template-start set integrity in `TemplateManager.createWorkoutFromTemplate`: generated template sets now initialize as incomplete (`.distantPast`) unless both weight and reps are already non-zero, preventing unstarted planned sets from carrying live timestamps into stats/progress flows. Added regression coverage in `TemplateManagerTests`.
- Fixed workout model set-creation completion integrity by making `Workout.addSet` initialize sets as incomplete (`completedAt = .distantPast`) unless both weight and reps are greater than zero. This aligns model-level behavior with manager/view-model paths and prevents direct model usage from incorrectly treating placeholder sets (for example `185 x 0`) as completed work. Added regression coverage in `WorkoutManagerTests`.
- Fixed Active Workout set-add completion integrity so newly inserted starter sets and auto-suggested follow-up sets are initialized as incomplete (`completedAt = .distantPast`) even when prefilled with suggested reps/weight, preventing fresh placeholders from being treated as already logged work. Added regression coverage in `ActiveWorkoutViewModelTests`.
- Fixed working-set count integrity by updating `Workout.workingSetsCount` to include only completed non-warmup sets (`weight > 0` and `reps > 0`), so placeholders like `185 x 0` and warmup entries no longer inflate workout detail and summary set totals. Added regression coverage in `WorkoutManagerTests`.
- Improved template save UX and data integrity by preventing duplicate template names across case/diacritic/whitespace variants (for example `Pull Dây` vs `pull day`) in `TemplateManager.createTemplate` and `TemplateManager.updateTemplate`, sanitizing saved template names (trim/collapse whitespace, max length 80), and showing a clear duplicate-name alert in `TemplateEditView` instead of silently dismissing on failed save. Added regression coverage in `ErrorHandlingTests`.
- Fixed set creation completion-state integrity in `WorkoutManager.addSet`: new sets now only get a completion timestamp when both weight and reps are greater than zero, so partial placeholders like `185 x 0` correctly start as incomplete (`.distantPast`) instead of looking finished. Added regression coverage in `WorkoutManagerTests`.
- Prevented duplicate exercise creation/renaming across accent/case/whitespace variants by enforcing normalized name collision checks in `ExerciseManager.addExercise` and `ExerciseManager.updateExercise` (for example `Café Row` vs `cafe row`), and added user-facing duplicate-name alerts in Add/Edit Exercise flows instead of silently dismissing. Added regression coverage in `ErrorHandlingTests`.
- Fixed set completion-state consistency when reps are cleared: `ActiveWorkoutViewModel.updateSet` and `WorkoutManager.updateSet` now treat a set as incomplete unless both weight and reps are greater than zero, so changing reps to `0` correctly resets `completedAt` to `.distantPast` instead of leaving a stale completed timestamp. Added regression coverage in `ActiveWorkoutViewModelTests` and `WorkoutManagerTests`.
- Fixed workout progress-bar safety and accuracy in `WorkoutProgressView` by sanitizing invalid counts and clamping computed progress to `0...1`, so corrupted state (negative counts or completed > total) cannot render negative-width bars or overflow the progress track. Added regression coverage in `WorkoutProgressViewTests`.
- Hardened exercise-name data integrity and lookup resilience in `ExerciseManager`: add/update paths now sanitize names (trim/collapse whitespace, cap length to 80, fail-safe default for blank input), and `fetchExercise(withName:)` now falls back to case/diacritic-insensitive matching to avoid false misses from keyboard/autocorrect variants. Added regression tests in `ErrorHandlingTests`.
- Fixed Active Workout set-state integrity by aligning `ActiveWorkoutViewModel.updateSet` with `WorkoutManager` completion semantics: clearing a set back to `0` now resets `completedAt` to `.distantPast` (incomplete), and RPE validation now enforces the documented `1...10` range. Added regression tests in `ActiveWorkoutViewModelTests` for both behaviors.

- Hardened settings integrity for rest timer recovery by normalizing `UserSettings.restTimerDuration` to safe bounds (`1...3600`) at model init and startup sanitation in `SettingsManager`, so corrupted/legacy persisted values cannot create impossible timer durations in the UI. Added regression tests in `ErrorHandlingTests` for low/high out-of-range inputs.

- Fixed a discard-state recency mismatch in `ContentView` so Home/Templates bindings and workout sheet restoration now use workout date vs discard timestamp (fail-open when discard metadata is incomplete), matching `HomeViewModel` behavior. This prevents a stale discard flag from suppressing resume/sheet restoration when a newer incomplete workout exists.
- Fixed a Home resume fail-closed edge case for legacy/corrupted discard state: when `wasAnyWorkoutDiscarded` is true but `discardTimestamp` is missing, `HomeViewModel.shouldResumeIncompleteWorkout` now fails open and allows resume instead of hiding `Continue Workout`. This prevents valid incomplete workouts from getting stranded by incomplete discard metadata; updated regression coverage in `HomeViewModelTests`.
- Fixed set completion-state integrity in `WorkoutManager` so newly added placeholder sets (`addExercise`) are now initialized as incomplete (`completedAt = .distantPast`), sanitized zero-weight sets no longer get fresh completion timestamps, and clearing a previously completed set back to `0` resets it to incomplete. This keeps completion ordering/history signals aligned with actual logged work; added regression tests in `WorkoutManagerTests`.
- Hardened RPT drop normalization end-to-end so persisted or programmatic values are now sanitized to deterministic ascending unique drops with top-set `0.0` always first (for example unsorted/duplicated inputs normalize to `[0.0, 0.10, 0.20, 0.30]`), and `SettingsManager.updateRPTPercentageDrops` now rejects non-monotonic drop arrays that would make later sets heavier than earlier back-off sets; added regression tests in `ErrorHandlingTests`.
- Hardened persisted RPT drop recovery in `UserSettings.defaultRPTPercentageDrops` so corrupted/legacy values now fail safe to defaults (`[0.0, 0.10, 0.15]`) and automatically prepend a missing top-set `0.0` entry when needed, preventing blank/invalid drop arrays from degrading Settings examples or workout generation; added regression tests in `ErrorHandlingTests`.
- Fixed Home primary action consistency with discard-state recency logic by routing button state and resume selection through `HomeViewModel` (`resumableWorkout` / `canContinueWorkout`) instead of the raw `wasAnyWorkoutDiscarded` flag. This prevents stale discard flags from hiding `Continue Workout` when a newer resumable session exists; added regression tests in `HomeViewModelTests`.
- Fixed a Home resume edge case caused by coarse timestamp precision: `HomeViewModel.shouldResumeIncompleteWorkout` now treats workouts created at the exact discard timestamp as resumable (`>=` instead of `>`), so valid sessions are not incorrectly hidden when persisted dates share the same second; added regression coverage in `HomeViewModelTests`.
- Fixed a Home resume-state regression where discarding any workout could hide `Continue Workout` for later incomplete sessions. `HomeViewModel.loadRecentWorkouts()` now resumes an incomplete workout only when it is newer than the discard timestamp, preventing stale discarded sessions from resurfacing without suppressing legitimately resumable workouts; added regression coverage in `HomeViewModelTests`.
- Fixed Stats headline volume formatting to match Home behavior: `StatsView.formattedTotal(_:)` now clamps corrupted negative/non-finite input, rounds before thousand-abbreviation checks, avoids truncating sub-thousand decimals (for example `123.6 -> 124 lb`), and correctly promotes near-threshold values (for example `999.95 -> 1k lb`); added regression tests in `StatsViewFormattingTests`.
- Hardened lifetime stats integrity in `User.updateStats(with:)` by clamping corrupted workout volume inputs (negative or non-finite) to zero before accumulating `totalVolume`, so bad legacy set data can no longer decrease a user’s all-time volume; added regression coverage in `UserModelTests`.
- Fixed a Settings UX copy bug where the RPT example sentence showed duplicated units (`lb lb`); the view now renders the example string once so users see clean output like `205 → 180 lb`.
- Hardened `SettingsManager.formatWeight` (Int and Double overloads) against corrupted inputs by clamping negative and non-finite values to zero before formatting, preventing impossible values like `-45 lb` or `inf lb` from surfacing in settings/UI output; added regression tests in `FormattingTests`.
- Fixed Home primary action UX so users now see `Continue Workout` whenever an incomplete workout exists, even if the parent binding is temporarily nil (for example after tab/navigation state resets). The button now consistently resumes `activeWorkoutBinding ?? viewModel.currentWorkout` and only shows `Start New Workout` when no resumable session exists.
- Hardened follow-up workout generation against corrupted set data in `Workout.createFollowUpWorkout`: non-finite/negative percentage increases now sanitize safely, and generated follow-up sets clamp invalid negative weight/reps and out-of-range RPE values; added regression tests in `UserModelTests`.
- Fixed Home total-volume rounding for sub-thousand values by rounding to the nearest whole number instead of truncating (for example `123.6` now shows `124`), and ensured values like `999.6` consistently promote to `1k`; added regression tests in `HomeViewModelTests`.
- Hardened `Workout.complete()` against corrupted persisted durations by sanitizing any existing non-finite or negative duration before completion logic runs, ensuring completed workouts never retain impossible negative/invalid time values; added regression tests for negative and `.infinity` duration inputs.
- Polished workout summary UX by making exercise names deterministic and readable: `Workout.generateFormattedSummary()` now sorts exercise names alphabetically and shows `Exercises: None` when a workout has no logged sets; added regression coverage in `WorkoutManagerTests`.
- Fixed Home total-volume formatting near the thousand boundary by rounding before abbreviation logic, so values like `999.95` now correctly display as `1k` instead of truncating to `999`; added regression test coverage in `HomeViewModelTests`.
- Polished settings UX for edge cases by improving `SettingsManager.calculateRPTExample`: when no back-off sets are configured (drops = `[0.0]`), the app now shows `Top set only` instead of an empty/awkward ` lb` string, with regression test coverage.
- Hardened workout creation naming by sanitizing `WorkoutManager.createWorkout` input: names are now trimmed, blank names fall back to `"Workout"`, and excessively long names are capped to 80 characters, with regression tests for each case.
- Hardened `Workout.complete()` duration capture to clamp future-dated/corrupted start times to `0` seconds instead of persisting negative durations when a workout is completed, with regression tests for future and past start-date behavior.
- Hardened `Workout.formattedTotalVolume()` to clamp corrupted negative or non-finite totals to `0 lb`, preventing bad persisted set data from showing impossible negative volume in workout rows/details.
- Polished Home/Stats volume formatting near the thousand boundary by rounding first and then applying abbreviation logic, so values like `999.95` now display consistently as `1k lb` instead of an awkward `1000.0 lb`.
- Hardened RPT set generation by sanitizing `calculateRPTWeights` inputs: non-finite or negative top-set weights now clamp to `0`, and corrupted percentage drops are clamped into `0...1` so generated set weights can never go negative.
- Hardened `WorkoutManager` set persistence by sanitizing set inputs on add/update: negative weight/reps now clamp to `0`, and out-of-range RPE values are discarded, preventing corrupted values from polluting workout logs and stats.
- Hardened workout save behavior by sanitizing auto-computed duration so future-dated/corrupted workout start times clamp to `0` seconds instead of producing negative durations in persisted stats.
- Hardened completed-workout stats aggregation to clamp corrupted negative or non-finite volume/duration values to zero, preventing bad persisted data from inflating or inverting Home/Stats metrics.
- Fixed workout statistics integrity by excluding in-progress workouts from count, volume, and average-duration calculations, so Home/Stats summaries reflect only completed sessions.
- Hardened `WorkoutManager.roundToNearest5(_:)` against corrupted non-finite and negative inputs by clamping to `0` before rounding, preventing crash-prone numeric edge cases.
- Hardened `WorkoutManager.formatWeight(_:)` to safely clamp corrupted negative or non-finite values to `0.0 lb`, matching the app's defensive volume-formatting behavior.

## Contributing

Contributions are welcome! Please:

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/YourFeature`
3. Commit your changes: `git commit -m "Add YourFeature"`
4. Push to your branch: `git push origin feature/YourFeature`
5. Open a pull request detailing your changes.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
