import XCTest
@testable import RPT

@MainActor
final class TemplateViewModelSearchTests: XCTestCase {
    func testSearchPrompt_teachesInstructionCuesAlongsideBodyRegionsAndMovementTypes() {
        XCTAssertEqual(
            TemplateViewModel.searchPrompt,
            "Search templates, notes, exercises, muscle groups, instruction cues, body regions, or movement types"
        )
    }

    func testNoMatchesDescription_teachesInstructionCuesAlongsideBodyRegionsAndMovementTypes() {
        let viewModel = TemplateViewModel()
        viewModel.searchText = "legs"

        XCTAssertEqual(
            viewModel.noMatchesDescription(),
            "No template matches “legs”. Search by name, notes, exercise, muscle group, instruction cue, body region, or movement type."
        )
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
            WorkoutTemplate(name: "Pull Day", exercises: [TemplateExercise(exerciseName: bodyweightExercise.name)]),
            WorkoutTemplate(name: "Arm Day", exercises: [TemplateExercise(exerciseName: isolationExercise.name)])
        ]

        viewModel.searchText = "bodyweight"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Pull Day"])

        viewModel.searchText = "isolation"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Arm Day"])
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
            WorkoutTemplate(name: "Leg Day", exercises: [TemplateExercise(exerciseName: squat.name)]),
            WorkoutTemplate(name: "Core Day", exercises: [TemplateExercise(exerciseName: plank.name)])
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
            WorkoutTemplate(name: "Press Day", exercises: [TemplateExercise(exerciseName: bench.name)])
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
            WorkoutTemplate(name: "Push Focus", exercises: [TemplateExercise(exerciseName: bench.name)]),
            WorkoutTemplate(name: "Leg Focus", exercises: [TemplateExercise(exerciseName: squat.name)])
        ]

        viewModel.searchText = "bench chest"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Push Focus"])

        viewModel.searchText = "legs squat"
        XCTAssertEqual(viewModel.filteredTemplates.map(\.name), ["Leg Focus"])
    }
}
