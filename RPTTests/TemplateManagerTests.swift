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
        XCTAssertEqual(TemplateManager.shared.startWorkoutActionTitle(for: template), "Start Partial Workout")
        XCTAssertEqual(
            TemplateManager.shared.partialStartConfirmationMessage(for: template),
            "1 template exercise will be skipped for now: Incline Dumbbell Press. Start this workout with the remaining 1 available exercise?"
        )

        context.delete(availableExercise)
        XCTAssertNoThrow(try context.save())
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
            "1 template exercise will be skipped for now: Incline Dumbbell Press. Start this workout with the remaining 1 available exercise?"
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
        XCTAssertNil(
            TemplateManager.shared.partialStartConfirmationMessage(for: template),
            "If a corrupted template cannot resolve any unique exercises, partial-start confirmation should not pretend there is anything launchable"
        )
    }

    func testStartWorkoutActionTitle_staysDefaultWhenNothingWillBeSkipped() {
        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [sampleTemplateExercise(named: "Bench Press")],
            notes: ""
        )

        XCTAssertEqual(TemplateManager.shared.startWorkoutActionTitle(for: template), "Start Workout")
        XCTAssertNil(TemplateManager.shared.partialStartConfirmationMessage(for: template))
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
            "4 template exercises will be skipped for now: Ghost Lift, Phantom Row, Missing Curl, and 1 more. Start this workout with the remaining 1 available exercise?"
        )

        context.delete(availableExercise)
        XCTAssertNoThrow(try context.save())
    }

    func testTemplateStartHelpers_dedupeStaleDuplicateTemplateExercises() throws {
        let context = DataManager.shared.getModelContext()
        let availableExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        context.insert(availableExercise)
        XCTAssertNoThrow(try context.save())

        let template = WorkoutTemplate(
            name: "Push Day",
            exercises: [
                sampleTemplateExercise(named: "Bench Press"),
                sampleTemplateExercise(named: "  bench\npress  "),
                sampleTemplateExercise(named: "Ghost Lift"),
                sampleTemplateExercise(named: "  ghost\nlift  ")
            ],
            notes: ""
        )

        XCTAssertEqual(TemplateManager.shared.unavailableExerciseNames(in: template), ["Ghost Lift"])
        XCTAssertEqual(TemplateManager.shared.availableExerciseCount(in: template), 1)
        XCTAssertEqual(
            TemplateManager.shared.partialStartConfirmationMessage(for: template),
            "1 template exercise will be skipped for now: Ghost Lift. Start this workout with the remaining 1 available exercise?"
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
