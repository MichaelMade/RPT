import XCTest
@testable import RPT

@MainActor
final class TemplateViewModelTests: XCTestCase {
    func testNormalizedSearchQuery_trimsAndCollapsesWhitespace() {
        XCTAssertEqual(
            TemplateViewModel.normalizedSearchQuery("  Push\n\n   Day  "),
            "Push Day"
        )

        XCTAssertEqual(
            TemplateViewModel.normalizedSearchQuery(" \n\t "),
            ""
        )
    }

    func testFetchTemplates_ignoresWhitespaceOnlySearchText() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"]),
            makeTemplate(name: "Pull Day", exerciseNames: ["Barbell Row"])
        ]
        viewModel.searchText = "   \n  "

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Push Day", "Pull Day"]
        )
    }

    func testFetchTemplates_matchesTemplateNameOutOfOrderTokens() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Upper Body Push", exerciseNames: ["Bench Press"]),
            makeTemplate(name: "Leg Day", exerciseNames: ["Squat"])
        ]
        viewModel.searchText = "push upper"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Upper Body Push"]
        )
    }

    func testFetchTemplates_matchesExerciseNamesAndNotes() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"], notes: "Heavy chest focus"),
            makeTemplate(name: "Pull Day", exerciseNames: ["Barbell Row"], notes: "Controlled back volume")
        ]

        viewModel.searchText = "row"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Pull Day"])

        viewModel.searchText = "chest focus"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Push Day"])
    }

    func testFetchTemplates_prioritizesNameMatchesBeforeExerciseMatches() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Row Focus", exerciseNames: ["Bench Press"]),
            makeTemplate(name: "Pull Day", exerciseNames: ["Cable Row"]),
            makeTemplate(name: "Conditioning", exerciseNames: ["Farmer Row Carry"])
        ]
        viewModel.searchText = "row"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Row Focus", "Pull Day", "Conditioning"]
        )
    }

    func testFilteredResultsSummary_onlyAppearsForActiveSearch() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"]),
            makeTemplate(name: "Pull Day", exerciseNames: ["Barbell Row"])
        ]

        XCTAssertNil(viewModel.filteredResultsSummary(filteredCount: 2))

        viewModel.searchText = " push\n"
        XCTAssertEqual(
            viewModel.filteredResultsSummary(filteredCount: 1),
            "Showing 1 of 2 templates for “push”"
        )
    }

    func testClearSearch_resetsSearchState() {
        let viewModel = TemplateViewModel()
        viewModel.searchText = "Push"

        viewModel.clearSearch()

        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertFalse(viewModel.hasActiveSearch)
    }

    func testShouldShowResultsRecoveryActions_onlyAppearsWhenSearchStillHasResults() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"]),
            makeTemplate(name: "Pull Day", exerciseNames: ["Barbell Row"])
        ]

        XCTAssertFalse(viewModel.shouldShowResultsRecoveryActions(filteredCount: 2))

        viewModel.searchText = "push"
        XCTAssertTrue(viewModel.shouldShowResultsRecoveryActions(filteredCount: 1))
        XCTAssertFalse(viewModel.shouldShowResultsRecoveryActions(filteredCount: 0))
    }

    func testPersistActiveWorkoutBeforeTemplateStart_saveForLaterMarksWorkoutSavedOnlyAfterSuccess() {
        let viewModel = TemplateViewModel()
        let workoutStateManager = WorkoutStateManager.shared
        workoutStateManager.clearDiscardedState()
        defer { workoutStateManager.clearDiscardedState() }

        workoutStateManager.markWorkoutAsDiscarded(UUID())
        let workout = Workout(name: "Push Day")

        let didPersist = viewModel.persistActiveWorkoutBeforeTemplateStart(
            workout,
            action: .saveForLater,
            persist: { _ in true }
        )

        XCTAssertTrue(didPersist)
        XCTAssertFalse(workoutStateManager.wasAnyWorkoutDiscarded(), "Successful save-for-later protection should clear discarded state so the workout can still be resumed later")
    }

    func testPersistActiveWorkoutBeforeTemplateStart_discardDoesNotMutateStateWhenDeleteFails() {
        let viewModel = TemplateViewModel()
        let workoutStateManager = WorkoutStateManager.shared
        workoutStateManager.clearDiscardedState()
        defer { workoutStateManager.clearDiscardedState() }

        let workout = Workout(name: "Push Day")

        let didPersist = viewModel.persistActiveWorkoutBeforeTemplateStart(
            workout,
            action: .discard,
            persist: { _ in false }
        )

        XCTAssertFalse(didPersist)
        XCTAssertFalse(workoutStateManager.wasAnyWorkoutDiscarded(), "Failed discard protection should leave workout state untouched so the current draft stays resumable")
    }

    func testActiveWorkoutPersistenceFailureMessage_matchesActionContext() {
        let viewModel = TemplateViewModel()

        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureMessage(for: .saveForLater),
            "Couldn’t save the current workout. Keep it open, then try starting from the template again."
        )

        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureMessage(for: .discard),
            "Couldn’t discard the current workout. Keep it open, then try starting from the template again."
        )
    }

    private func makeTemplate(name: String, exerciseNames: [String], notes: String = "") -> WorkoutTemplate {
        WorkoutTemplate(
            name: name,
            exercises: exerciseNames.map {
                TemplateExercise(
                    exerciseName: $0,
                    suggestedSets: 3,
                    repRanges: [
                        TemplateRepRange(setNumber: 1, minReps: 6, maxReps: 8, percentageOfFirstSet: 1.0)
                    ],
                    notes: ""
                )
            },
            notes: notes
        )
    }
}
