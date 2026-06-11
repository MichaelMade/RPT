import XCTest
@testable import RPT

@MainActor
final class ExerciseLibraryViewModelSearchTests: XCTestCase {
    func testSearchPrompt_teachesInstructionCuesAlongsideBodyRegionsAndMovementTypes() {
        XCTAssertEqual(
            ExerciseLibraryViewModel.searchPrompt,
            "Search exercises, muscles, instruction cues, body regions, or movement types"
        )
    }

    func testNoMatchesDescription_teachesInstructionCuesAlongsideBodyRegionsAndMovementTypes() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.searchText = "legs"

        XCTAssertEqual(
            viewModel.noMatchesDescription(),
            "No exercise matches “legs”. Search by name, muscle group, instruction cue, body region, or movement type."
        )
    }

    func testNoMatchesDescription_usesFilterFriendlyCopyWhenSearchIsBlank() {
        let viewModel = ExerciseLibraryViewModel()

        XCTAssertEqual(
            viewModel.noMatchesDescription(),
            "No exercise matches your current search or filters. Search by name, muscle group, instruction cue, body region, or movement type."
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
