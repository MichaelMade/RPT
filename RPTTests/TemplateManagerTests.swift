import XCTest
@testable import RPT

@MainActor
final class TemplateManagerTests: XCTestCase {
    func testInitialCompletedAt_returnsDistantPastForIncompleteTemplateSet() {
        let now = Date()

        XCTAssertEqual(
            TemplateManager.initialCompletedAt(weight: 0, reps: 8, fallbackDate: now),
            .distantPast
        )
    }

    func testInitialCompletedAt_returnsFallbackDateForCompleteTemplateSet() {
        let now = Date()

        XCTAssertEqual(
            TemplateManager.initialCompletedAt(weight: 185, reps: 8, fallbackDate: now),
            now
        )
    }

    func testNamesCollide_ignoresCaseWhitespaceAndWidthVariants() {
        XCTAssertTrue(TemplateManager.namesCollide("  ＴＥＭＰＬＡＴＥ   A ", "template a"))
    }

    func testNormalizedNameLookupKey_defaultsToStablePOSIXLocale() {
        let value = "İstanbul"

        XCTAssertEqual(
            TemplateManager.normalizedNameLookupKey(value),
            TemplateManager.normalizedNameLookupKey(value, locale: Locale(identifier: "en_US_POSIX"))
        )
    }

    func testWorkoutTemplateInitializer_normalizesNameAndNotes() {
        let template = WorkoutTemplate(
            name: "  Upper   Body\nDay  ",
            exercises: [],
            notes: "\n Rest   2-3\nminutes   between sets  \n"
        )

        XCTAssertEqual(template.name, "Upper Body Day")
        XCTAssertEqual(template.notes, "Rest 2-3 minutes between sets")
    }

    func testWorkoutTemplateNormalizedDisplayNotes_returnsNilForWhitespaceOnly() {
        XCTAssertNil(WorkoutTemplate.normalizedDisplayNotes("  \n  \t  "))
    }

    func testTemplateExerciseInitializer_normalizesNameAndNotes() {
        let exercise = TemplateExercise(
            exerciseName: "  Bench\n   Press  ",
            suggestedSets: 3,
            repRanges: [],
            notes: "\n Focus   on\ncontrol   "
        )

        XCTAssertEqual(exercise.exerciseName, "Bench Press")
        XCTAssertEqual(exercise.notes, "Focus on control")
    }

    func testTemplateExerciseInitializer_fallsBackForBlankName() {
        let exercise = TemplateExercise(
            exerciseName: "   \n   ",
            suggestedSets: 1,
            repRanges: [],
            notes: ""
        )

        XCTAssertEqual(exercise.exerciseName, "Exercise")
    }
}
