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

    func testFetchExercises_matchesCompactedExerciseNames() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "")
        ]
        viewModel.searchText = "benchpress"

        let results = viewModel.fetchExercises()

        XCTAssertEqual(
            results.map(\.name),
            ["Bench Press"],
            "Exercise search should match compacted name queries so users do not need to type spaces exactly"
        )
    }

    func testFetchExercises_ignoresGenericTrailingExerciseSuffixes() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "")
        ]
        viewModel.searchText = "bench press exercise"

        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Bench Press"],
            "Exercise search should ignore generic trailing words like exercise so remembered movement names still find the saved lift"
        )
    }

    func testFetchExercises_handlesNaturalLanguageLookupPhrasing() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "")
        ]
        viewModel.searchText = "show me bench press exercise please"

        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Bench Press"],
            "Exercise search should understand conversational find/open/show phrasing instead of requiring users to type only the saved movement name"
        )

        viewModel.searchText = "find movement barbell row"
        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Barbell Row"],
            "Exercise search should also strip generic object words after natural-language lookup prefixes"
        )
    }

    func testFetchExercises_stripsObjectLeadInsAndEntityPrefixes() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Incline Dumbbell Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.shoulders], instructions: "")
        ]

        viewModel.searchText = "the bench press exercise"
        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Bench Press"],
            "Exercise search should ignore filler lead-ins like the/my when they wrap a remembered movement name"
        )

        viewModel.searchText = "exercise called incline dumbbell press"
        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Incline Dumbbell Press"],
            "Exercise search should also strip leading exercise/movement wrappers plus called/named wording"
        )

        viewModel.searchText = "open exercise for bench press"
        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Bench Press"],
            "Exercise search should ignore bridge words like for after natural-language lookup prefixes"
        )
    }

    func testFetchExercises_matchesExerciseInitialisms() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "")
        ]
        viewModel.searchText = "bp"

        let results = viewModel.fetchExercises()

        XCTAssertEqual(
            results.map(\.name),
            ["Bench Press"],
            "Exercise search should match common exercise initialisms like BP"
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
        let initialism = ExerciseLibraryViewModel.searchMatchPriority(
            exercise: Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            normalizedQuery: ExerciseLibraryViewModel.normalizedSearchLookupKey("bp")
        )
        let compacted = ExerciseLibraryViewModel.searchMatchPriority(
            exercise: Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            normalizedQuery: ExerciseLibraryViewModel.normalizedSearchLookupKey("benchpress")
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
        XCTAssertEqual(initialism, 3)
        XCTAssertEqual(compacted, 4)
        XCTAssertEqual(substring, 6)
        XCTAssertEqual(aliasExact, 7)
    }

    func testFetchExercises_prioritizesMoreRelevantSearchMatches() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Front Squat Rowing Drill", category: .compound, primaryMuscleGroups: [.quadriceps], secondaryMuscleGroups: [.back], instructions: ""),
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
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

        viewModel.searchText = "bp"

        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Bench Press"],
            "Initialism matches should surface the intended exercise ahead of unrelated results"
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

    func testFetchExercises_matchesCombinedAliasQueriesAcrossCategoryAndMuscles() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Cable Fly", category: .isolation, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.shoulders], instructions: ""),
            Exercise(name: "Pull-Up", category: .bodyweight, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "")
        ]

        viewModel.searchText = "compound chest"
        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Bench Press"],
            "Exercise search should match combined browse queries that span separate aliases like category plus muscle group"
        )

        viewModel.searchText = "triceps upper body"
        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Bench Press"],
            "Exercise search should also combine muscle and body-region aliases so natural browse phrasing still finds the right movement"
        )
    }

    func testFetchExercises_matchesBodyRegionAliases() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Back Squat", category: .compound, primaryMuscleGroups: [.quadriceps], secondaryMuscleGroups: [.glutes], instructions: ""),
            Exercise(name: "Plank", category: .bodyweight, primaryMuscleGroups: [.abs], secondaryMuscleGroups: [.obliques], instructions: ""),
            Exercise(name: "Burpee", category: .bodyweight, primaryMuscleGroups: [.quadriceps, .chest], secondaryMuscleGroups: [.shoulders, .abs], instructions: "")
        ]

        viewModel.searchText = "upper body"
        XCTAssertEqual(viewModel.fetchExercises().map(\.name), ["Bench Press", "Burpee"])

        viewModel.searchText = "legs"
        XCTAssertEqual(viewModel.fetchExercises().map(\.name), ["Back Squat", "Burpee"])

        viewModel.searchText = "core"
        XCTAssertEqual(viewModel.fetchExercises().map(\.name), ["Plank", "Burpee"])

        viewModel.searchText = "full body"
        XCTAssertEqual(viewModel.fetchExercises().map(\.name), ["Burpee"])
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

    func testFetchExercises_matchesReviewActionPhrasesForAnyExercise() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "")
        ]
        viewModel.searchText = "review bench press"

        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Bench Press"],
            "Exercise search should understand named Review quick-action wording so users can refind the same movement from the library action copy they just saw"
        )
    }

    func testFetchExercises_matchesInstructionTextAfterNameAndAliasMatches() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "Lower the bar to your mid chest with your elbows stacked under your wrists."),
            Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "Drive elbows back and squeeze your shoulder blades together at the top."),
            Exercise(name: "Chest Fly", category: .isolation, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.shoulders], instructions: "Keep a soft bend in your elbows.")
        ]
        viewModel.searchText = "drive elbows back"

        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Barbell Row"],
            "Exercise search should also match instruction cues so users can refind a movement by the coaching note they remember"
        )

        viewModel.searchText = "chest"
        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Bench Press", "Chest Fly"],
            "Name and muscle matches should still outrank instruction-only matches when a query could hit both"
        )
    }

    func testFetchExercises_matchesInstructionInitialisms() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "Drive elbows back"),
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "Brace and press")
        ]
        viewModel.searchText = "deb"

        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Barbell Row"],
            "Instruction search should support shorthand initialisms so quick cue-based lookups still find the right movement"
        )
    }

    func testFetchExercises_matchesCrossFieldQueriesAcrossNameAliasAndInstructions() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "Lower the bar to your mid chest with elbows stacked under wrists."),
            Exercise(name: "Cable Fly", category: .isolation, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.shoulders], instructions: "Keep a soft bend in your elbows."),
            Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "Drive elbows back at the top.")
        ]

        viewModel.searchText = "bench elbows"
        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Bench Press"],
            "Exercise search should match mixed-cue queries when users remember part of the exercise name and part of the coaching note"
        )

        viewModel.searchText = "compound elbows"
        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Bench Press", "Barbell Row"],
            "Exercise search should also combine category aliases with instruction cues instead of requiring every remembered word to live in one field"
        )
    }

    func testFetchExercises_matchesEditAndDeleteActionPhrasesOnlyForCustomExercises() {
        let viewModel = ExerciseLibraryViewModel()
        let customExercise = Exercise(name: "Garage Dip", category: .bodyweight, primaryMuscleGroups: [.triceps], secondaryMuscleGroups: [.chest], instructions: "")
        customExercise.isCustom = true

        let defaultExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "")
        defaultExercise.isCustom = false

        viewModel.exercises = [customExercise, defaultExercise]
        viewModel.searchText = "edit garage dip"

        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Garage Dip"],
            "Custom exercises should be discoverable by the named Edit quick action shown in the library"
        )

        viewModel.searchText = "delete bench press"
        XCTAssertTrue(
            viewModel.fetchExercises().isEmpty,
            "Built-in exercises should not suddenly match delete action wording when the library does not actually offer a delete shortcut for them"
        )
    }

    func testFetchExercises_matchesSelectionActionPhrasesOnlyWhenPickerAliasesAreEnabled() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: ""),
            Exercise(name: "Incline Dumbbell Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.shoulders], instructions: "")
        ]
        viewModel.searchText = "add bench press"

        XCTAssertTrue(
            viewModel.fetchExercises().isEmpty,
            "Library search should not match picker-only add wording unless the selector flow explicitly enables those aliases"
        )

        viewModel.includeSelectionActionSearchAliases = true
        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Bench Press"],
            "Workout/template pickers should understand named add-action wording for the current exact-match shortcut"
        )

        viewModel.searchText = "select barbell row"
        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Barbell Row"],
            "Picker search should also understand select wording so remembered action copy still finds the intended exercise"
        )

        viewModel.searchText = "choose incline dumbbell press"
        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Incline Dumbbell Press"],
            "Picker search should understand choose wording so natural selection phrasing still finds the intended exercise"
        )

        viewModel.searchText = "use bench press exercise"
        XCTAssertEqual(
            viewModel.fetchExercises().map(\.name),
            ["Bench Press"],
            "Picker search should also understand use wording while still ignoring trailing generic exercise filler"
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

    func testShouldShowResultsRecoveryActions_onlyAppearsWhenAnActiveQueryStillHasResults() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "")
        ]

        XCTAssertFalse(viewModel.shouldShowResultsRecoveryActions(filteredCount: 2))

        viewModel.searchText = "bench"
        XCTAssertTrue(viewModel.shouldShowResultsRecoveryActions(filteredCount: 1))
        XCTAssertFalse(viewModel.shouldShowResultsRecoveryActions(filteredCount: 0))

        viewModel.searchText = ""
        viewModel.selectedCategory = .compound
        XCTAssertTrue(viewModel.shouldShowResultsRecoveryActions(filteredCount: 2))
    }

    func testSingleSelectableExerciseActionTitle_onlyAppearsForExactVisibleMatchesWhileQueryIsActive() {
        let viewModel = ExerciseLibraryViewModel()
        let bench = Exercise(
            name: "Bench Press",
            category: .compound,
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.triceps],
            instructions: ""
        )
        viewModel.exercises = [
            bench,
            Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "")
        ]

        XCTAssertEqual(
            viewModel.singleSelectableExerciseActionTitle(for: bench),
            "Add “Bench Press”",
            "When only one visible exercise remains, picker lists should surface the same one-tap add shortcut even without an active search or filter"
        )

        viewModel.searchText = "bench"
        XCTAssertEqual(
            viewModel.singleSelectableExerciseActionTitle(for: bench),
            "Add “Bench Press”",
            "Exact one-result picker searches should still surface the same one-tap add shortcut for the matched exercise"
        )

        XCTAssertNil(
            viewModel.singleSelectableExerciseActionTitle(for: nil),
            "The add shortcut should disappear once there is no single visible match"
        )
    }

    func testShouldShowSingleResultQuickActions_supportsSingleVisibleExercisesWithoutSearch() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "")
        ]

        XCTAssertTrue(
            viewModel.shouldShowSingleResultQuickActions(filteredCount: 1),
            "When the library only has one visible exercise, the quick-action footer should stay discoverable even without an active search"
        )

        XCTAssertFalse(
            viewModel.shouldShowSingleResultQuickActions(filteredCount: 2),
            "Quick actions should still require exactly one visible exercise"
        )
    }

    func testShouldShowSingleResultQuickActions_supportsFilterOnlyMatchesToo() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Barbell Row", category: .compound, primaryMuscleGroups: [.back], secondaryMuscleGroups: [.biceps], instructions: "")
        ]

        viewModel.selectedMuscleGroup = .chest
        XCTAssertTrue(
            viewModel.shouldShowSingleResultQuickActions(filteredCount: 1),
            "Category or muscle filters that narrow the library to one visible result should unlock the same quick-action footer as searches"
        )

        XCTAssertFalse(
            viewModel.shouldShowSingleResultQuickActions(filteredCount: 2),
            "Quick actions should still require exactly one visible exercise"
        )
    }

    func testSuggestedExerciseNameFromSearch_returnsNormalizedSearchWhenNameIsAvailable() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "")
        ]
        viewModel.searchText = "  Incline\nBench Press  "

        XCTAssertEqual(
            viewModel.suggestedExerciseNameFromSearch(),
            "Incline Bench Press",
            "No-match exercise searches should be reusable as a prefilled custom-exercise draft when the normalized name is still unique"
        )
        XCTAssertEqual(
            viewModel.createExerciseRecoveryTitle(filteredCount: 0),
            "Add Custom Exercise “Incline Bench Press”"
        )
    }

    func testSuggestedExerciseNameFromSearch_stripsSelectionPrefixesAndGenericTrailingExerciseSuffixes() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "")
        ]
        viewModel.searchText = "  use exercise Incline Bench Press exercise  "

        XCTAssertEqual(
            viewModel.suggestedExerciseNameFromSearch(),
            "Incline Bench Press",
            "Create-from-search should strip picker-style selection wording and generic trailing exercise words so new custom names stay clean"
        )
        XCTAssertEqual(
            viewModel.createExerciseRecoveryTitle(filteredCount: 0),
            "Add Custom Exercise “Incline Bench Press”"
        )
    }

    func testSuggestedExerciseNameFromSearch_stripsConversationalLookupPhrasing() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "")
        ]
        viewModel.searchText = "  can you find exercise Incline Bench Press for me  "

        XCTAssertEqual(
            viewModel.suggestedExerciseNameFromSearch(),
            "Incline Bench Press",
            "Create-from-search should strip conversational lookup phrasing so search-seeded custom exercise names stay clean"
        )
        XCTAssertEqual(
            viewModel.createExerciseRecoveryTitle(filteredCount: 0),
            "Add Custom Exercise “Incline Bench Press”"
        )
    }

    func testSuggestedExerciseNameFromSearch_stripsObjectLeadInsAndEntityPrefixes() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "")
        ]
        viewModel.searchText = "  find my exercise called Incline Bench Press please  "

        XCTAssertEqual(
            viewModel.suggestedExerciseNameFromSearch(),
            "Incline Bench Press",
            "Create-from-search should strip filler object words plus leading exercise wrappers so new custom exercise names stay clean"
        )
        XCTAssertEqual(
            viewModel.createExerciseRecoveryTitle(filteredCount: 0),
            "Add Custom Exercise “Incline Bench Press”"
        )
    }

    func testSuggestedExerciseNameFromSearch_hidesCreateRecoveryForDuplicateNormalizedNames() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "")
        ]
        viewModel.searchText = "  bench\npress  "

        XCTAssertNil(
            viewModel.suggestedExerciseNameFromSearch(),
            "Search-to-create should stay hidden when the normalized exercise name already exists in the library"
        )
        XCTAssertNil(viewModel.createExerciseRecoveryTitle(filteredCount: 0))
    }

    func testSuggestedExerciseNameFromSearch_hidesCreateRecoveryWhenSuffixStrippingRevealsExistingExercise() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "")
        ]
        viewModel.searchText = "bench press exercise"

        XCTAssertNil(
            viewModel.suggestedExerciseNameFromSearch(),
            "Create recovery should stay hidden when suffix stripping reveals an exercise that already exists"
        )
        XCTAssertNil(viewModel.createExerciseRecoveryTitle(filteredCount: 0))
    }

    func testSuggestedExerciseNameFromSearch_hidesGenericEntityOnlyPrefills() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.searchText = "exercise"

        XCTAssertNil(
            viewModel.suggestedExerciseNameFromSearch(),
            "Create recovery should stay hidden for generic exercise-only searches instead of suggesting unusably vague custom names"
        )
        XCTAssertNil(viewModel.createExerciseRecoveryTitle(filteredCount: 0))
    }

    func testShouldShowCreateExerciseFromSearchAction_requiresResultsAndUniqueSearchName() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Incline Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.shoulders], instructions: "")
        ]

        viewModel.searchText = "Bench"
        XCTAssertTrue(
            viewModel.shouldShowCreateExerciseFromSearchAction(filteredCount: 2),
            "Near-match searches should keep a direct create action visible when the exact normalized exercise name is still available"
        )

        viewModel.searchText = "bench press"
        XCTAssertFalse(
            viewModel.shouldShowCreateExerciseFromSearchAction(filteredCount: 1),
            "The create action should disappear when the search already resolves to an existing normalized exercise name"
        )
    }

    func testPreferredNewExerciseDefaults_followActiveFilters() {
        let viewModel = ExerciseLibraryViewModel()

        XCTAssertEqual(
            viewModel.preferredNewExerciseCategory(),
            .compound,
            "New custom exercises should fall back to Compound when no category filter is active"
        )
        XCTAssertEqual(
            viewModel.preferredNewExercisePrimaryMuscles(),
            [],
            "New custom exercises should not invent a primary muscle when no muscle filter is active"
        )

        viewModel.selectedCategory = .isolation
        viewModel.selectedMuscleGroup = .back

        XCTAssertEqual(
            viewModel.preferredNewExerciseCategory(),
            .isolation,
            "New custom exercises should inherit the currently selected category filter"
        )
        XCTAssertEqual(
            viewModel.preferredNewExercisePrimaryMuscles(),
            [.back],
            "New custom exercises should inherit the currently selected muscle-group filter as their initial primary muscle"
        )

        XCTAssertTrue(
            viewModel.shouldShowGenericCreateExerciseAction(filteredCount: 0),
            "Filter-only empty states should still offer an inline custom-exercise path that reuses the active filter context"
        )
    }

    func testShouldShowGenericCreateExerciseAction_onlyAppearsForEmptyLibraryOrFilterOnlyDeadEnds() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "")
        ]

        XCTAssertFalse(
            viewModel.shouldShowGenericCreateExerciseAction(filteredCount: 0),
            "A non-empty library without active filters should rely on search-specific recovery or normal browsing instead of showing a generic create CTA everywhere"
        )

        viewModel.selectedCategory = .isolation

        XCTAssertTrue(
            viewModel.shouldShowGenericCreateExerciseAction(filteredCount: 0),
            "When filters narrow the library to zero matches, the inline add-exercise fallback should stay available"
        )

        viewModel.searchText = "bench"

        XCTAssertFalse(
            viewModel.shouldShowGenericCreateExerciseAction(filteredCount: 0),
            "Once a search query is active, the view should prefer search-specific create recovery instead of the generic filter-only CTA"
        )
    }

    func testCreateExerciseRecoveryTitle_staysAvailableDuringNearMatchResults() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Incline Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.shoulders], instructions: "")
        ]
        viewModel.searchText = "Bench"

        XCTAssertEqual(
            viewModel.createExerciseRecoveryTitle(filteredCount: 2),
            "Add Custom Exercise “Bench”",
            "Near-match results should keep a direct create-from-search title available so picker flows can offer inline add-and-continue recovery"
        )
        XCTAssertEqual(viewModel.preferredNewExercisePrefillName(), "Bench")
    }

    func testPreferredNewExercisePrefillName_fallsBackToEmptyStringForDuplicateSearchNames() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "")
        ]
        viewModel.searchText = " bench press "

        XCTAssertEqual(
            viewModel.preferredNewExercisePrefillName(),
            "",
            "Duplicate normalized exercise names should not prefill add flows with an unusable collision"
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

    func testSelectableResultsSummary_supportsWorkoutExclusions() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: ""),
            Exercise(name: "Incline Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.shoulders], instructions: "")
        ]
        viewModel.searchText = "bench"

        XCTAssertEqual(
            viewModel.selectableResultsSummary(
                availableCount: 0,
                excludedCount: 2,
                exclusionContext: "workout"
            ),
            "Showing 0 available of 2 exercises for “bench” • 2 already in workout",
            "Workout exercise pickers should explain when the current search only finds movements that are already in the active workout"
        )
    }

    func testSelectionEmptyState_prefersEmptyLibraryCopyOverSearchFailureWhenNothingExists() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.searchText = "bench"
        viewModel.selectedCategory = .compound

        XCTAssertEqual(
            viewModel.selectionEmptyStateTitle(totalFetchedCount: 0, excludedCount: 0),
            "No Exercises Available",
            "Picker empty states should not pretend a user search failed when the library is actually empty"
        )
        XCTAssertEqual(
            viewModel.selectionEmptyStateDescription(
                totalFetchedCount: 0,
                excludedCount: 0,
                context: .workout
            ),
            "Add an exercise in the library first, then come back here to use it in a workout.",
            "Workout pickers should keep the empty-library guidance even if a search or filter is already active"
        )
        XCTAssertEqual(
            viewModel.selectionEmptyStateDescription(
                totalFetchedCount: 0,
                excludedCount: 0,
                context: .template
            ),
            "Add an exercise in the library first, then come back here to use it in a template.",
            "Template pickers should keep the empty-library guidance even if a search or filter is already active"
        )
    }

    func testSelectionEmptyState_keepsAlreadyAddedMessagingForFullyExcludedResults() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "")
        ]
        viewModel.searchText = "bench"

        XCTAssertEqual(
            viewModel.selectionEmptyStateTitle(totalFetchedCount: 1, excludedCount: 1),
            "All Matching Exercises Already Added"
        )
        XCTAssertEqual(
            viewModel.selectionEmptyStateDescription(
                totalFetchedCount: 1,
                excludedCount: 1,
                context: .template
            ),
            "This template already includes every exercise in your current search or filter results. Clear your filters or remove one from the template to add it again."
        )
    }

    func testSelectionEmptyStateDescription_teachesRicherSearchRecoveryInPickers() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "")
        ]
        viewModel.searchText = "squat"

        XCTAssertEqual(
            viewModel.selectionEmptyStateDescription(
                totalFetchedCount: 1,
                excludedCount: 0,
                context: .workout
            ),
            "No exercises matched “squat”. Try a different search, clear it to browse every exercise in your library, or search names, notes, body regions like upper body or legs, muscle groups, and action wording like add, use, choose, or review. You can also add a custom exercise from this search.",
            "Workout and template exercise pickers should teach the same richer search recovery users already get in the main library"
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
            "No exercises matched “squat”. Try a different search, clear it to browse every exercise, or search names, notes, body regions like upper body or legs, muscle groups, and action wording like add, use, choose, or review. You can also add a custom exercise from this search."
        )
    }

    func testEmptyStateDescription_withFiltersOnlyKeepsGenericRecoveryCopy() {
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [
            Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest], secondaryMuscleGroups: [.triceps], instructions: "")
        ]
        viewModel.selectedCategory = .isolation

        XCTAssertEqual(
            viewModel.emptyStateDescription(filteredCount: 0),
            "Try changing your search or filters, or clear them to see every exercise."
        )
    }

    func testDeletionConfirmationMessage_fallsBackToGenericCopyWithoutImpactDetails() {
        XCTAssertEqual(
            ExerciseLibraryViewModel.deletionConfirmationMessage(
                for: nil,
                impact: .init(loggedSetCount: 0, loggedWorkingSetCount: 0, loggedWarmupSetCount: 0, loggedWorkoutCount: 0, draftSetCount: 0, draftWorkoutCount: 0, templateCount: 0, templateNames: [])
            ),
            "Deleting this exercise cannot be undone."
        )
    }

    func testDeletionConfirmationMessage_namesSpecificExerciseAndImpact() {
        let exercise = Exercise(
            name: "  Garage\n Dip  ",
            category: .bodyweight,
            primaryMuscleGroups: [.chest],
            isCustom: true
        )

        XCTAssertEqual(
            ExerciseLibraryViewModel.deletionConfirmationMessage(
                for: exercise,
                impact: .init(loggedSetCount: 5, loggedWorkingSetCount: 3, loggedWarmupSetCount: 2, loggedWorkoutCount: 2, draftSetCount: 0, draftWorkoutCount: 0, templateCount: 1, templateNames: ["Push Day"])
            ),
            "Deleting “Garage Dip” will remove 5 logged sets from 2 workouts, including 3 logged working sets and 2 logged warm-up sets. It will also leave 1 template (“Push Day”) that still references it and will skip it when started until you replace or remove it."
        )
    }

    func testDeletionConfirmationMessage_usesExerciseFallbackNameWhenBlank() {
        let blankExercise = Exercise(
            name: "  \n ",
            category: .compound,
            primaryMuscleGroups: [.back],
            isCustom: true
        )

        XCTAssertEqual(
            ExerciseLibraryViewModel.deletionConfirmationMessage(
                for: blankExercise,
                impact: .init(loggedSetCount: 1, loggedWorkingSetCount: 1, loggedWarmupSetCount: 0, loggedWorkoutCount: 1, draftSetCount: 0, draftWorkoutCount: 0, templateCount: 0, templateNames: [])
            ),
            "Deleting this exercise will remove 1 logged set from 1 workout, including 1 logged working set."
        )
    }

    func testDeletionConfirmationMessage_mentionsUnloggedDraftWorkoutImpact() {
        let exercise = Exercise(
            name: "Garage Dip",
            category: .bodyweight,
            primaryMuscleGroups: [.chest],
            isCustom: true
        )

        XCTAssertEqual(
            ExerciseLibraryViewModel.deletionConfirmationMessage(
                for: exercise,
                impact: .init(loggedSetCount: 2, loggedWorkingSetCount: 0, loggedWarmupSetCount: 2, loggedWorkoutCount: 1, draftSetCount: 3, draftWorkoutCount: 1, templateCount: 0, templateNames: [])
            ),
            "Deleting “Garage Dip” will remove 2 logged sets from 1 workout, including 2 logged warm-up sets. It will also remove 3 unlogged draft sets from 1 in-progress workout."
        )
    }

    func testDeletionConfirmationMessage_namesMultipleReferencingTemplatesWhenNeeded() {
        let exercise = Exercise(
            name: "Garage Dip",
            category: .bodyweight,
            primaryMuscleGroups: [.chest],
            isCustom: true
        )

        XCTAssertEqual(
            ExerciseLibraryViewModel.deletionConfirmationMessage(
                for: exercise,
                impact: .init(loggedSetCount: 0, loggedWorkingSetCount: 0, loggedWarmupSetCount: 0, loggedWorkoutCount: 0, draftSetCount: 0, draftWorkoutCount: 0, templateCount: 3, templateNames: ["Push Day", "Upper A", "Upper B"])
            ),
            "Deleting “Garage Dip” will leave 3 templates (including “Push Day”, “Upper A”, and 1 more) that still reference it and will skip it when started until you replace or remove it."
        )
    }

    func testExerciseActionTitles_nameTheExactExercise() {
        let viewModel = ExerciseLibraryViewModel()
        let customExercise = Exercise(
            name: "Garage Dip",
            category: .bodyweight,
            primaryMuscleGroups: [.triceps],
            secondaryMuscleGroups: [.chest],
            instructions: ""
        )

        XCTAssertEqual(viewModel.reviewActionTitle(for: customExercise), "Review “Garage Dip”")
        XCTAssertEqual(ExerciseLibraryViewModel.editScreenTitle(for: customExercise), "Edit “Garage Dip”")
        XCTAssertEqual(viewModel.editActionTitle(for: customExercise), "Edit “Garage Dip”")
        XCTAssertEqual(viewModel.deleteActionTitle(for: customExercise), "Delete “Garage Dip”")
        XCTAssertEqual(viewModel.deleteAlertTitle(for: customExercise), "Delete “Garage Dip”?")
    }

    func testExerciseActionTitles_fallBackGracefullyWithoutAnExercise() {
        let viewModel = ExerciseLibraryViewModel()

        XCTAssertNil(viewModel.reviewActionTitle(for: nil))
        XCTAssertEqual(ExerciseLibraryViewModel.editScreenTitle(for: nil), "Edit Exercise")
        XCTAssertNil(viewModel.editActionTitle(for: nil))
        XCTAssertNil(viewModel.deleteActionTitle(for: nil))
        XCTAssertEqual(viewModel.deleteAlertTitle(for: nil), "Delete Exercise?")
        XCTAssertEqual(viewModel.deleteFailureAlertTitle(for: nil), "Unable to Delete Exercise")
        XCTAssertEqual(viewModel.deleteFailureMessage(for: nil), "This exercise could not be deleted right now. Please try again.")
    }

    func testExerciseActionTitles_fallBackGracefullyForBlankExerciseNames() {
        let blankExercise = Exercise(
            name: "  \n  ",
            category: .bodyweight,
            primaryMuscleGroups: [.back],
            isCustom: true
        )
        let viewModel = ExerciseLibraryViewModel()
        viewModel.exercises = [blankExercise]

        XCTAssertEqual(viewModel.singleSelectableExerciseActionTitle(for: blankExercise), "Add Exercise")
        XCTAssertEqual(viewModel.reviewActionTitle(for: blankExercise), "Review Exercise")
        XCTAssertEqual(ExerciseLibraryViewModel.editScreenTitle(for: blankExercise), "Edit Exercise")
        XCTAssertEqual(viewModel.editActionTitle(for: blankExercise), "Edit Exercise")
        XCTAssertEqual(viewModel.deleteActionTitle(for: blankExercise), "Delete Exercise")
        XCTAssertEqual(viewModel.deleteAlertTitle(for: blankExercise), "Delete Exercise?")
        XCTAssertEqual(viewModel.deleteFailureAlertTitle(for: blankExercise), "Unable to Delete Exercise")
        XCTAssertEqual(viewModel.deleteFailureMessage(for: blankExercise), "This exercise could not be deleted right now. Please try again.")
    }

    func testExerciseDeleteFailureCopy_namesSpecificExerciseWhenAvailable() {
        let exercise = Exercise(
            name: "  Garage\n Dip  ",
            category: .bodyweight,
            primaryMuscleGroups: [.chest],
            isCustom: true
        )
        let viewModel = ExerciseLibraryViewModel()

        XCTAssertEqual(viewModel.deleteFailureAlertTitle(for: exercise), "Couldn’t Delete “Garage Dip”")
        XCTAssertEqual(viewModel.deleteFailureMessage(for: exercise), "“Garage Dip” is still in your exercise library. Please try again.")
    }
}
