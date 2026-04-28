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
