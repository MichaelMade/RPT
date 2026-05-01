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

    func testSearchMatchPriority_prefersNameMatchesBeforeAliasMatches() {
        let exact = ExerciseLibraryViewModel.searchMatchPriority(
            exercise: Exercise(name: "Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: ""),
            normalizedQuery: ExerciseLibraryViewModel.normalizedSearchLookupKey("row")
        )
        let prefix = ExerciseLibraryViewModel.searchMatchPriority(
            exercise: Exercise(name: "Row Machine", category: .other, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: ""),
            normalizedQuery: ExerciseLibraryViewModel.normalizedSearchLookupKey("row")
        )
        let tokenPrefix = ExerciseLibraryViewModel.searchMatchPriority(
            exercise: Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: ""),
            normalizedQuery: ExerciseLibraryViewModel.normalizedSearchLookupKey("row")
        )
        let substring = ExerciseLibraryViewModel.searchMatchPriority(
            exercise: Exercise(name: "Front Squat Rowing Drill", category: .compound, primaryMuscleGroups: [.quadriceps], secondaryMuscleGroups: [.back], instructions: ""),
            normalizedQuery: ExerciseLibraryViewModel.normalizedSearchLookupKey("row")
        )
        let aliasExact = ExerciseLibraryViewModel.searchMatchPriority(
            exercise: Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            normalizedQuery: ExerciseLibraryViewModel.normalizedSearchLookupKey("chest")
        )

        XCTAssertEqual(exact, 0)
        XCTAssertEqual(prefix, 1)
        XCTAssertEqual(tokenPrefix, 2)
        XCTAssertEqual(substring, 3)
        XCTAssertEqual(aliasExact, 4)
    }

    func testFetchExercises_prioritizesMoreRelevantSearchMatches() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Front Squat Rowing Drill", category: .compound, primaryMuscleGroups: [.quadriceps], secondaryMuscleGroups: [.back], instructions: ""),
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

    func testFetchExercises_matchesReorderedMultiWordQueriesByTokenPrefix() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Incline Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.shoulders], instructions: ""),
            Exercise(name: "Bench Dip", category: .bodyweight, primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [.chest], instructions: ""),
            Exercise(name: "Press Around", category: .other, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.shoulders], instructions: "")
        ]
        viewModel.searchText = "press bench"

        let results = viewModel.fetchExercises()

        XCTAssertEqual(
            results.map(\.name),
            ["Incline Bench Press"],
            "Exercise search should still find likely matches when users type multi-word queries out of stored-name order"
        )
    }

    func testFetchExercises_matchesPrimaryMuscleAliases() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "")
        ]
        viewModel.searchText = "chest"

        let results = viewModel.fetchExercises()

        XCTAssertEqual(
            results.map(\.name),
            ["Bench Press"],
            "Exercise search should match primary muscle names so users can find movements even when they remember the target muscle instead of the exercise name"
        )
    }

    func testFetchExercises_matchesMultiWordMuscleAliases() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Back Extension", category: .other, primaryMuscleGroups: [.lowerBack], secondaryMuscleGroups: [.glutes], instructions: ""),
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "")
        ]
        viewModel.searchText = "lower back"

        let results = viewModel.fetchExercises()

        XCTAssertEqual(
            results.map(\.name),
            ["Back Extension"],
            "Exercise search should match shared display-name aliases like Lower Back without requiring users to open the muscle filter chips"
        )
    }

    func testFetchExercises_matchesCategoryAliasesAfterNameMatches() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Compound Stretch", category: .other, primaryMuscleGroups: [.other], secondaryMuscleGroups: [], instructions: ""),
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Pull-Up", category: .bodyweight, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "")
        ]
        viewModel.searchText = "compound"

        let results = viewModel.fetchExercises()

        XCTAssertEqual(
            results.map(\.name),
            ["Compound Stretch", "Bench Press"],
            "Category-name matches should help users browse by movement type, but true name matches should still rank ahead of alias-only hits"
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
            "Showing 1 of 3 exercises for “Bench”",
            "Active exercise searches should surface a quick filtered-result summary with the normalized query"
        )

        viewModel.searchText = ""
        viewModel.selectedMuscleGroup = .back

        XCTAssertEqual(
            viewModel.filteredResultsSummary(filteredCount: 2),
            "Showing 2 of 3 exercises targeting Back",
            "Active exercise filters should surface which muscle group is narrowing the library"
        )
    }

    func testFilteredResultsSummary_includesCombinedSearchAndFilterContext() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: ""),
            Exercise(name: "Cable Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: ""),
            Exercise(name: "Pull-Up", category: .bodyweight, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "")
        ]
        viewModel.searchText = "  row\n"
        viewModel.selectedCategory = .compound
        viewModel.selectedMuscleGroup = .back

        XCTAssertEqual(
            viewModel.filteredResultsSummary(filteredCount: 2),
            "Showing 2 of 3 exercises for “row” • in Compound • targeting Back",
            "Combined search and filter summaries should explain why the visible exercise set is narrowed"
        )
    }

    func testSelectableResultsSummary_includesTemplateExclusions() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: ""),
            Exercise(name: "Cable Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: ""),
            Exercise(name: "Pull-Up", category: .bodyweight, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "")
        ]
        viewModel.searchText = "row"
        viewModel.selectedCategory = .compound

        XCTAssertEqual(
            viewModel.selectableResultsSummary(availableCount: 0, excludedCount: 2),
            "Showing 0 available of 3 exercises for “row” • in Compound • 2 already in template",
            "Template exercise pickers should explain when zero visible results are caused by already-added matches instead of missing search coverage"
        )
    }

    func testEmptyStateKind_prefersEmptyLibraryWhenNoExercisesExistEvenIfQueryIsActive() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.searchText = "bench"
        viewModel.selectedCategory = .compound

        XCTAssertEqual(
            viewModel.emptyStateKind(filteredCount: 0),
            .emptyLibrary,
            "An actually empty library should keep the first-run empty state instead of pretending the user merely filtered everything out"
        )
        XCTAssertEqual(
            viewModel.emptyStateTitle(filteredCount: 0),
            "No Exercises Yet"
        )
        XCTAssertEqual(
            viewModel.emptyStateDescription(filteredCount: 0),
            "Add your first custom exercise to start building your library."
        )
    }

    func testEmptyStateKind_usesNoMatchingResultsWhenLibraryHasExercisesButFiltersHideThem() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "")
        ]
        viewModel.searchText = "squat"

        XCTAssertEqual(
            viewModel.emptyStateKind(filteredCount: 0),
            .noMatchingResults,
            "Once the library has exercises, a zero-result search should use the recovery empty state instead of first-run copy"
        )
        XCTAssertEqual(
            viewModel.emptyStateTitle(filteredCount: 0),
            "No Matching Exercises"
        )
        XCTAssertEqual(
            viewModel.emptyStateDescription(filteredCount: 0),
            "Try changing your search or filters, or clear them to see every exercise."
        )
    }

    func testDeletionConfirmationMessage_fallsBackToGenericCopyWithoutImpactDetails() {
        XCTAssertEqual(
            ExerciseLibraryViewModel.deletionConfirmationMessage(
                for: .init(loggedSetCount: 0, workoutCount: 0, templateCount: 0)
            ),
            "Are you sure you want to delete this exercise? This action cannot be undone."
        )
    }

    func testDeletionConfirmationMessage_describesLoggedHistoryAndTemplateImpact() {
        XCTAssertEqual(
            ExerciseLibraryViewModel.deletionConfirmationMessage(
                for: .init(loggedSetCount: 5, workoutCount: 2, templateCount: 1)
            ),
            "This will remove 5 logged sets from 2 workouts. 1 template still references this exercise and will skip it when started until you replace or remove it."
        )
    }
}
