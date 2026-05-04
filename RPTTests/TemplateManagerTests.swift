import XCTest
@testable import RPT

@MainActor
final class TemplateManagerTests: XCTestCase {
    func testValidateDraft_requiresNonEmptyName() {
        let result = TemplateManager.shared.validateDraft(
            name: "   \n  ",
            exercises: [sampleTemplateExercise()]
        )

        XCTAssertEqual(result, .missingName)
    }

    func testValidateDraft_requiresAtLeastOneExercise() {
        let result = TemplateManager.shared.validateDraft(
            name: "Upper Body",
            exercises: []
        )

        XCTAssertEqual(result, .noExercises)
    }

    func testValidateDraft_acceptsEditableExistingTemplateName() {
        guard let template = TemplateManager.shared.fetchAllTemplates().first else {
            XCTFail("Expected seeded template data")
            return
        }

        let result = TemplateManager.shared.validateDraft(
            name: " \(template.name) ",
            exercises: [sampleTemplateExercise()],
            excludingTemplateId: template.id
        )

        XCTAssertEqual(result, .valid)
    }

    func testValidateDraft_rejectsDuplicateExerciseNames() {
        let result = TemplateManager.shared.validateDraft(
            name: "Upper Body",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "  bench\npress  ")
            ]
        )

        XCTAssertEqual(result, .duplicateExercise)
    }

    func testValidateDraft_rejectsDuplicateNormalizedName() {
        let result = TemplateManager.shared.validateDraft(
            name: "  Ｕｐｐｅｒ   Ｂｏｄｙ   ＲＰＴ  ",
            exercises: [sampleTemplateExercise()]
        )

        XCTAssertEqual(result, .duplicateName)
    }

    func testHasDuplicateExerciseNames_ignoresCaseWhitespaceAndWidthVariants() {
        XCTAssertTrue(
            TemplateManager.hasDuplicateExerciseNames([
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: " ＢＥＮＣＨ   ＰＲＥＳＳ ")
            ])
        )
    }

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

    func testTemplateExerciseInitializer_preservesExistingRepRangesWhenReducingSetCount() {
        let exercise = TemplateExercise(
            exerciseName: "Bench Press",
            suggestedSets: 2,
            repRanges: [
                TemplateRepRange(setNumber: 1, minReps: 4, maxReps: 6, percentageOfFirstSet: 1.0),
                TemplateRepRange(setNumber: 2, minReps: 7, maxReps: 9, percentageOfFirstSet: 0.87),
                TemplateRepRange(setNumber: 3, minReps: 10, maxReps: 12, percentageOfFirstSet: 0.74)
            ],
            notes: ""
        )

        XCTAssertEqual(exercise.repRanges.count, 2)
        XCTAssertEqual(exercise.repRanges[0].minReps, 4)
        XCTAssertEqual(exercise.repRanges[1].minReps, 7)
        XCTAssertEqual(exercise.repRanges[1].maxReps, 9)
        XCTAssertEqual(exercise.repRanges[1].percentageOfFirstSet, 0.87)
    }

    func testTemplateExerciseInitializer_fillsMissingRangesWithoutOverwritingExistingOnes() {
        let exercise = TemplateExercise(
            exerciseName: "Bench Press",
            suggestedSets: 3,
            repRanges: [
                TemplateRepRange(setNumber: 1, minReps: 5, maxReps: 7, percentageOfFirstSet: 1.0),
                TemplateRepRange(setNumber: 3, minReps: 9, maxReps: 11, percentageOfFirstSet: 0.76)
            ],
            notes: ""
        )

        XCTAssertEqual(exercise.repRanges.map(\.setNumber), [1, 2, 3])
        XCTAssertEqual(exercise.repRanges[0].minReps, 5)
        XCTAssertEqual(exercise.repRanges[1].minReps, 8)
        XCTAssertEqual(exercise.repRanges[1].maxReps, 10)
        XCTAssertEqual(exercise.repRanges[1].percentageOfFirstSet, 0.9)
        XCTAssertEqual(exercise.repRanges[2].percentageOfFirstSet, 0.76)
    }

    func testAddExerciseToTemplate_rejectsNormalizedDuplicateNames() {
        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )

        let didAddDuplicate = TemplateManager.shared.addExerciseToTemplate(
            template,
            exerciseName: "  bench\npress  "
        )

        XCTAssertFalse(didAddDuplicate)
        XCTAssertEqual(template.exercises.count, 1)
    }

    func testAddExerciseToTemplate_appendsDefaultExerciseWhenUnique() {
        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )

        let didAddExercise = TemplateManager.shared.addExerciseToTemplate(
            template,
            exerciseName: "Incline Bench Press"
        )

        XCTAssertTrue(didAddExercise)
        XCTAssertEqual(template.exercises.count, 2)
        XCTAssertEqual(template.exercises.last?.exerciseName, "Incline Bench Press")
        XCTAssertEqual(template.exercises.last?.repRanges.map(\.setNumber), [1, 2, 3])
    }

    private func sampleTemplateExercise(named name: String = "Bench Press") -> TemplateExercise {
        TemplateExercise(
            exerciseName: name,
            suggestedSets: 3,
            repRanges: [
                TemplateRepRange(setNumber: 1, minReps: 6, maxReps: 8, percentageOfFirstSet: 1.0)
            ],
            notes: ""
        )
    }
}
