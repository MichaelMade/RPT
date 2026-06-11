import XCTest
@testable import RPT

@MainActor
final class ExerciseLibraryViewModelSearchTests: XCTestCase {
    func testSearchPrompt_teachesCustomMovesAlongsidePushPullSplitsAndInstructionCues() {
        XCTAssertEqual(
            ExerciseLibraryViewModel.searchPrompt,
            "Search exercises, custom moves, muscles, push/pull splits, instruction cues, body regions, or movement types"
        )
    }

    func testNoMatchesDescription_teachesCustomExercisesAlongsidePushPullSplitsAndInstructionCues() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.searchText = "legs"

        XCTAssertEqual(
            viewModel.noMatchesDescription(),
            "No exercise matches “legs”. Search by name, custom exercise, muscle group, push/pull split, instruction cue, body region, or movement type."
        )
    }

    func testNoMatchesDescription_usesFilterFriendlyCopyWhenSearchIsBlank() {
        let viewModel = ExerciseLibraryViewModel()

        XCTAssertEqual(
            viewModel.noMatchesDescription(),
            "No exercise matches your current search or filters. Search by name, custom exercise, muscle group, push/pull split, instruction cue, body region, or movement type."
        )
    }

    func testFilteredExercises_matchesCombinedTermsAcrossNameAndMuscleMetadata() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(
                name: "Bench Press",
                category: .compound,
                primaryMuscleGroups: [.chest],
                secondaryMuscleGroups: [.triceps]
            ),
            Exercise(
                name: "Back Squat",
                category: .compound,
                primaryMuscleGroups: [.quadriceps],
                secondaryMuscleGroups: [.glutes]
            )
        ]

        viewModel.searchText = "bench chest"
        XCTAssertEqual(viewModel.filteredExercises.map(\.displayName), ["Bench Press"])

        viewModel.searchText = "legs squat"
        XCTAssertEqual(viewModel.filteredExercises.map(\.displayName), ["Back Squat"])
    }

    func testFilteredExercises_matchesPushAndPullAliases() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(
                name: "Bench Press",
                category: .compound,
                primaryMuscleGroups: [.chest],
                secondaryMuscleGroups: [.triceps]
            ),
            Exercise(
                name: "Barbell Row",
                category: .compound,
                primaryMuscleGroups: [.back],
                secondaryMuscleGroups: [.biceps]
            )
        ]

        viewModel.searchText = "push"
        XCTAssertEqual(viewModel.filteredExercises.map(\.displayName), ["Bench Press"])

        viewModel.searchText = "pull"
        XCTAssertEqual(viewModel.filteredExercises.map(\.displayName), ["Barbell Row"])
    }

    func testFilteredExercises_matchesCustomExerciseAliases() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(
                name: "Custom Cable Fly",
                category: .isolation,
                primaryMuscleGroups: [.chest],
                isCustom: true
            ),
            Exercise(
                name: "Bench Press",
                category: .compound,
                primaryMuscleGroups: [.chest]
            )
        ]

        viewModel.searchText = "custom"
        XCTAssertEqual(viewModel.filteredExercises.map(\.displayName), ["Custom Cable Fly"])

        viewModel.searchText = "my exercise"
        XCTAssertEqual(viewModel.filteredExercises.map(\.displayName), ["Custom Cable Fly"])
    }

    func testFilteredExercises_matchesInstructionCueTerms() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(
                name: "Barbell Row",
                category: .compound,
                primaryMuscleGroups: [.back],
                instructions: "Drive elbows back and keep the bar close."
            )
        ]

        viewModel.searchText = "drive elbows back"
        XCTAssertEqual(viewModel.filteredExercises.map(\.displayName), ["Barbell Row"])
    }
}
