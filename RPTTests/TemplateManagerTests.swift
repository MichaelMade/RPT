import XCTest
import SwiftData
@testable import RPT

@MainActor
final class TemplateManagerTests: XCTestCase {
    private final class FailingDataManager: DataManaging {
        private let wrappedContext: ModelContext

        init(context: ModelContext) {
            self.wrappedContext = context
        }

        func getModelContext() -> ModelContext {
            wrappedContext
        }

        func saveChanges() throws {
            throw DataManager.DataError.saveFailed
        }
    }

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

    func testMutationResult_missingNameUsesSpecificAlertCopy() {
        XCTAssertEqual(TemplateManager.MutationResult.missingName.alertTitle, "Template Name Required")
        XCTAssertEqual(
            TemplateManager.MutationResult.missingName.alertMessage,
            "Enter a template name before saving this workout plan."
        )
    }

    func testMutationResult_noExercisesUsesSpecificAlertCopy() {
        XCTAssertEqual(TemplateManager.MutationResult.noExercises.alertTitle, "Add an Exercise First")
        XCTAssertEqual(
            TemplateManager.MutationResult.noExercises.alertMessage,
            "Add at least one exercise before saving this template."
        )
    }

    func testMutationResult_duplicateExerciseUsesSpecificAlertCopy() {
        XCTAssertEqual(TemplateManager.MutationResult.duplicateExercise.alertTitle, "Duplicate Exercise in Template")
        XCTAssertEqual(
            TemplateManager.MutationResult.duplicateExercise.alertMessage,
            "Each exercise can only appear once in a template. Remove or replace the duplicate entry before saving."
        )
    }

    func testDuplicateExerciseNames_returnsUniqueRepeatedDisplayNamesForDraftExercises() {
        XCTAssertEqual(
            TemplateManager.shared.duplicateExerciseNames(in: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "bench\npress"),
                sampleTemplateExercise(named: "Squat"),
                sampleTemplateExercise(named: "  squat  "),
                sampleTemplateExercise(named: "Bench Press")
            ]),
            ["Bench Press", "Squat"]
        )
    }

    func testDuplicateExerciseMessage_helperNamesRepeatedExercises() {
        XCTAssertEqual(
            TemplateManager.shared.duplicateExerciseMessage(
                for: [
                    sampleTemplateExercise(named: "Bench Press"),
                    sampleTemplateExercise(named: " bench\npress ")
                ],
                style: .helper
            ),
            "Bench Press appears more than once in this template. Remove or replace the extra copy to save."
        )
    }

    func testDuplicateExerciseMessage_alertSummarizesMultipleRepeatedExercises() {
        XCTAssertEqual(
            TemplateManager.shared.duplicateExerciseMessage(
                for: [
                    sampleTemplateExercise(named: "Bench Press"),
                    sampleTemplateExercise(named: " bench\npress "),
                    sampleTemplateExercise(named: "Squat"),
                    sampleTemplateExercise(named: " squat "),
                    sampleTemplateExercise(named: "Row"),
                    sampleTemplateExercise(named: " row ")
                ],
                style: .alert
            ),
            "Bench Press, Squat, and 1 more exercise appear more than once in this template. Remove or replace the duplicate entries before saving."
        )
    }

    func testMutationResult_duplicateNameUsesSpecificAlertCopy() {
        XCTAssertEqual(TemplateManager.MutationResult.duplicateName.alertTitle, "Template Already Exists")
        XCTAssertEqual(
            TemplateManager.MutationResult.duplicateName.alertMessage,
            "A template with this name already exists. Please choose a different name."
        )
    }

    func testCreateTemplate_returnsValidationSpecificFailureForMissingName() {
        let result = TemplateManager.shared.createTemplate(
            name: "   ",
            exercises: [sampleTemplateExercise()],
            notes: ""
        )

        XCTAssertEqual(result, .missingName)
    }

    func testCreateTemplate_returnsValidationSpecificFailureForNoExercises() {
        let result = TemplateManager.shared.createTemplate(
            name: "Upper Body",
            exercises: [],
            notes: ""
        )

        XCTAssertEqual(result, .noExercises)
    }

    func testCreateTemplate_returnsValidationSpecificFailureForDuplicateExercises() {
        let result = TemplateManager.shared.createTemplate(
            name: "Upper Body",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "  bench\npress  ")
            ],
            notes: ""
        )

        XCTAssertEqual(result, .duplicateExercise)
    }

    func testCreateTemplate_failedSaveReturnsPersistenceFailureAndDoesNotPersistTemplate() {
        let context = DataManager.shared.getModelContext()
        let manager = TemplateManager(
            dataManager: FailingDataManager(context: context),
            seedDefaultTemplates: false
        )
        let templateName = "Failure Template \(UUID().uuidString)"

        let result = manager.createTemplate(
            name: templateName,
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )

        XCTAssertEqual(result, .persistenceFailure)
        XCTAssertNil(manager.fetchTemplateByName(templateName))
    }

    func testMutationResult_persistenceFailureUsesRetryAlertCopy() {
        XCTAssertEqual(TemplateManager.MutationResult.persistenceFailure.alertTitle, "Unable to Save Template")
        XCTAssertEqual(
            TemplateManager.MutationResult.persistenceFailure.alertMessage,
            "Your template changes could not be saved right now. Please try again."
        )
    }

    func testDeletionResult_persistenceFailureUsesRetryAlertCopy() {
        XCTAssertEqual(TemplateManager.DeletionResult.persistenceFailure.alertTitle, "Unable to Delete Template")
        XCTAssertEqual(
            TemplateManager.DeletionResult.persistenceFailure.alertMessage,
            "This template could not be deleted right now. Please try again."
        )
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

    func testFetchTemplateByName_matchesWhitespaceAndWidthVariants() throws {
        let context = DataManager.shared.getModelContext()
        let uniqueSuffix = UUID().uuidString
        let template = WorkoutTemplate(
            name: "Upper Body Lookup \(uniqueSuffix)",
            exercises: [sampleTemplateExercise()],
            notes: ""
        )
        context.insert(template)
        XCTAssertNoThrow(try context.save())

        let fetched = TemplateManager.shared.fetchTemplateByName("  Ｕｐｐｅｒ   Ｂｏｄｙ   Ｌｏｏｋｕｐ \(uniqueSuffix)  ")

        XCTAssertEqual(fetched?.id, template.id)

        context.delete(template)
        XCTAssertNoThrow(try context.save())
    }

    func testSourceTemplate_prefersStableIdentifierBeforeNameFallback() throws {
        let context = DataManager.shared.getModelContext()
        let matchingName = "Source Template \(UUID().uuidString)"
        let renamedTemplate = WorkoutTemplate(
            id: "source-template-id-\(UUID().uuidString)",
            name: "Renamed Source Template",
            exercises: [sampleTemplateExercise()],
            notes: ""
        )
        let staleNameTemplate = WorkoutTemplate(
            name: matchingName,
            exercises: [sampleTemplateExercise(named: "Squat")],
            notes: ""
        )
        context.insert(renamedTemplate)
        context.insert(staleNameTemplate)
        XCTAssertNoThrow(try context.save())

        let workout = Workout(
            name: "Push Day",
            startedFromTemplate: matchingName,
            startedFromTemplateID: renamedTemplate.id
        )

        let resolvedTemplate = TemplateManager.shared.sourceTemplate(for: workout)

        XCTAssertEqual(
            resolvedTemplate?.id,
            renamedTemplate.id,
            "Template history should follow the persisted source template identifier before falling back to the remembered name"
        )

        context.delete(staleNameTemplate)
        context.delete(renamedTemplate)
        XCTAssertNoThrow(try context.save())
    }

    func testSourceTemplate_ignoresBlankRememberedTemplateName() throws {
        let context = DataManager.shared.getModelContext()
        let placeholderTemplate = WorkoutTemplate(
            name: "Template",
            exercises: [sampleTemplateExercise()],
            notes: ""
        )
        context.insert(placeholderTemplate)
        XCTAssertNoThrow(try context.save())

        let workout = Workout(name: "Push Day", startedFromTemplate: "   \n   ")

        XCTAssertNil(
            TemplateManager.shared.sourceTemplate(for: workout),
            "Blank remembered template names should not accidentally resolve a real template named Template"
        )

        context.delete(placeholderTemplate)
        XCTAssertNoThrow(try context.save())
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

    func testAddExerciseToTemplate_failedSaveRollsBackInsertedExercise() {
        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )

        let failingManager = TemplateManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            exerciseManager: ExerciseManager.shared,
            seedDefaultTemplates: false
        )

        let didAddExercise = failingManager.addExerciseToTemplate(
            template,
            exerciseName: "Incline Bench Press"
        )

        XCTAssertFalse(didAddExercise)
        XCTAssertEqual(template.exercises.count, 1)
        XCTAssertEqual(template.exercises.first?.exerciseName, "Bench Press")
    }

    func testUpdateTemplateExercise_rejectsNormalizedDuplicateNameAndLeavesOriginalExerciseUntouched() {
        let originalExercise = sampleTemplateExercise(named: "Bench Press")
        let secondExercise = sampleTemplateExercise(named: "Incline Bench Press")
        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [originalExercise, secondExercise],
            notes: ""
        )

        let updatedExercise = TemplateExercise(
            id: originalExercise.id,
            exerciseName: "  incline\nbench   press  ",
            suggestedSets: 4,
            repRanges: [
                TemplateRepRange(setNumber: 1, minReps: 8, maxReps: 10, percentageOfFirstSet: 1.0)
            ],
            notes: "Pause at the bottom"
        )

        let didUpdateExercise = TemplateManager.shared.updateTemplateExercise(
            template,
            exerciseId: originalExercise.id,
            updatedExercise: updatedExercise
        )

        XCTAssertFalse(didUpdateExercise)
        XCTAssertEqual(template.exercises.map(\.exerciseName), ["Bench Press", "Incline Bench Press"])
        XCTAssertEqual(template.exercises[0].suggestedSets, originalExercise.suggestedSets)
        XCTAssertEqual(template.exercises[0].notes, originalExercise.notes)
    }

    func testUpdateTemplateExercise_failedSaveRestoresOriginalExercise() {
        let originalExercise = sampleTemplateExercise(named: "Bench Press")
        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [originalExercise],
            notes: ""
        )

        let updatedExercise = TemplateExercise(
            id: originalExercise.id,
            exerciseName: "Incline Bench Press",
            suggestedSets: 4,
            repRanges: [
                TemplateRepRange(setNumber: 1, minReps: 8, maxReps: 10, percentageOfFirstSet: 1.0)
            ],
            notes: "Pause at the bottom"
        )

        let failingManager = TemplateManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            exerciseManager: ExerciseManager.shared,
            seedDefaultTemplates: false
        )

        let didUpdateExercise = failingManager.updateTemplateExercise(
            template,
            exerciseId: originalExercise.id,
            updatedExercise: updatedExercise
        )

        XCTAssertFalse(didUpdateExercise)
        XCTAssertEqual(template.exercises.count, 1)
        XCTAssertEqual(template.exercises[0].exerciseName, originalExercise.exerciseName)
        XCTAssertEqual(template.exercises[0].suggestedSets, originalExercise.suggestedSets)
        XCTAssertEqual(template.exercises[0].notes, originalExercise.notes)
    }

    func testRemoveExerciseFromTemplate_failedSaveRestoresRemovedExerciseInPlace() {
        let firstExercise = sampleTemplateExercise(named: "Bench Press")
        let secondExercise = sampleTemplateExercise(named: "Pull-Up")
        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [firstExercise, secondExercise],
            notes: ""
        )

        let failingManager = TemplateManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            exerciseManager: ExerciseManager.shared,
            seedDefaultTemplates: false
        )

        let didRemoveExercise = failingManager.removeExerciseFromTemplate(
            template,
            exerciseId: firstExercise.id
        )

        XCTAssertFalse(didRemoveExercise)
        XCTAssertEqual(template.exercises.map(\.exerciseName), ["Bench Press", "Pull-Up"])
    }

    func testUnavailableExerciseNames_returnsOnlyMissingTemplateExercises() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "Incline Dumbbell Press")
            ],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.unavailableExerciseNames(in: template),
            ["Incline Dumbbell Press"]
        )
        XCTAssertEqual(TemplateManager.shared.availableExerciseCount(in: template), 1)
        XCTAssertEqual(TemplateManager.shared.startWorkoutActionTitle(for: template), "Start Partial Template")
        XCTAssertEqual(
            TemplateManager.shared.partialStartConfirmationMessage(for: template),
            "1 template exercise will be skipped for now: Incline Dumbbell Press. Start this workout with the remaining 1 unique available exercise?"
        )

        context.delete(availableExercise)
        XCTAssertNoThrow(try context.save())
    }

    func testDuplicateExerciseNames_returnsUniqueRepeatedDisplayNames() {
        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "  bench\npress  "),
                sampleTemplateExercise(named: "Pull-Up"),
                sampleTemplateExercise(named: "PULL-UP")
            ],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.duplicateExerciseNames(in: template),
            ["Bench Press", "Pull-Up"]
        )
    }

    func testDuplicateExerciseNames_returnsEmptyForUniqueExercises() {
        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "Pull-Up")
            ],
            notes: ""
        )

        XCTAssertTrue(TemplateManager.shared.duplicateExerciseNames(in: template).isEmpty)
    }

    func testStartableExerciseNames_returnsUniqueResolvableNamesInTemplateOrder() throws {
        let context = DataManager.shared.getModelContext()
        let firstExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let secondExercise = Exercise(name: "Pull-Up", category: .compound, primaryMuscleGroups: [.lats])
        context.insert(firstExercise)
        context.insert(secondExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(firstExercise)
            context.delete(secondExercise)
            try? context.save()
        }

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "  bench\npress  "),
                sampleTemplateExercise(named: "Ghost Lift"),
                sampleTemplateExercise(named: "Pull-Up")
            ],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.startableExerciseNames(in: template),
            ["Bench Press", "Pull-Up"]
        )
    }

    func testStartWorkoutActionTitle_usesPartialCopyWhenRepeatedEntriesWillBeSkipped() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "  bench\npress  ")
            ],
            notes: ""
        )

        XCTAssertEqual(TemplateManager.shared.startWorkoutActionTitle(for: template), "Start Partial Template")
        XCTAssertEqual(
            TemplateManager.shared.startWorkoutConfirmationMessage(for: template),
            "Repeated entries for Bench Press will only be added once. Start this workout with the remaining 1 unique available exercise?"
        )

        context.delete(availableExercise)
        XCTAssertNoThrow(try context.save())
    }

    func testIssues_returnsMissingOnlyForUnavailableFirstOccurrence() {
        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [
                sampleTemplateExercise(named: "Ghost Lift"),
                sampleTemplateExercise(named: "Bench Press")
            ],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.issues(for: template, exerciseId: template.exercises[0].id),
            [.missingFromLibrary]
        )
    }

    func testIssues_marksOnlyRepeatedCopyForDuplicateTemplateEntries() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "  bench\npress  ")
            ],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.issues(for: template, exerciseId: template.exercises[0].id),
            []
        )
        XCTAssertEqual(
            TemplateManager.shared.issues(for: template, exerciseId: template.exercises[1].id),
            [.repeatedEntry]
        )
    }

    func testIssues_combinesMissingAndRepeatedForStaleDuplicateCopies() {
        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [
                sampleTemplateExercise(named: "Ghost Lift"),
                sampleTemplateExercise(named: "  ghost\nlift  ")
            ],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.issues(for: template, exerciseId: template.exercises[1].id),
            [.missingFromLibrary, .repeatedEntry]
        )
    }

    func testTemplateListExerciseSummary_showsPlainExerciseCountWhenTemplateIsClean() {
        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "Incline Dumbbell Press")
            ],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.templateListExerciseSummary(for: template),
            "2 exercises"
        )
    }

    func testTemplateListExerciseSummary_callsOutMissingAndRepeatedEntries() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())

        let template = WorkoutTemplate(
            name: "Corrupted Push Day",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: " bench\npress "),
                sampleTemplateExercise(named: "Ghost Lift")
            ],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.templateListExerciseSummary(for: template),
            "1 of 2 unique exercises ready • 1 missing • 1 repeated"
        )

        context.delete(availableExercise)
        XCTAssertNoThrow(try context.save())
    }

    func testTemplateListExerciseSummary_callsOutDuplicateOnlyTemplateInUniqueTerms() {
        let template = WorkoutTemplate(
            name: "Duplicate Only",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "  bench\npress  ")
            ],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.templateListExerciseSummary(for: template),
            "1 unique exercise ready • 1 repeated"
        )
    }

    func testTemplateListExerciseSummary_callsOutEmptyTemplateAsNotStartable() {
        let template = WorkoutTemplate(
            name: "Empty Template",
            exercises: [],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.templateListExerciseSummary(for: template),
            "No exercises yet • add at least 1 to start"
        )
    }

    func testTemplateListExerciseSummary_mentionsActiveWorkoutBlockForOtherwiseReadyTemplate() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.templateListExerciseSummary(for: template, blockedByActiveWorkout: true),
            "1 exercise • workout in progress"
        )
    }

    func testTemplateListExerciseSummary_keepsLegacyCurrentWorkoutPlaceholderGeneric() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )
        let activeWorkout = Workout(name: "Current Workout")

        XCTAssertEqual(
            TemplateManager.shared.templateListExerciseSummary(
                for: template,
                blockedByActiveWorkout: true,
                blockingWorkout: activeWorkout
            ),
            "1 exercise • workout in progress"
        )
    }

    func testTemplateListExerciseSummary_namesSpecificBlockingWorkoutWhenAvailable() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )
        let activeWorkout = Workout(name: "  Upper   A  ")

        XCTAssertEqual(
            TemplateManager.shared.templateListExerciseSummary(
                for: template,
                blockedByActiveWorkout: true,
                blockingWorkout: activeWorkout
            ),
            "1 exercise • “Upper A” in progress"
        )
    }

    func testTemplateListExerciseSummary_doesNotAddActiveWorkoutSuffixWhenTemplateCannotStartAnyway() {
        let template = WorkoutTemplate(
            name: "Empty Template",
            exercises: [],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.templateListExerciseSummary(for: template, blockedByActiveWorkout: true),
            "No exercises yet • add at least 1 to start"
        )
    }

    func testTemplateListPreviewExerciseNames_skipsDuplicateDisplayNamesAndPreservesOrder() {
        let template = WorkoutTemplate(
            name: "Corrupted Push Day",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: " bench\npress "),
                sampleTemplateExercise(named: "Incline Dumbbell Press"),
                sampleTemplateExercise(named: "PULL-UP")
            ],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.templateListPreviewExerciseNames(for: template),
            ["Bench Press", "Incline Dumbbell Press"]
        )
    }

    func testTemplateListPreviewExerciseNames_prioritizesStartableUniqueExercisesBeforeMissingOnes() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = WorkoutTemplate(
            name: "Mixed Availability",
            exercises: [
                sampleTemplateExercise(named: "Ghost Lift"),
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "Phantom Row")
            ],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.templateListPreviewExerciseNames(for: template),
            ["Bench Press", "Ghost Lift"]
        )
    }

    func testTemplateListPreviewExerciseNames_respectsRequestedPreviewCount() {
        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "Incline Dumbbell Press"),
                sampleTemplateExercise(named: "Pull-Up")
            ],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.templateListPreviewExerciseNames(for: template, maxCount: 1),
            ["Bench Press"]
        )
    }

    func testTemplateListHasMoreUniqueExercisesToPreview_ignoresDuplicateRowsWhenDecidingEllipsis() {
        let duplicateOnlyTemplate = WorkoutTemplate(
            name: "Corrupted Push Day",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: " bench\npress ")
            ],
            notes: ""
        )

        XCTAssertFalse(
            TemplateManager.shared.templateListHasMoreUniqueExercisesToPreview(for: duplicateOnlyTemplate),
            "Repeated exercise rows should not force an ellipsis when there are no additional unique preview items."
        )

        let templateWithRealOverflow = WorkoutTemplate(
            name: "Push Day",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "Incline Dumbbell Press"),
                sampleTemplateExercise(named: "Pull-Up")
            ],
            notes: ""
        )

        XCTAssertTrue(
            TemplateManager.shared.templateListHasMoreUniqueExercisesToPreview(for: templateWithRealOverflow),
            "Rows should still show an ellipsis when more unique exercise names exist beyond the preview limit."
        )
    }

    func testPartialStartConfirmationMessage_usesUniqueResolvableExerciseCountForCorruptedDuplicates() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())

        let template = WorkoutTemplate(
            name: "Corrupted Push Day",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: " bench\npress "),
                sampleTemplateExercise(named: "Incline Dumbbell Press")
            ],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.availableExerciseCount(in: template),
            1,
            "Template starts should count only unique resolvable exercises when corrupted duplicates exist"
        )
        XCTAssertEqual(
            TemplateManager.shared.partialStartConfirmationMessage(for: template),
            "1 template exercise will be skipped for now: Incline Dumbbell Press. Start this workout with the remaining 1 unique available exercise?"
        )

        context.delete(availableExercise)
        XCTAssertNoThrow(try context.save())
    }

    func testAvailableExerciseCount_returnsZeroWhenOnlyDuplicateMissingExercisesRemain() {
        let template = WorkoutTemplate(
            name: "Missing Only",
            exercises: [
                sampleTemplateExercise(named: "Ghost Lift"),
                sampleTemplateExercise(named: "  ghost\nlift ")
            ],
            notes: ""
        )

        XCTAssertEqual(TemplateManager.shared.availableExerciseCount(in: template), 0)
        XCTAssertEqual(TemplateManager.shared.startWorkoutActionTitle(for: template), "Can't Start Template")
        XCTAssertEqual(
            TemplateManager.shared.startWorkoutDisabledMessage(for: template),
            "None of this template’s unique exercises are currently available in your library. Restore or replace the missing exercises before starting."
        )
        XCTAssertNil(
            TemplateManager.shared.partialStartConfirmationMessage(for: template),
            "If a corrupted template cannot resolve any unique exercises, partial-start confirmation should not pretend there is anything launchable"
        )
    }

    func testStartWorkoutDisabledMessage_explainsSingleMissingOnlyExercise() {
        let template = WorkoutTemplate(
            name: "Missing Only",
            exercises: [sampleTemplateExercise(named: "Ghost Lift")],
            notes: ""
        )

        XCTAssertEqual(TemplateManager.shared.availableExerciseCount(in: template), 0)
        XCTAssertEqual(TemplateManager.shared.startWorkoutActionTitle(for: template), "Can't Start Template")
        XCTAssertEqual(
            TemplateManager.shared.startWorkoutDisabledMessage(for: template),
            "This template can’t start right now because its only exercise is missing from your library. Restore or replace it before starting."
        )
    }

    func testCanStartWorkout_returnsFalseForEmptyTemplate() {
        let template = WorkoutTemplate(
            name: "Empty Template",
            exercises: [],
            notes: ""
        )

        XCTAssertFalse(TemplateManager.shared.canStartWorkout(for: template))
        XCTAssertEqual(TemplateManager.shared.startWorkoutActionTitle(for: template), "Can't Start Template")
        XCTAssertEqual(
            TemplateManager.shared.startWorkoutDisabledMessage(for: template),
            "This template doesn’t have any exercises yet. Edit it to add at least one exercise before starting."
        )
    }

    func testCanStartWorkout_returnsTrueWhenTemplateHasAtLeastOneResolvableExercise() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )

        XCTAssertTrue(TemplateManager.shared.canStartWorkout(for: template))
        XCTAssertEqual(TemplateManager.shared.startWorkoutActionTitle(for: template), "Start Template")
        XCTAssertEqual(
            TemplateManager.shared.templateDetailStatusSummary(for: template),
            "Ready to start with 1 exercise."
        )
        XCTAssertNil(TemplateManager.shared.partialStartConfirmationMessage(for: template))
    }

    func testTemplateStatusTone_usesBlockedByActiveWorkoutOnlyForOtherwiseReadyTemplate() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.templateStatusTone(for: template, blockedByActiveWorkout: true),
            .blockedByActiveWorkout
        )
    }

    func testTemplateStatusTone_keepsWarningForPartialTemplateEvenWhenCurrentWorkoutBlocksStart() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "Ghost Lift")
            ],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.templateStatusTone(for: template, blockedByActiveWorkout: true),
            .warning
        )
    }

    func testTemplateDetailStatusSummary_mentionsCurrentWorkoutBlockForOtherwiseReadyTemplate() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.templateDetailStatusSummary(for: template, blockedByActiveWorkout: true),
            "Ready to start with 1 exercise. Continue, save, or discard this workout before starting this template."
        )
    }

    func testTemplateDetailStatusSummary_asksNamedEmptyBlockingWorkoutToAddAnExercise() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )
        let activeWorkout = Workout(name: "  Upper   A  ")

        XCTAssertEqual(
            TemplateManager.shared.templateDetailStatusSummary(
                for: template,
                blockedByActiveWorkout: true,
                blockingWorkout: activeWorkout
            ),
            "Ready to start with 1 exercise. Add an exercise to “Upper A” to keep going, save it for later, or discard it before starting this template."
        )
    }

    func testTemplateDetailStatusSummary_keepsLegacyCurrentWorkoutPlaceholderGenericForEmptyBlockingWorkout() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )
        let activeWorkout = Workout(name: "Current Workout")

        XCTAssertEqual(
            TemplateManager.shared.templateDetailStatusSummary(
                for: template,
                blockedByActiveWorkout: true,
                blockingWorkout: activeWorkout
            ),
            "Ready to start with 1 exercise. Add an exercise to keep going, save it for later, or discard this workout before starting this template."
        )
    }

    func testTemplateDetailStatusSummary_keepsContinueLanguageForBlockingWorkoutWithLoggedSets() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )
        let activeWorkout = Workout(name: "Upper A")
        _ = activeWorkout.addSet(exercise: availableExercise, weight: 185, reps: 8)

        XCTAssertEqual(
            TemplateManager.shared.templateDetailStatusSummary(
                for: template,
                blockedByActiveWorkout: true,
                blockingWorkout: activeWorkout
            ),
            "Ready to start with 1 exercise. Continue, save, or discard “Upper A” before starting this template."
        )
    }

    func testStartWorkoutActionTitle_usesCurrentWorkoutLabelWhenAnotherWorkoutBlocksStart() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.startWorkoutActionTitle(for: template, blockedByActiveWorkout: true),
            "Workout In Progress"
        )
    }

    func testStartWorkoutActionTitle_namesSpecificBlockingWorkoutWhenAvailable() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )
        let activeWorkout = Workout(name: "  Upper   A  ")

        XCTAssertEqual(
            TemplateManager.shared.startWorkoutActionTitle(
                for: template,
                blockedByActiveWorkout: true,
                blockingWorkout: activeWorkout
            ),
            "“Upper A” In Progress"
        )
    }

    func testStartWorkoutActionTitle_keepsLegacyCurrentWorkoutPlaceholderGeneric() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())
        defer {
            context.delete(availableExercise)
            try? context.save()
        }

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )
        let activeWorkout = Workout(name: "Current Workout")

        XCTAssertEqual(
            TemplateManager.shared.startWorkoutActionTitle(
                for: template,
                blockedByActiveWorkout: true,
                blockingWorkout: activeWorkout
            ),
            "Workout In Progress"
        )
    }

    func testStartWorkoutActionTitle_keepsCantStartLabelWhenTemplateIsBlockedAndUnavailable() {
        let template = WorkoutTemplate(
            name: "Blocked Template",
            exercises: [sampleTemplateExercise(named: "Ghost Lift")],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.startWorkoutActionTitle(for: template, blockedByActiveWorkout: true),
            "Can't Start Template"
        )
    }

    func testTemplateDetailStatusSummary_doesNotMentionCurrentWorkoutWhenTemplateCannotStartOnItsOwn() {
        let template = WorkoutTemplate(
            name: "Blocked Template",
            exercises: [sampleTemplateExercise(named: "Ghost Lift")],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.templateDetailStatusSummary(for: template, blockedByActiveWorkout: true),
            "This template can’t start right now because its only exercise is missing from your library. Restore or replace it before starting."
        )
    }

    func testPartialStartConfirmationMessage_summarizesSeveralMissingExercises() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "Ghost Lift"),
                sampleTemplateExercise(named: "Phantom Row"),
                sampleTemplateExercise(named: "Missing Curl"),
                sampleTemplateExercise(named: "Lost Press")
            ],
            notes: ""
        )

        XCTAssertEqual(
            TemplateManager.shared.partialStartConfirmationMessage(for: template),
            "4 template exercises will be skipped for now: Ghost Lift, Phantom Row, Missing Curl, and 1 more. Start this workout with the remaining 1 unique available exercise?"
        )

        context.delete(availableExercise)
        XCTAssertNoThrow(try context.save())
    }

    func testTemplateStartHelpers_dedupeStaleDuplicateTemplateExercises() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())

        let firstBench = sampleTemplateExercise(named: "Bench Press")
        let duplicateBench = sampleTemplateExercise(named: "  bench\npress  ")
        let missingGhost = sampleTemplateExercise(named: "Ghost Lift")
        let duplicateGhost = sampleTemplateExercise(named: "  ghost\nlift  ")
        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [
                firstBench,
                duplicateBench,
                missingGhost,
                duplicateGhost
            ],
            notes: ""
        )

        XCTAssertEqual(TemplateManager.shared.unavailableExerciseNames(in: template), ["Ghost Lift"])
        XCTAssertEqual(TemplateManager.shared.availableExerciseCount(in: template), 1)
        XCTAssertEqual(TemplateManager.shared.startWorkoutActionTitle(for: template), "Start Partial Template")
        XCTAssertEqual(
            TemplateManager.shared.templateDetailStatusSummary(for: template),
            "Starts with 1 of 2 unique exercises right now. 1 missing from your library • 1 repeated entry."
        )
        XCTAssertTrue(
            TemplateManager.shared.isExerciseIncludedWhenStartingWorkout(for: template, exerciseId: firstBench.id),
            "The first resolvable unique exercise should be marked as included when the workout starts"
        )
        XCTAssertFalse(
            TemplateManager.shared.isExerciseIncludedWhenStartingWorkout(for: template, exerciseId: duplicateBench.id),
            "Repeated template rows should not be marked as included when only the first occurrence is used"
        )
        XCTAssertFalse(
            TemplateManager.shared.isExerciseIncludedWhenStartingWorkout(for: template, exerciseId: missingGhost.id),
            "Missing exercises should not be marked as included when the workout starts"
        )
        XCTAssertFalse(
            TemplateManager.shared.isExerciseIncludedWhenStartingWorkout(for: template, exerciseId: duplicateGhost.id),
            "Missing repeated exercises should not be marked as included when the workout starts"
        )
        XCTAssertEqual(
            TemplateManager.shared.partialStartConfirmationMessage(for: template),
            "1 template exercise will be skipped for now: Ghost Lift. Repeated entries for Bench Press will only be added once. Start this workout with the remaining 1 unique available exercise?"
        )

        let workout = TemplateManager.shared.createWorkoutFromTemplate(template)
        XCTAssertEqual(workout?.exerciseCount, 1)
        XCTAssertEqual(workout?.sets.count, 1)
        XCTAssertEqual(workout?.sets.first?.exercise?.name, "Bench Press")

        if let workout {
            context.delete(workout)
        }
        context.delete(availableExercise)
        XCTAssertNoThrow(try context.save())
    }

    func testCreateWorkoutFromTemplate_returnsNilWhenNoTemplateExercisesExistInLibrary() {
        let template = WorkoutTemplate(
            name: "Missing Exercises",
            exercises: [sampleTemplateExercise(named: "Ghost Lift")],
            notes: ""
        )

        XCTAssertNil(
            TemplateManager.shared.createWorkoutFromTemplate(template),
            "Starting a template with no resolvable exercises should fail instead of creating an empty workout"
        )
    }

    func testCreateWorkoutFromTemplate_skipsMissingExercisesButStartsWhenAtLeastOneExists() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "Ghost Lift")
            ],
            notes: ""
        )

        let workout = TemplateManager.shared.createWorkoutFromTemplate(template)

        XCTAssertNotNil(workout)
        XCTAssertEqual(workout?.exerciseCount, 1)
        XCTAssertEqual(workout?.sets.count, 1)
        XCTAssertEqual(workout?.sets.first?.exercise?.name, "Bench Press")

        if let workout {
            context.delete(workout)
        }
        context.delete(availableExercise)
        XCTAssertNoThrow(try context.save())
    }

    func testUpdateTemplate_failedSaveRestoresOriginalTemplateState() {
        let context = DataManager.shared.getModelContext()
        let manager = TemplateManager(
            dataManager: FailingDataManager(context: context),
            seedDefaultTemplates: false
        )
        let template = WorkoutTemplate(
            name: "Original Template",
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: "Original notes"
        )
        context.insert(template)
        XCTAssertNoThrow(try context.save())

        let result = manager.updateTemplate(
            template,
            name: "Updated Template",
            exercises: [sampleTemplateExercise(named: "Incline Press")],
            notes: "Updated notes"
        )

        XCTAssertEqual(result, .persistenceFailure)
        XCTAssertEqual(template.name, "Original Template")
        XCTAssertEqual(template.notes, "Original notes")
        XCTAssertEqual(template.exercises.map(\.exerciseName), ["Bench Press"])

        context.delete(template)
        XCTAssertNoThrow(try context.save())
    }

    func testCreateWorkoutFromTemplate_failedSaveReturnsNilAndCleansUpDraftWorkout() throws {
        let context = DataManager.shared.getModelContext()
        let manager = TemplateManager(
            dataManager: FailingDataManager(context: context),
            seedDefaultTemplates: false
        )
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())

        let templateName = "Push Day \(UUID().uuidString)"
        let template = WorkoutTemplate(
            name: templateName,
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )

        let workout = manager.createWorkoutFromTemplate(template)

        XCTAssertNil(workout)
        XCTAssertFalse(
            (try context.fetch(FetchDescriptor<Workout>())).contains { $0.name == templateName && $0.startedFromTemplate == templateName },
            "A failed template start should not leave behind an unsaved workout draft"
        )

        context.delete(availableExercise)
        XCTAssertNoThrow(try context.save())
    }

    func testCreateWorkoutFromTemplate_persistsTemplateIdentifierForRenameSafeHistoryLinks() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())

        let template = WorkoutTemplate(
            id: UUID().uuidString,
            name: "Push Day",
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )

        let workout = try XCTUnwrap(TemplateManager.shared.createWorkoutFromTemplate(template))
        XCTAssertEqual(workout.startedFromTemplate, "Push Day")
        XCTAssertEqual(workout.startedFromTemplateID, template.id)

        context.delete(workout)
        context.delete(availableExercise)
        XCTAssertNoThrow(try context.save())
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
