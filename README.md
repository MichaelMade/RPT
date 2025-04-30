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
- **Swift**: 5.9 or later

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

## Contributing

Contributions are welcome! Please:

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/YourFeature`
3. Commit your changes: `git commit -m "Add YourFeature"`
4. Push to your branch: `git push origin feature/YourFeature`
5. Open a pull request detailing your changes.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

