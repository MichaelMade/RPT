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

    func testFetchTemplates_matchesExerciseMuscleGroupAliases() throws {
        let context = DataManager.shared.getModelContext()
        let bench = Exercise(
            name: "Bench Search Alias \(UUID().uuidString)",
            category: .compound,
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.triceps, .shoulders]
        )
        let row = Exercise(
            name: "Row Search Alias \(UUID().uuidString)",
            category: .compound,
            primaryMuscleGroups: [.back],
            secondaryMuscleGroups: [.biceps]
        )
        context.insert(bench)
        context.insert(row)
        try context.save()
        defer {
            context.delete(bench)
            context.delete(row)
            try? context.save()
        }

        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Push Day", exerciseNames: [bench.name]),
            makeTemplate(name: "Pull Day", exerciseNames: [row.name])
        ]

        viewModel.searchText = "chest"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Push Day"])

        viewModel.searchText = "biceps"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Pull Day"])
    }

    func testFetchTemplates_matchesExerciseCategoryAliases() throws {
        let context = DataManager.shared.getModelContext()
        let pullUp = Exercise(
            name: "Bodyweight Search Alias \(UUID().uuidString)",
            category: .bodyweight,
            primaryMuscleGroups: [.back]
        )
        let curl = Exercise(
            name: "Isolation Search Alias \(UUID().uuidString)",
            category: .isolation,
            primaryMuscleGroups: [.biceps]
        )
        context.insert(pullUp)
        context.insert(curl)
        try context.save()
        defer {
            context.delete(pullUp)
            context.delete(curl)
            try? context.save()
        }

        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Pull Day", exerciseNames: [pullUp.name]),
            makeTemplate(name: "Arm Day", exerciseNames: [curl.name])
        ]

        viewModel.searchText = "bodyweight"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Pull Day"])

        viewModel.searchText = "isolation"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Arm Day"])
    }

    func testFetchTemplates_matchesExercisePrescriptionTerms() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(
                name: "Strength Day",
                exerciseNames: ["Bench Press"],
                suggestedSets: 4,
                repRangesByExercise: [[
                    TemplateRepRange(setNumber: 1, minReps: 4, maxReps: 6, percentageOfFirstSet: 1.0),
                    TemplateRepRange(setNumber: 2, minReps: 6, maxReps: 8, percentageOfFirstSet: 0.9),
                    TemplateRepRange(setNumber: 3, minReps: 8, maxReps: 10, percentageOfFirstSet: 0.8),
                    TemplateRepRange(setNumber: 4, minReps: 10, maxReps: 12, percentageOfFirstSet: 0.7)
                ]]
            ),
            makeTemplate(name: "Pull Day", exerciseNames: ["Barbell Row"])
        ]

        viewModel.searchText = "4 sets"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Strength Day"])

        viewModel.searchText = "10-12 reps"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Strength Day"])

        viewModel.searchText = "70 of first set"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Strength Day"])
    }

    func testTemplateEditorNavigationTitle_namesExistingTemplate() {
        XCTAssertEqual(
            TemplateViewModel.templateEditorNavigationTitle(isNewTemplate: false, templateName: "  Upper   A  "),
            "Edit “Upper A”"
        )
    }

    func testTemplateEditorNavigationTitle_fallsBackForUnnamedTemplate() {
        XCTAssertEqual(
            TemplateViewModel.templateEditorNavigationTitle(isNewTemplate: false, templateName: " \n\t "),
            "Edit Template"
        )
    }

    func testTemplateDetailNavigationTitle_namesExistingTemplate() {
        XCTAssertEqual(
            TemplateViewModel.templateDetailNavigationTitle(for: "  Upper   A  "),
            "Upper A"
        )
    }

    func testTemplateDetailNavigationTitle_fallsBackForUnnamedTemplate() {
        XCTAssertEqual(
            TemplateViewModel.templateDetailNavigationTitle(for: " \n\t "),
            "Template Details"
        )
    }

    func testTemplateExerciseEditorNavigationTitle_namesConfiguredExercise() {
        XCTAssertEqual(
            TemplateViewModel.templateExerciseEditorNavigationTitle(for: "  Romanian   Deadlift  "),
            "Configure “Romanian Deadlift”"
        )
    }

    func testTemplateExerciseEditorNavigationTitle_fallsBackForUnnamedExercise() {
        XCTAssertEqual(
            TemplateViewModel.templateExerciseEditorNavigationTitle(for: " \n\t "),
            "Configure Exercise"
        )
    }

    func testTemplateSaveFailureAlertTitle_namesSpecificTemplate() {
        XCTAssertEqual(
            TemplateViewModel.templateSaveFailureAlertTitle(for: "  Upper   A  "),
            "Couldn’t Save Template “Upper A”"
        )
    }

    func testTemplateSaveFailureAlertTitle_fallsBackForUnnamedTemplate() {
        XCTAssertEqual(
            TemplateViewModel.templateSaveFailureAlertTitle(for: " \n\t "),
            "Couldn’t Save This Template"
        )
    }

    func testFetchTemplates_matchesEditTemplateRecoveryCopyForBrokenTemplates() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Empty Draft", exerciseNames: []),
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"])
        ]

        viewModel.searchText = "edit template"

        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Empty Draft"])
    }

    func testFetchTemplates_matchesResumeCurrentWorkoutWhenActiveWorkoutExistsEvenIfTemplateNeedsRepair() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Ghost Day", exerciseNames: ["Ghost Lift"]),
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"])
        ]

        viewModel.searchText = "resume current workout"

        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Ghost Day", "Push Day"]
        )
    }

    func testFetchTemplates_matchesSaveAndOpenTemplateRecoveryCopyWhenActiveWorkoutExistsEvenIfTemplateNeedsRepair() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Ghost Day", exerciseNames: ["Ghost Lift"]),
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"])
        ]

        viewModel.searchText = "save and open template"

        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Ghost Day", "Push Day"]
        )
    }

    func testFetchTemplates_matchesThisWorkoutBlockedStartGuidanceWhenActiveWorkoutExists() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Ghost Day", exerciseNames: ["Ghost Lift"]),
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"])
        ]

        viewModel.searchText = "continue, save, or discard this workout before starting this template"

        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Ghost Day", "Push Day"]
        )
    }

    func testFetchTemplates_matchesGenericContinueWorkoutBlockedStartCTA() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Ghost Day", exerciseNames: ["Ghost Lift"]),
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"])
        ]

        viewModel.searchText = "continue workout"

        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Ghost Day", "Push Day"]
        )
    }

    func testFetchTemplates_matchesGenericDiscardAndStartTemplateAlertTitle() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Upper A", exerciseNames: ["Bench Press"]),
            makeTemplate(name: "Lower Day", exerciseNames: ["Squat"])
        ]

        viewModel.searchText = "discard this workout & start template upper a"

        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Upper A"]
        )
    }

    func testFetchTemplates_matchesCurrentStartTemplateCTAForNamedTemplate() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Upper A", exerciseNames: ["Bench Press"]),
            makeTemplate(name: "Lower Day", exerciseNames: ["Squat"])
        ]

        viewModel.searchText = "start template upper a"

        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Upper A"])
    }

    func testFetchTemplates_matchesCurrentPartialStartTemplateCTA() throws {
        let viewModel = TemplateViewModel()
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        viewModel.templates = [
            makeTemplate(name: "Upper A", exerciseNames: ["Bench Press", "Incline Dumbbell Press"]),
            makeTemplate(name: "Lower Day", exerciseNames: ["Squat"])
        ]

        viewModel.searchText = "start partial template upper a"

        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Upper A"])
    }

    func testFetchTemplates_matchesGenericStartThisTemplateCTAForPlaceholderTemplateName() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "   ", exerciseNames: ["Bench Press"]),
            makeTemplate(name: "Lower Day", exerciseNames: ["Squat"])
        ]

        viewModel.searchText = "start this template"

        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["   "])
    }

    func testFetchTemplates_matchesUnavailableExerciseRestoreRecoveryCopy() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Ghost Day", exerciseNames: ["Ghost Lift"]),
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"])
        ]

        viewModel.searchText = "restore ghost lift"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Ghost Day"])

        viewModel.searchText = "replace ghost lift"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Ghost Day"])

        viewModel.searchText = "skipped until restored"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Ghost Day"])

        viewModel.searchText = "missing from library ghost lift"
        XCTAssertEqual(viewModel.fetchTemplates().map(\.name), ["Ghost Day"])
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

        viewModel.searchText = "remove extra copy"
        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Duplicate Template"]
        )

        viewModel.searchText = "repeated entry bench press"
        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Duplicate Template"]
        )
    }

    func testFetchTemplates_matchesQuickActionCopyForNamedTemplateSearches() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Upper Body Push", exerciseNames: ["Bench Press"]),
            makeTemplate(name: "Lower Body", exerciseNames: ["Squat"])
        ]

        viewModel.searchText = "copy upper body"
        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Upper Body Push"]
        )

        viewModel.searchText = "duplicate upper body push"
        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Upper Body Push"]
        )

        viewModel.searchText = "review upper body push"
        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Upper Body Push"]
        )

        viewModel.searchText = "edit upper body push"
        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Upper Body Push"]
        )

        viewModel.searchText = "delete upper body push"
        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Upper Body Push"]
        )

        viewModel.searchText = "start upper body push"
        XCTAssertEqual(
            viewModel.fetchTemplates().map(\.name),
            ["Upper Body Push"]
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

    func testFetchTemplates_matchesSpecificBlockingWorkoutNameWhenAnotherWorkoutIsActive() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"]),
            WorkoutTemplate(name: "Empty Template", exercises: [], notes: "")
        ]
        viewModel.searchText = "upper a in progress"

        XCTAssertEqual(
            viewModel.fetchTemplates(
                blockedByActiveWorkout: true,
                activeWorkout: Workout(name: "  Upper   A  ")
            ).map(\.name),
            ["Push Day"]
        )
    }

    func testFetchTemplates_matchesPartialBlockedStartRecoveryCopy() throws {
        let viewModel = TemplateViewModel()
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        viewModel.templates = [
            makeTemplate(name: "Upper A", exerciseNames: ["Bench Press", "Incline Dumbbell Press"]),
            makeTemplate(name: "Ready Template", exerciseNames: ["Bench Press"])
        ]
        viewModel.searchText = "save & start partial template upper a"

        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Upper A"]
        )
    }

    func testFetchTemplates_matchesPartialBlockedStartAvailablePartCopy() throws {
        let viewModel = TemplateViewModel()
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        viewModel.templates = [
            makeTemplate(name: "Upper A", exerciseNames: ["Bench Press", "Incline Dumbbell Press"]),
            makeTemplate(name: "Ready Template", exerciseNames: ["Bench Press"])
        ]
        viewModel.searchText = "available part of template upper a"

        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Upper A"]
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

    func testFetchTemplates_matchesResumeCurrentWorkoutCopyWhenAnotherWorkoutIsActive() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"]),
            WorkoutTemplate(name: "Empty Template", exercises: [], notes: "")
        ]
        viewModel.searchText = "resume current workout"

        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Push Day"]
        )
    }

    func testFetchTemplates_matchesActiveWorkoutRecoveryCopyWhenAnotherWorkoutIsActive() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"]),
            WorkoutTemplate(name: "Empty Template", exercises: [], notes: "")
        ]

        viewModel.searchText = "save for later"
        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Push Day"]
        )

        viewModel.searchText = "discard workout"
        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Push Day"]
        )

        viewModel.searchText = "save & open template"
        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Push Day"]
        )

        viewModel.searchText = "save and open template"
        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Push Day"]
        )

        viewModel.searchText = "save & start template"
        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Push Day"]
        )

        viewModel.searchText = "save and start template"
        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Push Day"]
        )

        viewModel.searchText = "discard and open template"
        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Push Day"]
        )

        viewModel.searchText = "discard & start template"
        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Push Day"]
        )

        viewModel.searchText = "discard and start template"
        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Push Day"]
        )
    }

    func testFetchTemplates_matchesExactContinueCTAForBlockingWorkoutName() {
        let viewModel = TemplateViewModel()
        let activeWorkout = Workout(name: "Push Day")
        viewModel.templates = [
            makeTemplate(name: "Upper A", exerciseNames: ["Bench Press"]),
            WorkoutTemplate(name: "Empty Template", exercises: [], notes: "")
        ]

        viewModel.searchText = "Continue “Push Day”"

        XCTAssertEqual(
            viewModel.fetchTemplates(
                blockedByActiveWorkout: true,
                activeWorkout: activeWorkout
            ).map(\.name),
            ["Upper A"]
        )
    }

    func testFetchTemplates_matchesExactDiscardAndStartCTAForBlockingWorkoutName() {
        let viewModel = TemplateViewModel()
        let activeWorkout = Workout(name: "Push Day")
        viewModel.templates = [
            makeTemplate(name: "Upper A", exerciseNames: ["Bench Press"]),
            WorkoutTemplate(name: "Empty Template", exercises: [], notes: "")
        ]

        viewModel.searchText = "Discard “Push Day” & Start Template “Upper A”"

        XCTAssertEqual(
            viewModel.fetchTemplates(
                blockedByActiveWorkout: true,
                activeWorkout: activeWorkout
            ).map(\.name),
            ["Upper A"]
        )
    }

    func testFetchTemplates_matchesKeepGoingBeforeOpeningTemplatePromptWhenAnotherWorkoutIsActive() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Lower Day", exerciseNames: ["Squat"]),
            WorkoutTemplate(name: "Empty Template", exercises: [], notes: "")
        ]
        viewModel.searchText = "keep going before opening lower day"

        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Lower Day"]
        )
    }

    func testFetchTemplates_matchesContinueItBeforeStartingTemplatePromptWhenAnotherWorkoutIsActive() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Lower Day", exerciseNames: ["Squat"]),
            WorkoutTemplate(name: "Empty Template", exercises: [], notes: "")
        ]
        viewModel.searchText = "continue it before starting lower day"

        XCTAssertEqual(
            viewModel.fetchTemplates(blockedByActiveWorkout: true).map(\.name),
            ["Lower Day"]
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

    func testEmptyStateDescription_forActiveSearchOnlyMentionsCreateWhenSafe() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"])
        ]

        viewModel.searchText = "  Lower\n Day  "
        XCTAssertEqual(
            viewModel.emptyStateDescription(filteredCount: 0),
            "No templates matched “Lower Day”. Try a different search, clear it to browse every workout template, or search names, exercises, notes, and issue labels like missing or repeated. You can also create a new template from this search."
        )

        viewModel.searchText = "  Push\n Day  "
        XCTAssertEqual(
            viewModel.emptyStateDescription(filteredCount: 0),
            "No templates matched “Push Day”. Try a different search, clear it to browse every workout template, or search names, exercises, notes, and issue labels like missing or repeated."
        )
    }

    func testEmptyStateDescription_withoutSearchUsesFirstRunGuidance() {
        let viewModel = TemplateViewModel()

        XCTAssertEqual(
            viewModel.emptyStateDescription(filteredCount: 0),
            "Create your first workout template to quickly start repeatable RPT sessions."
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

    func testShouldShowSingleTemplateQuickActions_whenSearchNarrowsToOneTemplate() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"]),
            makeTemplate(name: "Pull Day", exerciseNames: ["Barbell Row"])
        ]
        viewModel.searchText = "push"

        XCTAssertTrue(
            viewModel.shouldShowSingleTemplateQuickActions(filteredCount: 1),
            "Search-driven single matches should keep showing the visible quick actions card"
        )
        XCTAssertFalse(viewModel.shouldShowSingleTemplateQuickActions(filteredCount: 2))
    }

    func testShouldShowSingleTemplateQuickActions_whenOnlyOneTemplateExistsWithoutSearch() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"])
        ]

        XCTAssertTrue(
            viewModel.shouldShowSingleTemplateQuickActions(filteredCount: 1),
            "A lone saved template should surface visible quick actions even before the user discovers swipe gestures"
        )

        viewModel.templates.append(makeTemplate(name: "Pull Day", exerciseNames: ["Barbell Row"]))
        XCTAssertFalse(
            viewModel.shouldShowSingleTemplateQuickActions(filteredCount: 1),
            "Browse-mode quick actions should stay reserved for the one-template case to avoid cluttering larger lists"
        )
    }

    func testSuggestedTemplateNameForEmptySearch_usesNormalizedActiveSearchTextOnlyWhenNoResultsRemain() {
        let viewModel = TemplateViewModel()
        viewModel.searchText = "  Upper\n Body  "

        XCTAssertEqual(
            viewModel.suggestedTemplateNameForEmptySearch(filteredCount: 0),
            "Upper Body"
        )
        XCTAssertNil(viewModel.suggestedTemplateNameForEmptySearch(filteredCount: 1))

        viewModel.clearSearch()
        XCTAssertNil(viewModel.suggestedTemplateNameForEmptySearch(filteredCount: 0))
    }

    func testSuggestedTemplateNameFromSearch_ignoresExistingTemplateNameCollisions() {
        let viewModel = TemplateViewModel()
        viewModel.templates = [
            makeTemplate(name: "Upper Body", exerciseNames: ["Bench Press"]),
            makeTemplate(name: "Upper Body Push", exerciseNames: ["Overhead Press"])
        ]

        viewModel.searchText = "  upper\n body  "
        XCTAssertNil(viewModel.suggestedTemplateNameFromSearch())
        XCTAssertFalse(viewModel.shouldShowCreateTemplateFromSearchAction(filteredCount: 1))

        viewModel.searchText = "upper"
        XCTAssertEqual(viewModel.suggestedTemplateNameFromSearch(), "upper")
        XCTAssertTrue(viewModel.shouldShowCreateTemplateFromSearchAction(filteredCount: 2))
    }

    func testCreateTemplateRecoveryTitle_formatsNormalizedSearchText() {
        let viewModel = TemplateViewModel()
        viewModel.searchText = "  Lower\n Day  "

        XCTAssertEqual(
            viewModel.createTemplateRecoveryTitle(filteredCount: 0),
            "Create “Lower Day”"
        )
        XCTAssertEqual(
            viewModel.createTemplateRecoveryTitle(filteredCount: 2),
            "Create “Lower Day”"
        )
    }

    func testPreferredNewTemplatePrefillName_reusesSearchWhenSafe() {
        let viewModel = TemplateViewModel()
        viewModel.searchText = "  Lower\n Day  "

        XCTAssertEqual(viewModel.preferredNewTemplatePrefillName(), "Lower Day")

        viewModel.templates = [
            makeTemplate(name: "Lower Day", exerciseNames: ["Squat"])
        ]

        XCTAssertEqual(viewModel.preferredNewTemplatePrefillName(), "")

        viewModel.clearSearch()
        XCTAssertEqual(viewModel.preferredNewTemplatePrefillName(), "")
    }

    func testPreferredDuplicateTemplateName_defaultsToCopySuffix() {
        let viewModel = TemplateViewModel()
        let template = makeTemplate(name: "Upper Body", exerciseNames: ["Bench Press"])
        viewModel.templates = [template]

        XCTAssertEqual(
            viewModel.preferredDuplicateTemplateName(for: template),
            "Upper Body Copy"
        )
    }

    func testPreferredDuplicateTemplateName_incrementsUntilUnique() {
        let viewModel = TemplateViewModel()
        let template = makeTemplate(name: "Upper Body", exerciseNames: ["Bench Press"])
        viewModel.templates = [
            template,
            makeTemplate(name: "Upper Body Copy", exerciseNames: ["Incline Press"]),
            makeTemplate(name: "Upper Body Copy 2", exerciseNames: ["Overhead Press"])
        ]

        XCTAssertEqual(
            viewModel.preferredDuplicateTemplateName(for: template),
            "Upper Body Copy 3"
        )
    }

    func testPreferredDuplicateTemplateName_ignoresWhitespaceAndCaseCollisions() {
        let viewModel = TemplateViewModel()
        let template = makeTemplate(name: "Upper Body", exerciseNames: ["Bench Press"])
        viewModel.templates = [
            template,
            makeTemplate(name: " upper   body copy ", exerciseNames: ["Incline Press"])
        ]

        XCTAssertEqual(
            viewModel.preferredDuplicateTemplateName(for: template),
            "Upper Body Copy 2"
        )
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
            "You already have “Upper A” in progress: Started just now • No exercises added yet. Add an exercise to keep going, save it for later, or discard it before opening Template “Lower Day”."
        )
    }

    func testActiveWorkoutPromptMessage_guidesEmptyDraftToAddExerciseBeforeOpeningTemplate() {
        let viewModel = TemplateViewModel()
        let workout = Workout(name: "   ")
        let template = makeTemplate(name: "\n", exerciseNames: ["Squat"])

        XCTAssertEqual(
            viewModel.activeWorkoutPromptMessage(for: workout, opening: template),
            "You already have a workout in progress: Started just now • No exercises added yet. Add an exercise to keep going, save it for later, or discard it before opening this template."
        )
    }

    func testActiveWorkoutBlocksTemplateStartMessage_namesWorkoutAndTemplate() {
        let viewModel = TemplateViewModel()
        let workout = Workout(name: "Upper A")
        let template = makeTemplate(name: "Lower Day", exerciseNames: ["Squat"])

        XCTAssertEqual(
            viewModel.activeWorkoutBlocksTemplateStartMessage(for: workout, opening: template),
            "You already have “Upper A” in progress: Started just now • No exercises added yet. Add an exercise to keep going, save it for later, or discard it before starting Template “Lower Day”."
        )
    }

    func testActiveWorkoutBlocksTemplateStartMessage_guidesEmptyDraftToAddExerciseBeforeStartingTemplate() {
        let viewModel = TemplateViewModel()
        let workout = Workout(name: "   ")
        let template = makeTemplate(name: "\n", exerciseNames: ["Squat"])

        XCTAssertEqual(
            viewModel.activeWorkoutBlocksTemplateStartMessage(for: workout, opening: template),
            "You already have a workout in progress: Started just now • No exercises added yet. Add an exercise to keep going, save it for later, or discard it before starting this template."
        )
    }

    func testActiveWorkoutBlocksTemplateStartMessage_mentionsAvailablePartForPartialTemplate() throws {
        let viewModel = TemplateViewModel()
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let workout = Workout(name: "Upper A")
        let template = makeTemplate(name: "Lower Day", exerciseNames: ["Bench Press", "Incline Dumbbell Press"])

        XCTAssertEqual(
            viewModel.activeWorkoutBlocksTemplateStartMessage(for: workout, opening: template),
            "You already have “Upper A” in progress: Started just now • No exercises added yet. Add an exercise to keep going, save it for later, or discard it before starting the available part of Template “Lower Day”."
        )
    }

    func testStartTemplateFailureAlertTitles_nameSpecificTemplate() {
        let viewModel = TemplateViewModel()
        let template = makeTemplate(name: "  Upper   A  ", exerciseNames: ["Bench Press"])

        XCTAssertEqual(
            viewModel.startTemplateFailureAlertTitle(for: template),
            "Couldn’t Start Template “Upper A”",
            "Direct template-start failures should name the exact plan that could not launch"
        )

        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureAlertTitle(for: .saveForLater, opening: template),
            "Couldn’t Save & Start Template “Upper A”",
            "Save-and-start failures should keep naming the exact template the user was trying to open"
        )

        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureAlertTitle(for: .discard, opening: template),
            "Couldn’t Discard & Start Template “Upper A”",
            "Discard-and-start failures should keep naming the exact template in destructive recovery alerts"
        )
    }

    func testStartTemplateFailureAlertTitles_fallBackForGenericTemplateName() {
        let viewModel = TemplateViewModel()
        let template = makeTemplate(name: "   ", exerciseNames: ["Bench Press"])

        XCTAssertEqual(
            viewModel.startTemplateFailureAlertTitle(for: template),
            "Couldn’t Start This Template",
            "Blank legacy template names should use safe generic start-failure copy"
        )

        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureAlertTitle(for: .saveForLater, opening: template),
            "Couldn’t Save & Start This Template",
            "Blank legacy template names should use safe generic save-and-start copy"
        )

        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureAlertTitle(for: .discard, opening: template),
            "Couldn’t Discard & Start This Template",
            "Blank legacy template names should use safe generic discard-and-start copy"
        )
    }

    func testActiveWorkoutPersistenceFailureMessage_matchesActionContext() {
        let viewModel = TemplateViewModel()

        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureMessage(for: .saveForLater),
            "Couldn’t save this workout. Keep it open, then try starting the template again."
        )

        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureMessage(for: .discard),
            "Couldn’t discard this workout. Keep it open, then try starting the template again."
        )
    }

    func testActiveWorkoutPersistenceFailureMessage_namesCurrentWorkoutAndTemplateWhenAvailable() {
        let viewModel = TemplateViewModel()
        let currentWorkout = Workout(name: "  Push   Day  ")
        let template = makeTemplate(name: "  Upper   A  ", exerciseNames: ["Bench Press"])

        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureMessage(
                for: .saveForLater,
                currentWorkout: currentWorkout,
                opening: template
            ),
            "Couldn’t save “Push Day”. Keep it open, then try starting Template “Upper A” again.",
            "Template restart failures should keep both the live draft and the selected plan visible when recovery fails"
        )

        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureMessage(
                for: .discard,
                currentWorkout: currentWorkout,
                opening: template
            ),
            "Couldn’t discard “Push Day”. Keep it open, then try starting Template “Upper A” again.",
            "Discard restart failures should keep the live draft named in the recovery guidance"
        )
    }

    func testActiveWorkoutPersistenceFailureMessage_staysHonestForPartialTemplateStarts() {
        let viewModel = TemplateViewModel()
        let currentWorkout = Workout(name: "Push Day")
        let template = makeTemplate(name: "Upper A", exerciseNames: ["Bench Press", "Missing Exercise"])

        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureMessage(
                for: .saveForLater,
                currentWorkout: currentWorkout,
                opening: template
            ),
            "Couldn’t save “Push Day”. Keep it open, then try starting the available part of Template “Upper A” again.",
            "Partial-template restart failures should not imply RPT can still start the full original plan"
        )
    }

    func testStartTemplateButtonTitles_useNormalizedTemplateName() {
        let viewModel = TemplateViewModel()
        let template = makeTemplate(name: "  Upper   A  ", exerciseNames: ["Bench Press"])

        XCTAssertEqual(
            viewModel.startTemplateButtonTitle(for: template),
            "Start Template “Upper A”",
            "Template start CTAs should normalize the template name so Home and history actions stay readable"
        )

        XCTAssertEqual(
            viewModel.saveAndStartTemplateButtonTitle(for: template),
            "Save & Start Template “Upper A”",
            "Save-and-start recovery CTAs should name the exact template the user is about to open"
        )

        XCTAssertEqual(
            viewModel.discardAndStartTemplateButtonTitle(for: template),
            "Discard & Start Template “Upper A”",
            "Discard-and-start recovery CTAs should name the exact template so destructive branching stays unmistakable"
        )

        XCTAssertEqual(
            viewModel.discardCurrentWorkoutAndStartTemplateAlertTitle(for: template),
            "Discard This Workout & Start Template “Upper A”?",
            "Template-detail discard confirmations should name the exact template before replacing the active workout"
        )

        XCTAssertEqual(
            viewModel.discardCurrentWorkoutAndStartTemplateAlertMessage(for: template),
            "Your in-progress workout will be lost and RPT will immediately start Template “Upper A”. Source template: 1 exercise and 3 planned sets. This action cannot be undone.",
            "Template-detail discard confirmations should explain both the destructive impact and the template payload before the selected plan starts"
        )

        let currentWorkout = Workout(name: "  Push   Day  ")

        XCTAssertEqual(
            viewModel.saveAndStartTemplateButtonTitle(for: template, currentWorkout: currentWorkout),
            "Save “Push Day” & Start Template “Upper A”",
            "Save-and-start recovery CTAs should name the specific draft that will be saved when that workout is known"
        )

        XCTAssertEqual(
            viewModel.discardAndStartTemplateButtonTitle(for: template, currentWorkout: currentWorkout),
            "Discard “Push Day” & Start Template “Upper A”",
            "Discard-and-start recovery CTAs should name the specific draft that will be replaced when that workout is known"
        )

        XCTAssertEqual(
            viewModel.discardCurrentWorkoutAndStartTemplateAlertTitle(for: template, currentWorkout: currentWorkout),
            "Discard “Push Day” & Start Template “Upper A”?",
            "Template discard confirmations should name the specific draft being replaced when that workout is known"
        )

        XCTAssertEqual(
            viewModel.discardCurrentWorkoutAndStartTemplateAlertMessage(for: template, currentWorkout: currentWorkout),
            "“Push Day” will be lost and RPT will immediately start Template “Upper A”. Source template: 1 exercise and 3 planned sets. This action cannot be undone.",
            "Template discard confirmations should name the exact workout that will be discarded when available"
        )
    }

    func testTemplateActionTitles_fallBackForGenericTemplateName() {
        let viewModel = TemplateViewModel()
        let template = makeTemplate(name: "   ", exerciseNames: ["Bench Press"])

        XCTAssertEqual(viewModel.startTemplateButtonTitle(for: template), "Start This Template")
        XCTAssertEqual(viewModel.quickStartTemplateButtonTitle(for: template), "Start This Template")
        XCTAssertEqual(viewModel.saveAndStartTemplateButtonTitle(for: template), "Save & Start This Template")
        XCTAssertEqual(viewModel.discardAndStartTemplateButtonTitle(for: template), "Discard & Start This Template")
        XCTAssertEqual(viewModel.reviewTemplateButtonTitle(for: template), "Review Template")
        XCTAssertEqual(viewModel.editTemplateButtonTitle(for: template), "Edit Template")
        XCTAssertEqual(viewModel.duplicateTemplateButtonTitle(for: template), "Duplicate Template")
        XCTAssertEqual(viewModel.deleteTemplateButtonTitle(for: template), "Delete Template")
        XCTAssertEqual(viewModel.deleteTemplateAlertTitle(for: template), "Delete Template?")
        XCTAssertEqual(
            viewModel.deleteTemplateMessage(for: template),
            "Delete this template? This will remove 1 exercise and 3 planned sets. This action cannot be undone."
        )
        XCTAssertEqual(
            viewModel.deleteTemplateFailureAlertTitle(for: template),
            "Unable to Delete Template"
        )
        XCTAssertEqual(
            viewModel.deleteTemplateFailureMessage(for: template),
            "This template could not be deleted right now. Please try again."
        )
        XCTAssertEqual(
            viewModel.startTemplateFailureAlertTitle(for: template),
            "Couldn’t Start This Template"
        )
        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureAlertTitle(for: .saveForLater, opening: template),
            "Couldn’t Save & Start This Template"
        )
        XCTAssertEqual(
            viewModel.activeWorkoutPersistenceFailureAlertTitle(for: .discard, opening: template),
            "Couldn’t Discard & Start This Template"
        )
    }

    func testStartTemplateButtonTitles_namePartialTemplateStartsConsistently() throws {
        let viewModel = TemplateViewModel()
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = makeTemplate(
            name: "  Upper   A  ",
            exerciseNames: ["Bench Press", "Incline Dumbbell Press"]
        )

        XCTAssertEqual(
            viewModel.startTemplateButtonTitle(for: template),
            "Start Partial Template “Upper A”",
            "Source-template CTAs should warn when a restart will skip unavailable exercises instead of claiming the full template will run"
        )
        XCTAssertEqual(
            viewModel.quickStartTemplateButtonTitle(for: template),
            "Start Partial Template “Upper A”",
            "Quick-start CTAs should stay anchored to the chosen template even when the run will skip unavailable exercises"
        )
    }

    func testStartTemplateButtonTitles_fallBackForGenericPartialTemplateStarts() throws {
        let viewModel = TemplateViewModel()
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = makeTemplate(
            name: "   ",
            exerciseNames: ["Bench Press", "Incline Dumbbell Press"]
        )

        XCTAssertEqual(
            viewModel.startTemplateButtonTitle(for: template),
            "Start Partial Template",
            "Blank legacy source-template CTAs should stay generic while still warning that the run is partial"
        )
        XCTAssertEqual(
            viewModel.quickStartTemplateButtonTitle(for: template),
            "Start Partial Template",
            "Blank legacy template names should keep partial-start CTAs generic instead of surfacing the placeholder label"
        )
    }

    func testPartialTemplateRecoveryTitlesStayExplicit() throws {
        let viewModel = TemplateViewModel()
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = makeTemplate(
            name: "  Upper   A  ",
            exerciseNames: ["Bench Press", "Incline Dumbbell Press"]
        )

        XCTAssertEqual(viewModel.saveAndStartTemplateButtonTitle(for: template), "Save & Start Partial Template “Upper A”")
        XCTAssertEqual(viewModel.discardAndStartTemplateButtonTitle(for: template), "Discard & Start Partial Template “Upper A”")
        XCTAssertEqual(viewModel.discardCurrentWorkoutAndStartTemplateAlertTitle(for: template), "Discard This Workout & Start Partial Template “Upper A”?")
        XCTAssertEqual(viewModel.startTemplateFailureAlertTitle(for: template), "Couldn’t Start Partial Template “Upper A”")
        XCTAssertEqual(viewModel.activeWorkoutPersistenceFailureAlertTitle(for: .saveForLater, opening: template), "Couldn’t Save & Start Partial Template “Upper A”")
        XCTAssertEqual(viewModel.activeWorkoutPersistenceFailureAlertTitle(for: .discard, opening: template), "Couldn’t Discard & Start Partial Template “Upper A”")
        XCTAssertEqual(
            viewModel.discardCurrentWorkoutAndStartTemplateAlertMessage(for: template),
            "Your in-progress workout will be lost and RPT will immediately start the available part of Template “Upper A”. Source template: 2 exercises and 6 planned sets. This action cannot be undone.",
            "Partial template recovery copy should warn that only the available portion of the routine will start when missing exercises are being skipped"
        )

        let currentWorkout = Workout(name: " Push Day ")
        XCTAssertEqual(
            viewModel.saveAndStartTemplateButtonTitle(for: template, currentWorkout: currentWorkout),
            "Save “Push Day” & Start Partial Template “Upper A”"
        )
    }

    func testGenericPartialTemplateRecoveryTitlesStayExplicit() throws {
        let viewModel = TemplateViewModel()
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = makeTemplate(
            name: "   ",
            exerciseNames: ["Bench Press", "Incline Dumbbell Press"]
        )

        XCTAssertEqual(viewModel.saveAndStartTemplateButtonTitle(for: template), "Save & Start Partial Template")
        XCTAssertEqual(viewModel.discardAndStartTemplateButtonTitle(for: template), "Discard & Start Partial Template")
        XCTAssertEqual(viewModel.discardCurrentWorkoutAndStartTemplateAlertTitle(for: template), "Discard This Workout & Start Partial Template?")
        XCTAssertEqual(viewModel.startTemplateFailureAlertTitle(for: template), "Couldn’t Start Partial Template")
        XCTAssertEqual(viewModel.activeWorkoutPersistenceFailureAlertTitle(for: .saveForLater, opening: template), "Couldn’t Save & Start Partial Template")
        XCTAssertEqual(viewModel.activeWorkoutPersistenceFailureAlertTitle(for: .discard, opening: template), "Couldn’t Discard & Start Partial Template")
        XCTAssertEqual(
            viewModel.discardCurrentWorkoutAndStartTemplateAlertMessage(for: template),
            "Your in-progress workout will be lost and RPT will immediately start the available part of this template. Source template: 2 exercises and 6 planned sets. This action cannot be undone.",
            "Blank legacy template names should keep partial-start recovery copy generic while still warning that unavailable exercises will be skipped"
        )
    }

    func testDiscardAndStartTemplateAlertMessage_fallsBackForGenericTemplateName() {
        let viewModel = TemplateViewModel()
        let template = makeTemplate(name: "   ", exerciseNames: ["Bench Press"])

        XCTAssertEqual(
            viewModel.discardCurrentWorkoutAndStartTemplateAlertMessage(for: template),
            "Your in-progress workout will be lost and RPT will immediately start this template. Source template: 1 exercise and 3 planned sets. This action cannot be undone."
        )
    }

    func testDiscardCurrentWorkoutAndStartTemplateConfirmationIncludesNotesSummary() {
        let viewModel = TemplateViewModel()
        let template = makeTemplate(
            name: "Pull Day",
            exerciseNames: ["Barbell Row", "Lat Pulldown"],
            suggestedSets: 2,
            exerciseNotes: ["Keep elbows tucked", ""],
            notes: "Deload week"
        )

        XCTAssertEqual(
            viewModel.discardCurrentWorkoutAndStartTemplateAlertMessage(for: template),
            "Your in-progress workout will be lost and RPT will immediately start Template “Pull Day”. Source template: 2 exercises, 4 planned sets, and exercise notes and template notes. This action cannot be undone.",
            "Discard-and-start template confirmations should call out when the incoming plan includes saved notes the user expects to land in the new draft"
        )
    }

    func testDiscardCurrentWorkoutAndStartTemplateConfirmationFallbackCopy() {
        let viewModel = TemplateViewModel()
        let template = makeTemplate(name: "   ", exerciseNames: ["Bench Press"])

        XCTAssertEqual(
            viewModel.discardCurrentWorkoutAndStartTemplateAlertTitle(for: template),
            "Discard This Workout & Start This Template?",
            "Blank legacy template names should keep a safe generic discard-and-start confirmation title"
        )

        XCTAssertEqual(
            viewModel.discardCurrentWorkoutAndStartTemplateAlertMessage(for: template),
            "Your in-progress workout will be lost and RPT will immediately start this template. Source template: 1 exercise and 3 planned sets. This action cannot be undone.",
            "Blank legacy template names should keep honest generic discard-and-start impact copy while still summarizing the template payload"
        )
    }

    func testContinueCurrentWorkoutButtonTitle_namesSpecificDraftWhenWorkoutHasLoggedOrPlannedWork() {
        let viewModel = TemplateViewModel()
        let workout = Workout(name: "  Upper   A  ")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = workout.addSet(exercise: exercise, weight: 185, reps: 8)

        XCTAssertEqual(
            viewModel.continueCurrentWorkoutButtonTitle(for: workout),
            "Continue “Upper A”",
            "Template-start recovery should keep the continue wording once the draft already contains workout content"
        )
    }

    func testContinueCurrentWorkoutButtonTitle_usesOpenLanguageForEmptyNamedDraft() {
        let viewModel = TemplateViewModel()
        let workout = Workout(name: "  Upper   A  ")

        XCTAssertEqual(
            viewModel.continueCurrentWorkoutButtonTitle(for: workout),
            "Open “Upper A”",
            "Zero-exercise template conflicts should say Open so the safe action reads like reopening the draft before adding anything else"
        )
    }

    func testContinueCurrentWorkoutButtonTitle_fallsBackForGenericDraftName() {
        let viewModel = TemplateViewModel()
        let workout = Workout(name: "   ")

        XCTAssertEqual(
            viewModel.continueCurrentWorkoutButtonTitle(for: workout),
            "Open Workout",
            "Unnamed empty drafts should keep the clearer open-workout wording"
        )
    }

    func testActiveWorkoutInProgressTitle_namesSpecificDraftWhenAvailable() {
        let viewModel = TemplateViewModel()
        let workout = Workout(name: "  Upper   A  ")

        XCTAssertEqual(
            viewModel.activeWorkoutInProgressTitle(for: workout),
            "“Upper A” In Progress",
            "Blocked template states should name the exact in-progress workout when possible"
        )
    }

    func testActiveWorkoutInProgressTitle_fallsBackForGenericDraftName() {
        let viewModel = TemplateViewModel()
        let blankWorkout = Workout(name: "   ")
        let legacyPlaceholderWorkout = Workout(name: "Current Workout")

        XCTAssertEqual(
            viewModel.activeWorkoutInProgressTitle(for: blankWorkout),
            "Workout In Progress",
            "Unnamed drafts should keep the generic blocked-start status label"
        )
        XCTAssertEqual(
            viewModel.activeWorkoutInProgressTitle(for: legacyPlaceholderWorkout),
            "Workout In Progress",
            "Legacy placeholder draft names should keep the generic blocked-start status label"
        )
        XCTAssertEqual(
            viewModel.continueCurrentWorkoutButtonTitle(for: legacyPlaceholderWorkout),
            "Open Workout",
            "Legacy placeholder empty drafts should keep the generic open-workout label"
        )
    }

    func testTemplateActionTitles_nameSpecificTemplate() {
        let viewModel = TemplateViewModel()
        let template = makeTemplate(name: "  Upper   A  ", exerciseNames: ["Bench Press"])

        XCTAssertEqual(
            viewModel.reviewTemplateButtonTitle(for: template),
            "Review “Upper A”",
            "Template review actions should name the exact plan they open"
        )

        XCTAssertEqual(
            viewModel.editTemplateButtonTitle(for: template),
            "Edit “Upper A”",
            "Template edit actions should name the exact plan they modify"
        )

        XCTAssertEqual(
            viewModel.duplicateTemplateButtonTitle(for: template),
            "Duplicate “Upper A”",
            "Template duplicate actions should name the exact plan they copy"
        )

        XCTAssertEqual(
            viewModel.deleteTemplateButtonTitle(for: template),
            "Delete “Upper A”",
            "Template delete actions should name the exact plan so destructive choices stay unmistakable"
        )

        XCTAssertEqual(
            viewModel.deleteTemplateAlertTitle(for: template),
            "Delete “Upper A”?",
            "Template delete confirmations should name the exact plan in the title"
        )

        XCTAssertEqual(
            viewModel.deleteTemplateMessage(for: template),
            "Delete “Upper A”? This will remove 1 exercise and 3 planned sets. This action cannot be undone.",
            "Template delete confirmations should explain exactly which plan content will be removed"
        )

        XCTAssertEqual(
            viewModel.deleteTemplateFailureAlertTitle(for: template),
            "Couldn’t Delete “Upper A”",
            "Template delete failure alerts should keep naming the exact plan that stayed in the list"
        )

        XCTAssertEqual(
            viewModel.deleteTemplateFailureMessage(for: template),
            "“Upper A” is still in your templates. Please try again.",
            "Template delete failure alerts should confirm the plan was not removed"
        )
    }

    func testDeleteTemplateConfirmationFallbackCopy() {
        let viewModel = TemplateViewModel()

        XCTAssertEqual(
            viewModel.deleteTemplateAlertTitle(for: nil),
            "Delete Template?",
            "Missing template context should fall back to a safe generic title"
        )

        XCTAssertEqual(
            viewModel.deleteTemplateMessage(for: nil),
            "Delete this template? This action cannot be undone.",
            "Missing template context should keep a safe generic message"
        )

        XCTAssertEqual(
            viewModel.deleteTemplateFailureAlertTitle(for: nil),
            "Unable to Delete Template",
            "Missing template context should fall back to the generic delete failure title"
        )

        XCTAssertEqual(
            viewModel.deleteTemplateFailureMessage(for: nil),
            "This template could not be deleted right now. Please try again.",
            "Missing template context should keep the generic delete failure guidance"
        )
    }

    func testDeleteTemplateConfirmationMessage_includesSetAndNotesImpact() {
        let viewModel = TemplateViewModel()
        let template = makeTemplate(
            name: "  Pull   Day  ",
            exerciseNames: ["Pull-Up", "Barbell Row"],
            suggestedSets: 2,
            exerciseNotes: ["Pause at top", ""],
            notes: "Keep rest short"
        )

        XCTAssertEqual(
            viewModel.deleteTemplateMessage(for: template),
            "Delete “Pull Day”? This will remove 2 exercises, 4 planned sets, and exercise notes and template notes. This action cannot be undone.",
            "Template delete confirmations should spell out planned-set and note impact before removing a routine"
        )
    }

    func testStartTemplateAfterPersistingActiveWorkout_returnsStartedWorkoutAfterSuccessfulSaveForLater() {
        let expectedWorkout = Workout(name: "Template Workout")
        let viewModel = TemplateViewModel(templateManager: StubTemplateManager(workoutToReturn: expectedWorkout))
        let workoutStateManager = WorkoutStateManager.shared
        workoutStateManager.clearDiscardedState()
        defer { workoutStateManager.clearDiscardedState() }

        let activeWorkout = Workout(name: "Current Workout")
        let template = makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"])

        let result = viewModel.startTemplateAfterPersistingActiveWorkout(
            activeWorkout,
            action: .saveForLater,
            opening: template,
            persist: { _ in true }
        )

        switch result {
        case .success(let startedWorkout):
            XCTAssertTrue(startedWorkout === expectedWorkout)
        case .failure(let message):
            XCTFail("Expected success, got failure: \(message)")
        }

        XCTAssertFalse(workoutStateManager.wasAnyWorkoutDiscarded())
    }

    func testStartTemplateAfterPersistingActiveWorkout_returnsPersistenceFailureMessageWhenDiscardFails() {
        let viewModel = TemplateViewModel(templateManager: StubTemplateManager(workoutToReturn: Workout(name: "Template Workout")))
        let activeWorkout = Workout(name: "Current Workout")
        let template = makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"])

        let result = viewModel.startTemplateAfterPersistingActiveWorkout(
            activeWorkout,
            action: .discard,
            opening: template,
            persist: { _ in false }
        )

        switch result {
        case .success:
            XCTFail("Expected persistence failure")
        case .failure(let message):
            XCTAssertEqual(
                message,
                "Couldn’t discard this workout. Keep it open, then try starting Template “Push Day” again."
            )
        }
    }

    func testStartTemplateAfterPersistingActiveWorkout_returnsStartFailureMessageWhenTemplateCreationFails() {
        let viewModel = TemplateViewModel(templateManager: StubTemplateManager(workoutToReturn: nil))
        let activeWorkout = Workout(name: "Current Workout")
        let template = makeTemplate(name: "Push Day", exerciseNames: ["Bench Press"])

        let result = viewModel.startTemplateAfterPersistingActiveWorkout(
            activeWorkout,
            action: .saveForLater,
            opening: template,
            persist: { _ in true }
        )

        switch result {
        case .success:
            XCTFail("Expected template start failure")
        case .failure(let message):
            XCTAssertEqual(
                message,
                "Your template workout could not be started right now. Please try again."
            )
        }
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
        suggestedSets: Int = 3,
        repRangesByExercise: [[TemplateRepRange]]? = nil,
        exerciseNotes: [String]? = nil,
        notes: String = ""
    ) -> WorkoutTemplate {
        WorkoutTemplate(
            name: name,
            exercises: exerciseNames.enumerated().map { index, exerciseName in
                TemplateExercise(
                    exerciseName: exerciseName,
                    suggestedSets: suggestedSets,
                    repRanges: repRangesByExercise?[safe: index] ?? [
                        TemplateRepRange(setNumber: 1, minReps: 6, maxReps: 8, percentageOfFirstSet: 1.0)
                    ],
                    notes: exerciseNotes?[safe: index] ?? ""
                )
            },
            notes: notes
        )
    }
}
