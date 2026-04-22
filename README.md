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
