import XCTest
@testable import RPT

@MainActor
final class TemplateViewModelSearchTests: XCTestCase {
    /// Unique suffix with no digits, so numeric search queries can't
    /// accidentally substring-match it.
    private static func lettersOnlySuffix(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyz"
        return String((0..<length).compactMap { _ in letters.randomElement() })
    }

    func testInitializationDefersTemplateFetchUntilViewAppears() {
        let viewModel = TemplateViewModel()

        XCTAssertTrue(viewModel.templates.isEmpty)
    }

    func testSearchPrompt_teachesCustomMovesAlongsidePushPullSplitsAndRepPlans() {
        XCTAssertEqual(
            TemplateViewModel.searchPrompt,
            "Search templates, notes, exercises, custom moves, muscle groups, push/pull splits, set/rep plans, instruction cues, body regions, or movement types"
        )
    }

    func testNoMatchesDescription_teachesCustomExercisesAlongsidePushPullSplitsAndRepPlans() {
        let viewModel = TemplateViewModel()
        viewModel.searchText = "legs"

        XCTAssertEqual(
            viewModel.noMatchesDescription(),
            "No template matches “legs”. Search by name, notes, exercise, custom exercise, muscle group, push/pull split, set/rep plan, instruction cue, body region, or movement type."
        )
    }

    func testFilteredTemplates_matchesCustomExerciseAliases() throws {
        let context = DataManager.shared.getModelContext()
        let customExercise = Exercise(
            name: "Template Custom Cable Fly \(UUID().uuidString)",
            category: .isolation,
            primaryMuscleGroups: [.chest],
            isCustom: true
        )
        let standardExercise = Exercise(
            name: "Template Standard Bench \(UUID().uuidString)",
            category: .compound,
            primaryMuscleGroups: [.chest]
        )
        context.insert(customExercise)
        context.insert(standardExercise)
        try context.save()
        defer {
            context.delete(customExercise)
            context.delete(standardExercise)
            try? context.save()
        }

        let viewModel = TemplateViewModel()
        viewModel.templates = [
            WorkoutTemplate(name: "Custom Accessories", exercises: [TemplateExercise(exerciseName: customExercise.name, suggestedSets: 3, repRanges: [])]),
            WorkoutTemplate(name: "Press Day", exercises: [TemplateExercise(exerciseName: standardExercise.name, suggestedSets: 3, repRanges: [])])
        ]

        viewModel.searchText = "custom"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Custom Accessories"])

        viewModel.searchText = "my exercise"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Custom Accessories"])
    }

    func testFilteredTemplates_matchesExerciseCategoryAliases() throws {
        let context = DataManager.shared.getModelContext()
        let bodyweightExercise = Exercise(
            name: "Search Alias Pull-Up \(UUID().uuidString)",
            category: .bodyweight,
            primaryMuscleGroups: [.back]
        )
        let isolationExercise = Exercise(
            name: "Search Alias Curl \(UUID().uuidString)",
            category: .isolation,
            primaryMuscleGroups: [.biceps]
        )
        context.insert(bodyweightExercise)
        context.insert(isolationExercise)
        try context.save()
        defer {
            context.delete(bodyweightExercise)
            context.delete(isolationExercise)
            try? context.save()
        }

        let viewModel = TemplateViewModel()
        viewModel.templates = [
            WorkoutTemplate(name: "Pull Day", exercises: [TemplateExercise(exerciseName: bodyweightExercise.name, suggestedSets: 3, repRanges: [])]),
            WorkoutTemplate(name: "Arm Day", exercises: [TemplateExercise(exerciseName: isolationExercise.name, suggestedSets: 3, repRanges: [])])
        ]

        viewModel.searchText = "bodyweight"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Pull Day"])

        viewModel.searchText = "isolation"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Arm Day"])
    }

    func testFilteredTemplates_matchesPushAndPullAliases() throws {
        let context = DataManager.shared.getModelContext()
        let bench = Exercise(
            name: "Search Push Bench \(UUID().uuidString)",
            category: .compound,
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.triceps]
        )
        let row = Exercise(
            name: "Search Pull Row \(UUID().uuidString)",
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
            WorkoutTemplate(name: "Push Day", exercises: [TemplateExercise(exerciseName: bench.name, suggestedSets: 3, repRanges: [])]),
            WorkoutTemplate(name: "Pull Day", exercises: [TemplateExercise(exerciseName: row.name, suggestedSets: 3, repRanges: [])])
        ]

        viewModel.searchText = "push"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Push Day"])

        viewModel.searchText = "pull"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Pull Day"])
    }

    func testFilteredTemplates_matchesBodyRegionAliases() throws {
        let context = DataManager.shared.getModelContext()
        let squat = Exercise(
            name: "Search Alias Squat \(UUID().uuidString)",
            category: .compound,
            primaryMuscleGroups: [.quadriceps],
            secondaryMuscleGroups: [.glutes]
        )
        let plank = Exercise(
            name: "Search Alias Plank \(UUID().uuidString)",
            category: .bodyweight,
            primaryMuscleGroups: [.abs],
            secondaryMuscleGroups: [.obliques]
        )
        context.insert(squat)
        context.insert(plank)
        try context.save()
        defer {
            context.delete(squat)
            context.delete(plank)
            try? context.save()
        }

        let viewModel = TemplateViewModel()
        viewModel.templates = [
            WorkoutTemplate(name: "Leg Day", exercises: [TemplateExercise(exerciseName: squat.name, suggestedSets: 3, repRanges: [])]),
            WorkoutTemplate(name: "Core Day", exercises: [TemplateExercise(exerciseName: plank.name, suggestedSets: 3, repRanges: [])])
        ]

        viewModel.searchText = "legs"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Leg Day"])

        viewModel.searchText = "core"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Core Day"])
    }

    func testFilteredTemplates_matchesInstructionCuesFromExerciseLibrary() throws {
        let context = DataManager.shared.getModelContext()
        let bench = Exercise(
            name: "Search Cue Bench \(UUID().uuidString)",
            category: .compound,
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.triceps],
            instructions: "Drive elbows back and pause on the chest."
        )
        context.insert(bench)
        try context.save()
        defer {
            context.delete(bench)
            try? context.save()
        }

        let viewModel = TemplateViewModel()
        viewModel.templates = [
            WorkoutTemplate(name: "Press Day", exercises: [TemplateExercise(exerciseName: bench.name, suggestedSets: 3, repRanges: [])])
        ]

        viewModel.searchText = "drive elbows back"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Press Day"])
    }

    func testFilteredTemplates_matchesCombinedTermsAcrossExerciseAndMuscleMetadata() throws {
        let context = DataManager.shared.getModelContext()
        let bench = Exercise(
            name: "Search Combo Bench \(UUID().uuidString)",
            category: .compound,
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.triceps]
        )
        let squat = Exercise(
            name: "Search Combo Squat \(UUID().uuidString)",
            category: .compound,
            primaryMuscleGroups: [.quadriceps],
            secondaryMuscleGroups: [.glutes]
        )
        context.insert(bench)
        context.insert(squat)
        try context.save()
        defer {
            context.delete(bench)
            context.delete(squat)
            try? context.save()
        }

        let viewModel = TemplateViewModel()
        viewModel.templates = [
            WorkoutTemplate(name: "Push Focus", exercises: [TemplateExercise(exerciseName: bench.name, suggestedSets: 3, repRanges: [])]),
            WorkoutTemplate(name: "Leg Focus", exercises: [TemplateExercise(exerciseName: squat.name, suggestedSets: 3, repRanges: [])])
        ]

        viewModel.searchText = "bench chest"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Push Focus"])

        viewModel.searchText = "legs squat"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Leg Focus"])
    }

    func testFilteredTemplates_matchesSetAndRepPlanAliases() throws {
        let context = DataManager.shared.getModelContext()
        // Letters-only unique suffixes: numeric queries like "3 sets" must not
        // accidentally substring-match digits inside a generated name.
        let bench = Exercise(
            name: "Search Rep Plan Bench \(Self.lettersOnlySuffix())",
            category: .compound,
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.triceps]
        )
        let row = Exercise(
            name: "Search Rep Plan Row \(Self.lettersOnlySuffix())",
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
            WorkoutTemplate(
                name: "Strength Focus",
                exercises: [
                    TemplateExercise(
                        exerciseName: bench.name,
                        suggestedSets: 5,
                        repRanges: [
                            TemplateRepRange(setNumber: 1, minReps: 5, maxReps: 5),
                            TemplateRepRange(setNumber: 2, minReps: 5, maxReps: 5),
                            TemplateRepRange(setNumber: 3, minReps: 5, maxReps: 5),
                            TemplateRepRange(setNumber: 4, minReps: 5, maxReps: 5),
                            TemplateRepRange(setNumber: 5, minReps: 5, maxReps: 5)
                        ]
                    )
                ]
            ),
            WorkoutTemplate(
                name: "Hypertrophy Focus",
                exercises: [
                    TemplateExercise(
                        exerciseName: row.name,
                        suggestedSets: 3,
                        repRanges: [
                            TemplateRepRange(setNumber: 1, minReps: 8, maxReps: 10),
                            TemplateRepRange(setNumber: 2, minReps: 10, maxReps: 12),
                            TemplateRepRange(setNumber: 3, minReps: 12, maxReps: 15)
                        ]
                    )
                ]
            )
        ]

        viewModel.searchText = "5x5"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Strength Focus"])

        viewModel.searchText = "3x8-10"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Hypertrophy Focus"])

        viewModel.searchText = "3 sets"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Hypertrophy Focus"])
    }

    func testFilteredTemplates_matchesHyphenlessExerciseQueries() throws {
        let context = DataManager.shared.getModelContext()
        let pullUp = Exercise(
            name: "Search Alias Pull-up \(UUID().uuidString)",
            category: .bodyweight,
            primaryMuscleGroups: [.back]
        )
        context.insert(pullUp)
        try context.save()
        defer {
            context.delete(pullUp)
            try? context.save()
        }

        let viewModel = TemplateViewModel()
        viewModel.templates = [
            WorkoutTemplate(name: "Travel Pull Day", exercises: [TemplateExercise(exerciseName: pullUp.name, suggestedSets: 3, repRanges: [])])
        ]

        viewModel.searchText = "pullup"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Travel Pull Day"])
    }
}
