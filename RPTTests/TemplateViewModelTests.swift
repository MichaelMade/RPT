import XCTest
import SwiftData
@testable import RPT

@MainActor
final class TemplateViewModelTests: XCTestCase {
    private final class StubTemplateManager: TemplateManager {
        var workoutToReturn: Workout?

        init(workoutToReturn: Workout?) {
            self.workoutToReturn = workoutToReturn
            super.init(dataManager: DataManager.shared, exerciseManager: ExerciseManager.shared, seedDefaultTemplates: false)
        }

        override func createWorkoutFromTemplate(_ template: WorkoutTemplate) -> Workout? {
            workoutToReturn
        }
    }

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

    func testFetchTemplates_matchesExerciseNotes() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(
                name: "Push Day",
                exerciseNames: ["Bench Press"],
                exerciseNotes: ["Pause on the chest"]
            ),
            makeTemplate(
                name: "Pull Day",
                exerciseNames: ["Barbell Row"],
                exerciseNotes: ["Drive elbows back"]
            )
        ]

        viewModel.searchText = "pause chest"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Push Day"])

        viewModel.searchText = "deb"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Pull Day"])
    }

    func testFetchTemplates_matchesExerciseNameOutOfOrderTokens() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"]),
            makeTemplate(name: "Pull Day", exerciseNames: ["Barbell Row"])
        ]
        viewModel.searchText = "press bench"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Push Day"]
        )
    }

    func testFetchTemplates_matchesCompactedTemplateNameAndExerciseQueries() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Upper Body", exerciseNames: ["Bench Press"]),
            makeTemplate(name: "Pull Day", exerciseNames: ["Barbell Row"])
        ]

        viewModel.searchText = "upperbody"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Upper Body"])

        viewModel.searchText = "benchpress"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Upper Body"])
    }

    func testFetchTemplates_matchesTemplateAndExerciseInitialisms() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Upper Body Push", exerciseNames: ["Bench Press"]),
            makeTemplate(name: "Leg Day", exerciseNames: ["Romanian Deadlift"])
        ]

        viewModel.searchText = "ubp"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Upper Body Push"])

        viewModel.searchText = "bp"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Upper Body Push"])
    }

    func testFetchTemplates_matchesPunctuationInsensitiveExerciseQueries() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Pull Day", exerciseNames: ["Pull-Up"]),
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"])
        ]

        viewModel.searchText = "pullup"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Pull Day"]
        )
    }

    func testFetchTemplates_matchesCompactedNotesQueries() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"], notes: "Heavy chest focus"),
            makeTemplate(name: "Pull Day", exerciseNames: ["Barbell Row"], notes: "Controlled back volume")
        ]

        viewModel.searchText = "heavychest"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Push Day"]
        )
    }

    func testFetchTemplates_matchesNotesOutOfOrderTokens() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"], notes: "Heavy chest focus"),
            makeTemplate(name: "Pull Day", exerciseNames: ["Barbell Row"], notes: "Controlled back volume")
        ]
        viewModel.searchText = "focus heavy"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Push Day"]
        )
    }

    func testFetchTemplates_matchesNotesInitialisms() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"], notes: "Heavy chest focus"),
            makeTemplate(name: "Pull Day", exerciseNames: ["Barbell Row"], notes: "Controlled back volume")
        ]
        viewModel.searchText = "hcf"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Push Day"]
        )
    }

    func testFetchTemplates_matchesMissingIssueKeywords() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(
            name: "Available Bench \(UUID().uuidString)",
            category: .compound,
            primaryMuscleGroups: [.chest]
        )
        context.insert(availableExercise)
        try context.save()
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Broken Template", exerciseNames: ["Missing Lift \(UUID().uuidString)"]),
            makeTemplate(name: "Ready Template", exerciseNames: [availableExercise.name])
        ]
        viewModel.searchText = "missing"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Broken Template"]
        )
    }

    func testFetchTemplates_matchesPartialIssueKeywords() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(
            name: "Available Row \(UUID().uuidString)",
            category: .compound,
            primaryMuscleGroups: [.lats]
        )
        context.insert(availableExercise)
        try context.save()
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(
                name: "Partial Template",
                exerciseNames: [availableExercise.name, "Missing Squat \(UUID().uuidString)"]
            ),
            makeTemplate(name: "Ready Template", exerciseNames: [availableExercise.name])
        ]
        viewModel.searchText = "partial"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Partial Template"]
        )
    }

    func testFetchTemplates_matchesRepeatedIssueKeywords() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Duplicate Template", exerciseNames: ["Bench Press", " bench\npress "]),
            makeTemplate(name: "Clean Template", exerciseNames: ["Squat"])
        ]
        viewModel.searchText = "duplicate"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Duplicate Template"]
        )
    }

    func testFetchTemplates_matchesReadyKeywordForPartialAndReadyTemplates() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(
            name: "Available Press \(UUID().uuidString)",
            category: .compound,
            primaryMuscleGroups: [.chest]
        )
        context.insert(availableExercise)
        try context.save()
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(
                name: "Partial Template",
                exerciseNames: [availableExercise.name, "Missing Row \(UUID().uuidString)"]
            ),
            makeTemplate(name: "Ready Template", exerciseNames: [availableExercise.name]),
            makeTemplate(name: "Blocked Template", exerciseNames: ["Missing Squat \(UUID().uuidString)"])
        ]
        viewModel.searchText = "ready"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Partial Template", "Ready Template"]
        )
    }

    func testFetchTemplates_matchesCantStartKeywordForBlockedTemplates() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Blocked Template", exerciseNames: ["Missing Lift \(UUID().uuidString)"]),
            makeTemplate(name: "Ready Template", exerciseNames: ["Bench Press"])
        ]
        viewModel.searchText = "cant start"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Blocked Template"]
        )
    }

    func testFetchTemplates_matchesCantStartKeywordForDuplicateOnlyAndEmptyTemplates() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Duplicate Only", exerciseNames: ["Bench Press", " bench\npress "]),
            WorkoutTemplate(name: "Empty Template", exercises: [], notes: ""),
            makeTemplate(name: "Ready Template", exerciseNames: ["Bench Press", "Pull-Up"])
        ]
        viewModel.searchText = "can't start"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Duplicate Only", "Empty Template"]
        )
    }

    func testFetchTemplates_matchesCantStartKeywordWithoutPunctuationOrSpaces() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Duplicate Only", exerciseNames: ["Bench Press", " bench\npress "]),
            WorkoutTemplate(name: "Empty Template", exercises: [], notes: ""),
            makeTemplate(name: "Ready Template", exerciseNames: ["Bench Press", "Pull-Up"])
        ]
        viewModel.searchText = "cantstart"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Duplicate Only", "Empty Template"]
        )
    }

    func testFetchTemplates_matchesCurrentWorkoutKeywordsForOtherwiseReadyTemplatesWhenAnotherWorkoutIsActive() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"]),
            WorkoutTemplate(name: "Empty Template", exercises: [], notes: "")
        ]
        viewModel.searchText = "in progress"

        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Push Day"]
        )
    }

    func testFetchTemplates_matchesTemplateStatusSummaryCopyWhenAnotherWorkoutIsActive() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"]),
            WorkoutTemplate(name: "Empty Template", exercises: [], notes: "")
        ]
        viewModel.searchText = "finish the current workout"

        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Push Day"]
        )
    }

    func testFetchTemplates_doesNotMatchCurrentWorkoutKeywordsWhenNoWorkoutBlocksTemplateStart() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"]),
            WorkoutTemplate(name: "Empty Template", exercises: [], notes: "")
        ]
        viewModel.searchText = "current workout"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            []
        )
    }

    func testFetchTemplates_matchesEmptyTemplateKeywords() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            WorkoutTemplate(name: "Empty Template", exercises: [], notes: ""),
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"])
        ]
        viewModel.searchText = "empty"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Empty Template"]
        )
    }

    func testFetchTemplates_matchesTemplateDisabledHelperCopyForEmptyTemplates() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            WorkoutTemplate(name: "Empty Template", exercises: [], notes: ""),
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"])
        ]
        viewModel.searchText = "add at least one exercise before starting"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Empty Template"]
        )
    }

    func testFetchTemplates_matchesPartialStartConfirmationCopy() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(
            name: "Available Press \(UUID().uuidString)",
            category: .compound,
            primaryMuscleGroups: [.chest]
        )
        context.insert(availableExercise)
        try context.save()
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(
                name: "Partial Template",
                exerciseNames: [availableExercise.name, "Missing Row \(UUID().uuidString)"]
            ),
            makeTemplate(name: "Ready Template", exerciseNames: [availableExercise.name])
        ]
        viewModel.searchText = "remaining 1 unique available exercise"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Partial Template"]
        )
    }

    func testFetchTemplates_matchesVisibleTemplateDetailIssueAndSectionCopy() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(
            name: "Available Press \(UUID().uuidString)",
            category: .compound,
            primaryMuscleGroups: [.chest]
        )
        context.insert(availableExercise)
        try context.save()
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(
                name: "Partial Template",
                exerciseNames: [availableExercise.name, "Missing Row \(UUID().uuidString)"]
            ),
            makeTemplate(name: "Repeated Template", exerciseNames: [availableExercise.name, "  \(availableExercise.name)  "]),
            makeTemplate(name: "Ready Template", exerciseNames: [availableExercise.name])
        ]

        viewModel.searchText = "missing from library"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Partial Template"])

        viewModel.searchText = "ready right now"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Partial Template"])

        viewModel.searchText = "included when this workout starts"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Partial Template"])

        viewModel.searchText = "only the first copy will be added"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Repeated Template"])
    }

    func testFetchTemplates_prioritizesNameMatchesBeforeExerciseMatches() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Row Focus", exerciseNames: ["Bench Press"]),
            makeTemplate(name: "Pull Day", exerciseNames: ["Cable Row"]),
            makeTemplate(name: "Conditioning", exerciseNames: ["Farmer Row Carry"], notes: "Row intervals finisher")
        ]
        viewModel.searchText = "row"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Row Focus", "Pull Day", "Conditioning"]
        )
    }

    func testFetchTemplates_prioritizesDirectNameMatchesBeforeCompactedMatches() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Bench Press", exerciseNames: ["Squat"]),
            makeTemplate(name: "Benchpress Accessories", exerciseNames: ["Row"])
        ]
        viewModel.searchText = "benchpress"

        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Benchpress Accessories", "Bench Press"]
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

    func testActiveWorkoutPromptMessage_namesWorkoutAndDestinationTemplate() {
        let viewModel = TemplateViewModel()
        let workout = Workout(name: "Upper A")
        let template = makeTemplate(name: "Lower Day", exerciseNames: ["Squat"])

        XCTAssertEqual(
            viewModel.activeWorkoutPromptMessage(for: workout, opening: template),
            "You already have Upper A in progress. Save it for later, discard it, or keep going before opening Lower Day."
        )
    }

    func testActiveWorkoutPromptMessage_fallsBackForGenericWorkoutAndTemplateNames() {
        let viewModel = TemplateViewModel()
        let workout = Workout(name: "   \n  ")
        let template = makeTemplate(name: "   ", exerciseNames: ["Squat"])

        XCTAssertEqual(
            viewModel.activeWorkoutPromptMessage(for: workout, opening: template),
            "You already have a workout in progress. Save it for later, discard it, or keep going before opening this template."
        )
    }

    func testActiveWorkoutBlocksTemplateStartMessage_namesWorkoutAndTemplate() {
        let viewModel = TemplateViewModel()
        let workout = Workout(name: "Upper A")
        let template = makeTemplate(name: "Lower Day", exerciseNames: ["Squat"])

        XCTAssertEqual(
            viewModel.activeWorkoutBlocksTemplateStartMessage(for: workout, opening: template),
            "You already have Upper A in progress. Continue it, save it for later, or discard it before starting Lower Day."
        )
    }

    func testActiveWorkoutBlocksTemplateStartMessage_fallsBackForGenericWorkoutAndTemplateNames() {
        let viewModel = TemplateViewModel()
        let workout = Workout(name: "   ")
        let template = makeTemplate(name: "\n", exerciseNames: ["Squat"])

        XCTAssertEqual(
            viewModel.activeWorkoutBlocksTemplateStartMessage(for: workout, opening: template),
            "You already have a workout in progress. Continue it, save it for later, or discard it before starting this template."
        )
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

    func testCreateWorkoutFromTemplate_returnsCreatedWorkoutWhenManagerSucceeds() {
        let expectedWorkout = Workout(name: "Template Workout")
        let viewModel = TemplateViewModel(templateManager: StubTemplateManager(workoutToReturn: expectedWorkout))
        let template = makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"])

        XCTAssertTrue(viewModel.createWorkoutFromTemplate(template) === expectedWorkout)
    }

    func testCreateWorkoutFromTemplate_returnsNilWhenManagerFailsToPersistWorkout() {
        let viewModel = TemplateViewModel(templateManager: StubTemplateManager(workoutToReturn: nil))
        let template = makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"])

        XCTAssertNil(viewModel.createWorkoutFromTemplate(template))
    }

    private func makeTemplate(
        name: String,
        exerciseNames: [String],
        exerciseNotes: [String]? = nil,
        notes: String = ""
    ) -> WorkoutTemplate {
        WorkoutTemplate(
            name: name,
            exercises: exerciseNames.enumerated().map { index, exerciseName in
                TemplateExercise(
                    exerciseName: exerciseName,
                    suggestedSets: 3,
                    repRanges: [
                        TemplateRepRange(setNumber: 1, minReps: 6, maxReps: 8, percentageOfFirstSet: 1.0)
                    ],
                    notes: exerciseNotes?[safe: index] ?? ""
                )
            },
            notes: notes
        )
    }
}
