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

    func testFetchExercises_matchesLegacyWhitespaceAndDiacriticVariants() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Café   Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: ""),
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "")
        ]
        viewModel.searchText = " cafe row "

        let results = viewModel.fetchExercises()

        XCTAssertEqual(
            results.map(\.name),
            ["Café   Row"],
            "Exercise search should stay resilient to legacy whitespace and diacritic variants in stored names"
        )
    }

    func testSearchMatchPriority_prefersExactThenPrefixThenWordPrefixThenSubstring() {
        let exact = ExerciseLibraryViewModel.searchMatchPriority(
            exerciseName: "Row",
            normalizedQuery: ExerciseLibraryViewModel.normalizedSearchLookupKey("row")
        )
        let prefix = ExerciseLibraryViewModel.searchMatchPriority(
            exerciseName: "Row Machine",
            normalizedQuery: ExerciseLibraryViewModel.normalizedSearchLookupKey("row")
        )
        let wordPrefix = ExerciseLibraryViewModel.searchMatchPriority(
            exerciseName: "Barbell Row",
            normalizedQuery: ExerciseLibraryViewModel.normalizedSearchLookupKey("row")
        )
        let substring = ExerciseLibraryViewModel.searchMatchPriority(
            exerciseName: "Front Squat Rowing Drill",
            normalizedQuery: ExerciseLibraryViewModel.normalizedSearchLookupKey("row")
        )

        XCTAssertEqual(exact, 0)
        XCTAssertEqual(prefix, 1)
        XCTAssertEqual(wordPrefix, 2)
        XCTAssertEqual(substring, 3)
    }

    func testFetchExercises_prioritizesMoreRelevantSearchMatches() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Front Squat Rowing Drill", category: .compound, primaryMuscleGroups: [.legs], secondaryMuscleGroups: [.back], instructions: ""),
            Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: ""),
            Exercise(name: "Row Machine", category: .other, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: ""),
            Exercise(name: "Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "")
        ]
        viewModel.searchText = "row"

        let results = viewModel.fetchExercises()

        XCTAssertEqual(
            results.map(\.name),
            ["Row", "Row Machine", "Barbell Row", "Front Squat Rowing Drill"],
            "Exercise search should rank exact and prefix matches ahead of weaker substring matches"
        )
    }

    func testFetchExercises_appliesCategoryAndMuscleGroupFiltersTogether() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Incline Dumbbell Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.shoulders], instructions: ""),
            Exercise(name: "Pull-Up", category: .bodyweight, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "")
        ]
        viewModel.selectedCategory = .compound
        viewModel.selectedMuscleGroup = .shoulders

        let results = viewModel.fetchExercises()

        XCTAssertEqual(
            results.map(\.name),
            ["Incline Dumbbell Press"],
            "Exercise filters should support narrowing by both category and muscle group in the selector flows"
        )
    }

    func testClearFilters_resetsCategoryAndMuscleGroupSelections() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.selectedCategory = .compound
        viewModel.selectedMuscleGroup = .back

        viewModel.clearFilters()

        XCTAssertNil(viewModel.selectedCategory)
        XCTAssertNil(viewModel.selectedMuscleGroup)
        XCTAssertFalse(viewModel.hasActiveFilters)
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

        viewModel.searchText = ""
        viewModel.selectedMuscleGroup = .back

        XCTAssertEqual(
            viewModel.filteredResultsSummary(filteredCount: 2),
            "Showing 2 of 3 exercises",
            "Active exercise filters should also surface the filtered-result summary even without a text search"
        )
    }
}
