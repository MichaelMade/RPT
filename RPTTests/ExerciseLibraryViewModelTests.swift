import XCTest
@testable import RPT

@MainActor
final class ExerciseLibraryViewModelTests: XCTestCase {
    func testNormalizedSearchQuery_trimsAndCollapsesWhitespace() {
        XCTAssertEqual(
            ExerciseLibraryViewModel.normalizedSearchQuery("  Bench\n\n   Press  "),
            "Bench Press",
            "Exercise search should ignore leading/trailing whitespace and collapse internal whitespace runs"
        )

        XCTAssertEqual(
            ExerciseLibraryViewModel.normalizedSearchQuery(" \n\t "),
            "",
            "Whitespace-only exercise searches should behave like an empty query instead of hiding the whole library"
        )
    }

    func testFetchExercises_ignoresWhitespaceOnlySearchText() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "")
        ]
        viewModel.searchText = "   \n  "

        let results = viewModel.fetchExercises()

        XCTAssertEqual(
            results.map(\.name),
            ["Bench Press", "Barbell Row"],
            "Whitespace-only search text should not filter out every exercise"
        )
    }

    func testFetchExercises_matchesCollapsedSearchWhitespace() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Incline Dumbbell Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.shoulders], instructions: "")
        ]
        viewModel.searchText = "Bench   Press"

        let results = viewModel.fetchExercises()

        XCTAssertEqual(
            results.map(\.name),
            ["Bench Press"],
            "Collapsed search whitespace should still match normalized exercise names"
        )
    }

    func testFilteredResultsSummary_onlyAppearsForActiveQueries() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: ""),
            Exercise(name: "Pull-Up", category: .bodyweight, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "")
        ]

        XCTAssertNil(
            viewModel.filteredResultsSummary(filteredCount: 3),
            "The library should not show a redundant summary when nothing is being filtered"
        )

        viewModel.searchText = "Bench"

        XCTAssertEqual(
            viewModel.filteredResultsSummary(filteredCount: 1),
            "Showing 1 of 3 exercises",
            "Active exercise searches should surface a quick filtered-result summary"
        )
    }
}
