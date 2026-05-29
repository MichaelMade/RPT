import XCTest
import SwiftData
@testable import RPT

@MainActor
final class ActiveWorkoutViewModelTests: XCTestCase {
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

    private var workoutManager: WorkoutManager!

    override func setUp() {
        super.setUp()
        workoutManager = WorkoutManager.shared
    }

    override func tearDown() {
        workoutManager = nil
        super.tearDown()
    }

    func testUpdateSet_clearingWeightResetsCompletionDate() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let set = workout.addSet(exercise: exercise, weight: 185, reps: 5)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.updateSet(set, weight: 0, reps: 5, rpe: nil)

        // Then
        XCTAssertEqual(set.completedAt, .distantPast)
    }

    func testUpdateSet_rejectsZeroRPE() {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let set = workout.addSet(exercise: exercise, weight: 185, reps: 5)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When / Then
        XCTAssertThrowsError(try viewModel.updateSet(set, weight: 185, reps: 5, rpe: 0))
    }

    func testUpdateSet_clearingRepsResetsCompletionDate() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let set = workout.addSet(exercise: exercise, weight: 185, reps: 5)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.updateSet(set, weight: 185, reps: 0, rpe: nil)

        // Then
        XCTAssertEqual(set.completedAt, .distantPast)
    }

    func testUpdateSet_marksTemplateAutofilledSetCompleteWhenSaved() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Template Workout", fromTemplate: "Push Day")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let set = workout.addSet(exercise: exercise, weight: 185, reps: 8)
        set.completedAt = .distantPast // Simulates prefilled-but-not-yet-logged template set
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.updateSet(set, weight: 185, reps: 8, rpe: nil)

        // Then
        XCTAssertNotEqual(set.completedAt, .distantPast, "Saving a valid autofilled set should mark it complete")
    }

    func testUpdateSet_failedSaveRestoresPriorValues() {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let set = workout.addSet(exercise: exercise, weight: 185, reps: 5)
        let originalCompletedAt = set.completedAt
        let failingWorkoutManager = WorkoutManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            userManager: UserManager.shared
        )
        let viewModel = ActiveWorkoutViewModel(workout: workout, workoutManager: failingWorkoutManager)

        XCTAssertThrowsError(try viewModel.updateSet(set, weight: 205, reps: 6, rpe: 8))
        XCTAssertEqual(set.weight, 185)
        XCTAssertEqual(set.reps, 5)
        XCTAssertNil(set.rpe)
        XCTAssertEqual(set.completedAt, originalCompletedAt)
    }

    func testUpdateWorkoutName_trimsWhitespaceAndFallsBackWhenEmpty() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Original")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        viewModel.workoutName = "   \n\t  "
        try viewModel.updateWorkoutName()

        // Then
        XCTAssertEqual(workout.name, "Workout")
        XCTAssertEqual(viewModel.workoutName, "Workout")
    }

    func testUpdateWorkoutName_normalizesViewModelTextAfterSanitizing() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Original")
        let viewModel = ActiveWorkoutViewModel(workout: workout)
        let longMessyName = "  Upper   Body\nSession   " + String(repeating: "A", count: 100)

        // When
        viewModel.workoutName = longMessyName
        try viewModel.updateWorkoutName()

        // Then
        XCTAssertEqual(viewModel.workoutName, workout.name)
        XCTAssertEqual(viewModel.workoutName, workoutManager.sanitizedWorkoutName(longMessyName))
        XCTAssertEqual(viewModel.workoutName.count, 80)
        XCTAssertFalse(viewModel.workoutName.contains("\n"))
        XCTAssertFalse(viewModel.workoutName.contains("  "))
    }

    func testUpdateWorkoutName_failedSaveRestoresPriorModelAndVisibleFieldValue() {
        let workout = workoutManager.createWorkout(name: "Original")
        let failingWorkoutManager = WorkoutManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            userManager: UserManager.shared
        )
        let viewModel = ActiveWorkoutViewModel(workout: workout, workoutManager: failingWorkoutManager)

        viewModel.workoutName = "  New   Workout Name  "

        XCTAssertThrowsError(try viewModel.updateWorkoutName())
        XCTAssertEqual(workout.name, "Original")
        XCTAssertEqual(viewModel.workoutName, "Original")
    }

    func testUpdateWorkoutNameSafely_failureUsesNamedWorkoutAlertTitle() {
        let workout = workoutManager.createWorkout(name: "Upper A")
        let failingWorkoutManager = WorkoutManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            userManager: UserManager.shared
        )
        let viewModel = ActiveWorkoutViewModel(workout: workout, workoutManager: failingWorkoutManager)

        viewModel.workoutName = "Lower B"

        XCTAssertFalse(viewModel.updateWorkoutNameSafely())
        XCTAssertEqual(viewModel.workoutName, "Upper A")
        XCTAssertEqual(viewModel.errorAlertTitle, "Couldn’t Rename “Upper A”")
        XCTAssertEqual(viewModel.errorMessage, "Couldn’t rename “Upper A” right now. Please try again.")
    }

    func testUpdateWorkoutNameSafely_failureUsesCurrentWorkoutFallbackForBlankNames() {
        let workout = workoutManager.createWorkout(name: "   ")
        let failingWorkoutManager = WorkoutManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            userManager: UserManager.shared
        )
        let viewModel = ActiveWorkoutViewModel(workout: workout, workoutManager: failingWorkoutManager)

        viewModel.workoutName = "Lower B"

        XCTAssertFalse(viewModel.updateWorkoutNameSafely())
        XCTAssertEqual(viewModel.workoutName, "   ")
        XCTAssertEqual(viewModel.errorAlertTitle, "Couldn’t Rename Current Workout")
        XCTAssertEqual(viewModel.errorMessage, "Couldn’t rename the current workout right now. Please try again.")
    }

    func testCompleteWorkoutTitlesIncludeSpecificWorkoutName() {
        let workout = workoutManager.createWorkout(name: "Upper A")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(viewModel.completeWorkoutAlertTitle(), "Complete “Upper A”?")
        XCTAssertEqual(viewModel.finishButtonTitle(), "Finish “Upper A”")
        XCTAssertEqual(viewModel.completeWorkoutButtonTitle(), "Complete “Upper A” & Save")
        XCTAssertEqual(viewModel.continueWorkoutButtonTitle(), "Continue “Upper A”")
        XCTAssertEqual(viewModel.completeWorkoutMessage(), "Would you like to complete and save “Upper A”?")
    }

    func testCompleteWorkoutTitlesFallBackForGenericWorkoutName() {
        let workout = workoutManager.createWorkout(name: "Workout")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(viewModel.completeWorkoutAlertTitle(), "Complete Current Workout?")
        XCTAssertEqual(viewModel.finishButtonTitle(), "Finish Current Workout")
        XCTAssertEqual(viewModel.completeWorkoutButtonTitle(), "Complete Current Workout & Save")
        XCTAssertEqual(viewModel.continueWorkoutButtonTitle(), "Continue Current Workout")
        XCTAssertEqual(viewModel.completeWorkoutMessage(), "Would you like to complete and save your current workout?")
    }

    func testCompleteWorkoutTitlesFallBackForLegacyCurrentWorkoutPlaceholder() {
        let workout = workoutManager.createWorkout(name: "Current Workout")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(viewModel.completeWorkoutAlertTitle(), "Complete Current Workout?")
        XCTAssertEqual(viewModel.finishButtonTitle(), "Finish Current Workout")
        XCTAssertEqual(viewModel.completeWorkoutButtonTitle(), "Complete Current Workout & Save")
        XCTAssertEqual(viewModel.continueWorkoutButtonTitle(), "Continue Current Workout")
        XCTAssertEqual(viewModel.completeWorkoutMessage(), "Would you like to complete and save your current workout?")
    }

    func testDeleteExerciseCopyIncludesSpecificExerciseNameAndWorkoutContext() {
        let workout = workoutManager.createWorkout(name: "Pull")
        let exercise = Exercise(name: "  Bench   Press  ", category: .compound, primaryMuscleGroups: [.chest])
        _ = workout.addSet(exercise: exercise, weight: 185, reps: 5)
        _ = workout.addSet(exercise: exercise, weight: 0, reps: 0)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(viewModel.deleteExerciseAlertTitle(for: exercise), "Delete “Bench Press” from “Pull”?")
        XCTAssertEqual(viewModel.deleteExerciseButtonTitle(for: exercise), "Delete “Bench Press”")
        XCTAssertEqual(
            viewModel.deleteExerciseMessage(for: exercise),
            "Are you sure you want to remove “Bench Press” from “Pull”? This will remove 2 working sets from the workout, including 1 logged working set."
        )
    }

    func testDeleteExerciseCopyFallsBackWithoutSpecificExercise() {
        let workout = workoutManager.createWorkout(name: "Pull")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(viewModel.deleteExerciseAlertTitle(for: nil), "Delete Exercise?")
        XCTAssertEqual(
            viewModel.deleteExerciseMessage(for: nil),
            "Are you sure you want to remove this exercise from the workout? All sets for this exercise will be deleted."
        )
    }

    func testDeleteExerciseCopyFallsBackGracefullyForBlankExerciseNamesWhileKeepingImpactSummary() {
        let workout = workoutManager.createWorkout(name: "Pull")
        let blankExercise = Exercise(name: " \n ", category: .bodyweight, primaryMuscleGroups: [.back])
        _ = workout.addSet(exercise: blankExercise, weight: 0, reps: 12, isWarmup: true)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(viewModel.deleteExerciseAlertTitle(for: blankExercise), "Delete Exercise?")
        XCTAssertEqual(viewModel.deleteExerciseButtonTitle(for: blankExercise), "Delete Exercise")
        XCTAssertEqual(
            viewModel.deleteExerciseMessage(for: blankExercise),
            "Are you sure you want to remove this exercise from the workout? This will remove 1 warm-up set from the workout, including 1 logged warm-up set."
        )
    }

    func testDeleteExerciseCopyKeepsGenericWorkoutFallbackForLegacyPlaceholderNames() {
        let workout = workoutManager.createWorkout(name: "Current Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = workout.addSet(exercise: exercise, weight: 185, reps: 5)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(viewModel.deleteExerciseAlertTitle(for: exercise), "Delete “Bench Press” from Workout?")
        XCTAssertEqual(
            viewModel.deleteExerciseMessage(for: exercise),
            "Are you sure you want to remove “Bench Press” from this workout? This will remove 1 working set from the workout, including 1 logged working set."
        )
    }

    func testDeleteExerciseCopySeparatesWorkingAndWarmupLoggedSetImpact() {
        let workout = workoutManager.createWorkout(name: "Pull")
        let exercise = Exercise(name: "Lat Pulldown", category: .compound, primaryMuscleGroups: [.back])
        _ = workout.addSet(exercise: exercise, weight: 45, reps: 12, isWarmup: true)
        _ = workout.addSet(exercise: exercise, weight: 140, reps: 8)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(
            viewModel.deleteExerciseMessage(for: exercise),
            "Are you sure you want to remove “Lat Pulldown” from this workout? This will remove 2 sets from the workout, including 1 logged working set and 1 logged warm-up set."
        )
    }

    func testDeleteExerciseCopyMentionsUnloggedSetCountWhenNothingHasBeenCompletedYet() {
        let workout = workoutManager.createWorkout(name: "Pull")
        let exercise = Exercise(name: "Lat Pulldown", category: .compound, primaryMuscleGroups: [.back])
        _ = workout.addSet(exercise: exercise, weight: 0, reps: 0)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(
            viewModel.deleteExerciseMessage(for: exercise),
            "Are you sure you want to remove “Lat Pulldown” from this workout? This will remove 1 working set from the workout."
        )
    }

    func testDeleteExerciseCopyMentionsWorkingOnlyDraftSetCountBeforeAnythingIsLogged() {
        let workout = workoutManager.createWorkout(name: "Push")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = workout.addSet(exercise: exercise, weight: 135, reps: 0)
        _ = workout.addSet(exercise: exercise, weight: 0, reps: 0)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(
            viewModel.deleteExerciseMessage(for: exercise),
            "Are you sure you want to remove “Bench Press” from this workout? This will remove 2 working sets from the workout."
        )
    }

    func testDeleteExerciseCopyMentionsWarmupAndWorkingDraftSetMixBeforeAnythingIsLogged() {
        let workout = workoutManager.createWorkout(name: "Pull")
        let exercise = Exercise(name: "Lat Pulldown", category: .compound, primaryMuscleGroups: [.back])
        _ = workout.addSet(exercise: exercise, weight: 0, reps: 0, isWarmup: true)
        _ = workout.addSet(exercise: exercise, weight: 0, reps: 0)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(
            viewModel.deleteExerciseMessage(for: exercise),
            "Are you sure you want to remove “Lat Pulldown” from this workout? This will remove 2 sets from the workout (1 working set and 1 warm-up set)."
        )
    }

    func testAddExerciseToWorkout_createsIncompleteStarterSet() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Overhead Press", category: .compound, primaryMuscleGroups: [.shoulders])
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.addExerciseToWorkout(exercise)

        // Then
        let createdSet = workout.sets.first { $0.exercise?.id == exercise.id }
        XCTAssertNotNil(createdSet)
        XCTAssertEqual(createdSet?.completedAt, .distantPast, "New starter set should begin incomplete")
    }

    func testAddExerciseToWorkout_rejectsDuplicateExerciseSelection() throws {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Overhead Press", category: .compound, primaryMuscleGroups: [.shoulders])
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        try viewModel.addExerciseToWorkout(exercise)

        XCTAssertThrowsError(try viewModel.addExerciseToWorkout(exercise)) { error in
            XCTAssertEqual(
                error as? ActiveWorkoutViewModel.WorkoutError,
                .duplicateExercise,
                "Selecting an exercise that is already in the workout should be rejected instead of silently adding a surprise extra set"
            )
        }
        XCTAssertEqual(
            workout.sets.filter { $0.exercise?.id == exercise.id }.count,
            1,
            "Duplicate exercise selection should leave the workout with its original starter set only"
        )
    }

    func testAddExerciseToWorkout_failedSaveRollsBackInsertedStarterSet() {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Overhead Press", category: .compound, primaryMuscleGroups: [.shoulders])
        let failingWorkoutManager = WorkoutManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            userManager: UserManager.shared
        )
        let viewModel = ActiveWorkoutViewModel(workout: workout, workoutManager: failingWorkoutManager)

        XCTAssertThrowsError(try viewModel.addExerciseToWorkout(exercise))
        XCTAssertFalse(workout.sets.contains(where: { $0.exercise?.id == exercise.id }))
        XCTAssertFalse(exercise.sets.contains(where: { $0.workout?.id == workout.id }))
        XCTAssertFalse(viewModel.exerciseOrder.contains(where: { $0.id == exercise.id }))
        XCTAssertNil(viewModel.exerciseGroups[exercise])
    }

    func testAddExerciseToWorkoutSafely_failureUsesNamedExerciseAlertTitle() {
        let workout = workoutManager.createWorkout(name: "Push")
        let exercise = Exercise(name: "Overhead Press", category: .compound, primaryMuscleGroups: [.shoulders])
        let failingWorkoutManager = WorkoutManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            userManager: UserManager.shared
        )
        let viewModel = ActiveWorkoutViewModel(workout: workout, workoutManager: failingWorkoutManager)

        XCTAssertFalse(viewModel.addExerciseToWorkoutSafely(exercise))
        XCTAssertEqual(viewModel.errorAlertTitle, "Couldn’t Add “Overhead Press”")
        XCTAssertEqual(viewModel.errorMessage, "Failed to add exercise: Failed to save workout")
    }

    func testAddExerciseToWorkoutSafely_failureUsesGenericExerciseFallbackForBlankNames() {
        let workout = workoutManager.createWorkout(name: "Push")
        let exercise = Exercise(name: "   ", category: .compound, primaryMuscleGroups: [.shoulders])
        let failingWorkoutManager = WorkoutManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            userManager: UserManager.shared
        )
        let viewModel = ActiveWorkoutViewModel(workout: workout, workoutManager: failingWorkoutManager)

        XCTAssertFalse(viewModel.addExerciseToWorkoutSafely(exercise))
        XCTAssertEqual(viewModel.errorAlertTitle, "Couldn’t Add This Exercise")
        XCTAssertEqual(viewModel.errorMessage, "Failed to add exercise: Failed to save workout")
    }

    func testAddSetToExercise_keepsAutoSuggestedSetIncomplete() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let existingSet = workout.addSet(exercise: exercise, weight: 225, reps: 5)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.addSetToExercise(exercise)

        // Then
        let addedSet = workout.sets.first { $0.id != existingSet.id && $0.exercise?.id == exercise.id }
        XCTAssertNotNil(addedSet)
        XCTAssertEqual(addedSet?.completedAt, .distantPast, "Auto-suggested set should not be marked complete until user logs it")
    }

    func testAddSetToExercise_failedSaveRollsBackInsertedSet() {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let originalSet = workout.addSet(exercise: exercise, weight: 185, reps: 6)
        let failingWorkoutManager = WorkoutManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            userManager: UserManager.shared
        )
        let viewModel = ActiveWorkoutViewModel(workout: workout, workoutManager: failingWorkoutManager)

        XCTAssertThrowsError(try viewModel.addSetToExercise(exercise))
        XCTAssertEqual(workout.sets.filter { $0.exercise?.id == exercise.id }.count, 1)
        XCTAssertTrue(workout.sets.contains(where: { $0.id == originalSet.id }))
        XCTAssertEqual(viewModel.exerciseGroups[exercise]?.count, 1)
    }

    func testAddSetToExercise_usesLastSetNumberNotLatestCompletionTimestamp() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        let firstSet = workout.addSet(exercise: exercise, weight: 225, reps: 8)
        let secondSet = workout.addSet(exercise: exercise, weight: 205, reps: 10)

        // Simulate out-of-order completion timestamps from edits.
        firstSet.completedAt = Date().addingTimeInterval(120)
        secondSet.completedAt = Date().addingTimeInterval(-120)

        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.addSetToExercise(exercise)

        // Then
        let addedSet = workout.sets.first {
            $0.id != firstSet.id && $0.id != secondSet.id && $0.exercise?.id == exercise.id
        }
        XCTAssertNotNil(addedSet)
        XCTAssertEqual(addedSet?.reps, 12, "Progression should use the most recently added set number, not completion time")
    }

    func testAddSetToExercise_warmupDoesNotShiftWorkingSetDropProgression() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        _ = workout.addSet(exercise: exercise, weight: 135, reps: 8, isWarmup: true)
        let workingSet = workout.addSet(exercise: exercise, weight: 200, reps: 6)

        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.addSetToExercise(exercise)

        // Then
        let addedSet = workout.sets.first {
            $0.id != workingSet.id && $0.exercise?.id == exercise.id && !$0.isWarmup
        }
        XCTAssertNotNil(addedSet)
        XCTAssertEqual(addedSet?.weight, 180, "Warmup sets should not shift working-set drop progression")
        XCTAssertEqual(addedSet?.reps, 8, "Working-set progression should build from the last completed working set")
    }

    func testAddSetToExercise_keepsDefaultRepsWhenLastSetRepsAreZero() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = workout.addSet(exercise: exercise, weight: 200, reps: 0)

        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.addSetToExercise(exercise)

        // Then
        let addedSet = workout.sets.last { $0.exercise?.id == exercise.id }
        XCTAssertEqual(addedSet?.reps, 8, "Zero-rep seed sets should keep default starter reps instead of dropping to 2 reps")
    }

    func testAddSetToExercise_keepsDefaultRepsWhenLastSetRepsAreCorruptedNegative() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let corruptedSet = workout.addSet(exercise: exercise, weight: 200, reps: 6)
        corruptedSet.reps = -4

        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.addSetToExercise(exercise)

        // Then
        let addedSet = workout.sets.last { $0.exercise?.id == exercise.id }
        XCTAssertEqual(addedSet?.reps, 8, "Corrupted negative reps should not collapse suggestions below default starter reps")
    }

    func testAddSetToExercise_clampsCorruptedNegativeLastWeightToSafeSuggestion() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let corruptedSet = workout.addSet(exercise: exercise, weight: 185, reps: 6)
        corruptedSet.weight = -185

        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.addSetToExercise(exercise)

        // Then
        let addedSet = workout.sets.last { $0.id != corruptedSet.id && $0.exercise?.id == exercise.id }
        XCTAssertEqual(addedSet?.weight, 0, "Corrupted negative previous weight should never produce negative auto-suggested weights")
    }

    func testUpdateDropSetSuggestions_updatesBackoffSetsInOnePass() throws {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let topSet = workout.addSet(exercise: exercise, weight: 225, reps: 6)
        let backoffSet1 = workout.addSet(exercise: exercise, weight: 205, reps: 8)
        let backoffSet2 = workout.addSet(exercise: exercise, weight: 185, reps: 10)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        try viewModel.updateDropSetSuggestions(for: exercise, firstSetWeight: 245)

        XCTAssertEqual(topSet.weight, 225, "Updating drop-set suggestions should not mutate the logged top set")
        XCTAssertEqual(backoffSet1.weight, 220, "First backoff set should follow the configured 10% drop and round to the nearest 5 lb")
        XCTAssertEqual(backoffSet2.weight, 210, "Second backoff set should follow the configured 15% drop and round to the nearest 5 lb")
    }

    func testUpdateDropSetSuggestions_failedSaveRollsBackAllBackoffSets() {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = workout.addSet(exercise: exercise, weight: 225, reps: 6)
        let backoffSet1 = workout.addSet(exercise: exercise, weight: 205, reps: 8)
        let backoffSet2 = workout.addSet(exercise: exercise, weight: 185, reps: 10)
        let originalCompletedAt1 = backoffSet1.completedAt
        let originalCompletedAt2 = backoffSet2.completedAt
        let failingWorkoutManager = WorkoutManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            userManager: UserManager.shared
        )
        let viewModel = ActiveWorkoutViewModel(workout: workout, workoutManager: failingWorkoutManager)

        XCTAssertThrowsError(try viewModel.updateDropSetSuggestions(for: exercise, firstSetWeight: 245))
        XCTAssertEqual(backoffSet1.weight, 205)
        XCTAssertEqual(backoffSet2.weight, 185)
        XCTAssertEqual(backoffSet1.completedAt, originalCompletedAt1)
        XCTAssertEqual(backoffSet2.completedAt, originalCompletedAt2)
    }

    func testViewModelPreservesExerciseInsertionOrderWhenTimestampsMatch() {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        let squatSet = workout.addSet(exercise: squat, weight: 0, reps: 8)
        let benchSet = workout.addSet(exercise: bench, weight: 0, reps: 8)
        squatSet.completedAt = .distantPast
        benchSet.completedAt = .distantPast

        // When
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // Then
        XCTAssertEqual(viewModel.exerciseOrder.map(\.name), ["Squat", "Bench Press"])
    }

    func testOrderedSetsForDisplay_prefersInsertionOrderOverCompletionTimestamp() {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])

        let firstSet = workout.addSet(exercise: exercise, weight: 225, reps: 8)
        let secondSet = workout.addSet(exercise: exercise, weight: 205, reps: 10)

        // Simulate out-of-order timestamps from edits.
        firstSet.completedAt = Date().addingTimeInterval(120)
        secondSet.completedAt = Date().addingTimeInterval(-120)

        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        let orderedSets = viewModel.orderedSetsForDisplay(in: exercise)

        // Then
        XCTAssertEqual(orderedSets.map(\.id), [firstSet.id, secondSet.id])
    }

    func testTemplateAutofill_usesCompletedWorkingSetNotWarmup() {
        // Given
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let priorWorkout = workoutManager.createWorkout(name: "Prior Workout")
        _ = priorWorkout.addSet(exercise: exercise, weight: 45, reps: 12, isWarmup: true)
        _ = priorWorkout.addSet(exercise: exercise, weight: 205, reps: 6)

        let templateWorkout = workoutManager.createWorkout(name: "Template Workout", fromTemplate: "Push Day")
        _ = templateWorkout.addSet(exercise: exercise, weight: 0, reps: 8)

        // When
        _ = ActiveWorkoutViewModel(workout: templateWorkout)

        // Then
        let autofilledSet = templateWorkout.sets.first { $0.exercise?.id == exercise.id }
        XCTAssertEqual(autofilledSet?.weight, 205, "Autofill should ignore warmups and use prior completed working sets")
        XCTAssertEqual(autofilledSet?.reps, 8, "Template-set target reps should remain unchanged when already configured")
    }

    func testTemplateAutofill_ignoresIncompleteRecentWorkout() {
        // Given
        let exercise = Exercise(name: "Incline Bench", category: .compound, primaryMuscleGroups: [.chest])

        let completedWorkout = workoutManager.createWorkout(name: "Completed Workout")
        _ = completedWorkout.addSet(exercise: exercise, weight: 200, reps: 6)
        completedWorkout.isCompleted = true

        let newerIncompleteWorkout = workoutManager.createWorkout(name: "In Progress")
        _ = newerIncompleteWorkout.addSet(exercise: exercise, weight: 235, reps: 4)

        let templateWorkout = workoutManager.createWorkout(name: "Template Workout", fromTemplate: "Push Day")
        _ = templateWorkout.addSet(exercise: exercise, weight: 0, reps: 8)

        // When
        _ = ActiveWorkoutViewModel(workout: templateWorkout)

        // Then
        let autofilledSet = templateWorkout.sets.first { $0.exercise?.id == exercise.id }
        XCTAssertEqual(autofilledSet?.weight, 200, "Autofill should ignore newer in-progress workouts and use the most recent completed workout")
    }

    func testTemplateAutofill_failedSaveRestoresPriorSetValues() {
        let exercise = Exercise(name: "Overhead Press", category: .compound, primaryMuscleGroups: [.shoulders])

        let completedWorkout = workoutManager.createWorkout(name: "Completed Workout")
        _ = completedWorkout.addSet(exercise: exercise, weight: 135, reps: 6)
        completedWorkout.isCompleted = true

        let templateWorkout = workoutManager.createWorkout(name: "Template Workout", fromTemplate: "Push Day")
        let templateSet = templateWorkout.addSet(exercise: exercise, weight: 0, reps: 8)
        templateSet.completedAt = .distantPast

        let failingWorkoutManager = WorkoutManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            userManager: UserManager.shared
        )

        let viewModel = ActiveWorkoutViewModel(workout: templateWorkout, workoutManager: failingWorkoutManager)

        XCTAssertEqual(templateSet.weight, 0, "Failed template autofill saves should restore the original placeholder weight")
        XCTAssertEqual(templateSet.reps, 8, "Failed template autofill saves should preserve the template target reps")
        XCTAssertNil(templateSet.rpe, "Failed template autofill saves should not leave copied RPE values behind")
        XCTAssertEqual(templateSet.completedAt, .distantPast, "Failed template autofill saves should keep placeholder sets incomplete")
        XCTAssertEqual(viewModel.errorMessage, "Couldn’t load “Pull Day” right now. Please try again.")
    }

    func testShouldStartRestTimer_requiresCompletedWorkingSet() {
        XCTAssertTrue(ExerciseSetRowView.shouldStartRestTimer(weight: 225, reps: 5, isWarmup: false, wasCompletedWorkingSet: false))
        XCTAssertFalse(ExerciseSetRowView.shouldStartRestTimer(weight: 225, reps: 0, isWarmup: false, wasCompletedWorkingSet: false))
        XCTAssertFalse(ExerciseSetRowView.shouldStartRestTimer(weight: 0, reps: 5, isWarmup: false, wasCompletedWorkingSet: false))
        XCTAssertTrue(ExerciseSetRowView.shouldStartRestTimer(weight: 0, reps: 5, isWarmup: false, exerciseCategory: .bodyweight, wasCompletedWorkingSet: false))
        XCTAssertFalse(ExerciseSetRowView.shouldStartRestTimer(weight: 225, reps: 5, isWarmup: true, wasCompletedWorkingSet: false))
    }

    func testShouldStartRestTimer_doesNotRestartWhenSetWasAlreadyCompleted() {
        XCTAssertFalse(ExerciseSetRowView.shouldStartRestTimer(weight: 225, reps: 5, isWarmup: false, wasCompletedWorkingSet: true))
    }

    func testShouldUpdateDropSets_requiresCompletedNonWarmupFirstSet() {
        XCTAssertTrue(ExerciseSetRowView.shouldUpdateDropSets(weight: 225, reps: 5, isWarmup: false))
        XCTAssertFalse(ExerciseSetRowView.shouldUpdateDropSets(weight: 225, reps: 0, isWarmup: false))
        XCTAssertFalse(ExerciseSetRowView.shouldUpdateDropSets(weight: 0, reps: 5, isWarmup: false))
        XCTAssertTrue(ExerciseSetRowView.shouldUpdateDropSets(weight: 0, reps: 5, isWarmup: false, exerciseCategory: .bodyweight))
        XCTAssertFalse(ExerciseSetRowView.shouldUpdateDropSets(weight: 225, reps: 5, isWarmup: true))
    }

    func testExerciseSetDraftValidation_allowsBlankWeightAndRepsToClearSet() {
        XCTAssertEqual(
            ExerciseSetRowView.validateDraft(weightInput: "", repsInput: "  ", rpeInput: ""),
            .valid
        )
    }

    func testExerciseSetDraftValidation_rejectsInvalidNumericInputs() {
        XCTAssertEqual(
            ExerciseSetRowView.validateDraft(weightInput: "abc", repsInput: "5", rpeInput: ""),
            .invalidWeight
        )
        XCTAssertEqual(
            ExerciseSetRowView.validateDraft(weightInput: "185", repsInput: "five", rpeInput: ""),
            .invalidReps
        )
        XCTAssertEqual(
            ExerciseSetRowView.validateDraft(weightInput: "185", repsInput: "5", rpeInput: "11"),
            .invalidRPE
        )
    }

    func testExerciseSetSanitizedInteger_treatsBlankAsExplicitEmptyValue() {
        XCTAssertEqual(ExerciseSetRowView.sanitizedInteger(from: "   ", emptyValue: 0), 0)
        XCTAssertNil(ExerciseSetRowView.sanitizedInteger(from: "", emptyValue: nil))
        XCTAssertEqual(ExerciseSetRowView.sanitizedInteger(from: " 12 ", emptyValue: 0), 12)
        XCTAssertNil(ExerciseSetRowView.sanitizedInteger(from: "-3", emptyValue: 0))
    }

    func testFinishHelperText_whenAllExercisesCompleted_returnsNil() {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Row", category: .compound, primaryMuscleGroups: [.lats])
        _ = workout.addSet(exercise: bench, weight: 185, reps: 6)
        _ = workout.addSet(exercise: row, weight: 155, reps: 8)

        let viewModel = ActiveWorkoutViewModel(workout: workout)
        viewModel.toggleExerciseCompletion(bench)
        viewModel.toggleExerciseCompletion(row)

        XCTAssertNil(viewModel.finishHelperText)
    }

    func testFinishHelperText_whenOneExerciseRemains_mentionsExerciseName() {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Row", category: .compound, primaryMuscleGroups: [.lats])
        _ = workout.addSet(exercise: bench, weight: 185, reps: 6)
        _ = workout.addSet(exercise: row, weight: 155, reps: 8)

        let viewModel = ActiveWorkoutViewModel(workout: workout)
        viewModel.toggleExerciseCompletion(bench)

        XCTAssertEqual(
            viewModel.finishHelperText,
            "1 exercise left: Row. Tap the circle beside it when you're done to enable Finish “Test Workout”."
        )
    }

    func testFinishHelperText_whenSeveralExercisesRemain_summarizesCountAndPreviewNames() {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let squat = Exercise(name: "Squat", category: .compound, primaryMuscleGroups: [.quadriceps])
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Row", category: .compound, primaryMuscleGroups: [.lats])
        _ = workout.addSet(exercise: squat, weight: 225, reps: 5)
        _ = workout.addSet(exercise: bench, weight: 185, reps: 6)
        _ = workout.addSet(exercise: row, weight: 155, reps: 8)

        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(
            viewModel.finishHelperText,
            "3 exercises left: Squat, Bench Press, +1 more. Tap each circle when you're done to enable Finish “Test Workout”."
        )
    }

    func testExitDialogHelperText_whenAllExercisesCompleted_usesCompletionMessaging() {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = workout.addSet(exercise: bench, weight: 185, reps: 6)

        let viewModel = ActiveWorkoutViewModel(workout: workout)
        viewModel.toggleExerciseCompletion(bench)

        XCTAssertEqual(
            viewModel.exitDialogHelperText,
            "Save “Test Workout” for Later keeps it as a draft. Complete “Test Workout” & Save marks it as finished."
        )
        XCTAssertTrue(viewModel.canCompleteWorkoutFromExitDialog)
    }

    func testExitDialogHelperText_whenExercisesRemain_explainsWhyCompleteIsUnavailable() {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Row", category: .compound, primaryMuscleGroups: [.lats])
        _ = workout.addSet(exercise: bench, weight: 185, reps: 6)
        _ = workout.addSet(exercise: row, weight: 155, reps: 8)

        let viewModel = ActiveWorkoutViewModel(workout: workout)
        viewModel.toggleExerciseCompletion(bench)

        XCTAssertEqual(
            viewModel.exitDialogHelperText,
            "1 exercise left: Row. Tap the circle beside it when you're done to enable Complete “Test Workout” & Save."
        )
        XCTAssertFalse(viewModel.canCompleteWorkoutFromExitDialog)
    }

    func testExitDialogHelperText_whenAllExercisesCompletedAndWorkoutNameIsGeneric_usesCurrentWorkoutFallback() {
        let workout = workoutManager.createWorkout(name: "   ")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = workout.addSet(exercise: bench, weight: 185, reps: 6)

        let viewModel = ActiveWorkoutViewModel(workout: workout)
        viewModel.toggleExerciseCompletion(bench)

        XCTAssertEqual(
            viewModel.exitDialogHelperText,
            "Save Current Workout for Later keeps it as a draft. Complete Current Workout & Save marks it as finished."
        )
        XCTAssertTrue(viewModel.canCompleteWorkoutFromExitDialog)
    }

    func testExitDialogHelperText_whenWorkoutNameIsGeneric_usesCurrentWorkoutFallback() {
        let workout = workoutManager.createWorkout(name: "   ")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let row = Exercise(name: "Row", category: .compound, primaryMuscleGroups: [.lats])
        _ = workout.addSet(exercise: bench, weight: 185, reps: 6)
        _ = workout.addSet(exercise: row, weight: 155, reps: 8)

        let viewModel = ActiveWorkoutViewModel(workout: workout)
        viewModel.toggleExerciseCompletion(bench)

        XCTAssertEqual(
            viewModel.exitDialogHelperText,
            "1 exercise left: Row. Tap the circle beside it when you're done to enable Complete Current Workout & Save."
        )
    }

    func testDiscardWorkoutCopy_namesSpecificWorkout() {
        let workout = workoutManager.createWorkout(name: "  Upper   A  ")
        let bench = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let warmup = workout.addSet(exercise: bench, weight: 45, reps: 10, isWarmup: true)
        warmup.completedAt = .distantPast
        let workingSet = workout.addSet(exercise: bench, weight: 185, reps: 8)
        workingSet.completedAt = .distantPast

        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(viewModel.discardWorkoutAlertTitle(), "Discard “Upper A”?")
        XCTAssertEqual(viewModel.discardWorkoutButtonTitle(), "Discard “Upper A”")
        XCTAssertEqual(
            viewModel.discardWorkoutMessage(),
            "Discard “Upper A”? This will remove 1 exercise and 2 sets from this draft, including 1 logged working set and 1 logged warm-up set. This action cannot be undone."
        )
    }

    func testDiscardWorkoutCopy_callsOutWorkingOnlyDrafts() {
        let workout = workoutManager.createWorkout(name: "Push")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = workout.addSet(exercise: exercise, weight: 225, reps: 5)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(
            viewModel.discardWorkoutMessage(),
            "Discard “Push”? This will remove 1 exercise and 1 working set from this draft, including 1 logged working set. This action cannot be undone."
        )
    }

    func testDiscardWorkoutCopy_callsOutWarmupOnlyDrafts() {
        let workout = workoutManager.createWorkout(name: "Recovery")
        let mobility = Exercise(name: "Band Pull-Apart", category: .bodyweight, primaryMuscleGroups: [.shoulders])
        _ = workout.addSet(exercise: mobility, weight: 0, reps: 20, isWarmup: true)

        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(
            viewModel.discardWorkoutMessage(),
            "Discard “Recovery”? This will remove 1 exercise and 1 warm-up set from “Recovery”, including 1 logged warm-up set. This action cannot be undone."
        )
    }

    func testDiscardWorkoutCopy_fallsBackForGenericWorkoutName() {
        let workout = workoutManager.createWorkout(name: "   ")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(viewModel.discardWorkoutAlertTitle(), "Discard Current Workout?")
        XCTAssertEqual(viewModel.discardWorkoutButtonTitle(), "Discard Current Workout")
        XCTAssertEqual(
            viewModel.discardWorkoutMessage(),
            "Discard your current workout? This draft has no exercises yet, but it will still be removed. This action cannot be undone."
        )
    }

    func testDiscardWorkoutCopy_namesEmptySpecificWorkoutDraftInBody() {
        let workout = workoutManager.createWorkout(name: " Recovery ")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(
            viewModel.discardWorkoutMessage(),
            "Discard “Recovery”? “Recovery” has no exercises yet, but it will still be removed. This action cannot be undone."
        )
    }

    func testExitWorkoutCopy_namesSpecificWorkout() {
        let workout = workoutManager.createWorkout(name: "  Upper   A  ")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(viewModel.exitWorkoutMenuTitle(), "Exit “Upper A”")
        XCTAssertEqual(viewModel.saveForLaterButtonTitle(), "Save “Upper A” for Later")
        XCTAssertEqual(viewModel.discardWorkoutMenuTitle(), "Discard “Upper A”")
    }

    func testExitWorkoutCopy_fallsBackForGenericWorkoutName() {
        let workout = workoutManager.createWorkout(name: "Workout")
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        XCTAssertEqual(viewModel.exitWorkoutMenuTitle(), "Exit Current Workout")
        XCTAssertEqual(viewModel.saveForLaterButtonTitle(), "Save Current Workout for Later")
        XCTAssertEqual(viewModel.discardWorkoutMenuTitle(), "Discard Current Workout")
    }

    func testDeleteSet_removesSetFromExerciseRelationship() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let set = workout.addSet(exercise: exercise, weight: 185, reps: 6)
        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.deleteSet(set)

        // Then
        XCTAssertFalse(workout.sets.contains(where: { $0.id == set.id }))
        XCTAssertFalse(exercise.sets.contains(where: { $0.id == set.id }), "Deleting from active workout should also remove the set from exercise history links")
    }

    func testDeleteSet_failedSaveRestoresSetAndRelationships() {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let set = workout.addSet(exercise: exercise, weight: 185, reps: 6)
        let failingWorkoutManager = WorkoutManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            userManager: UserManager.shared
        )
        let viewModel = ActiveWorkoutViewModel(workout: workout, workoutManager: failingWorkoutManager)

        XCTAssertThrowsError(try viewModel.deleteSet(set))
        XCTAssertTrue(workout.sets.contains(where: { $0.id == set.id }))
        XCTAssertTrue(exercise.sets.contains(where: { $0.id == set.id }))
        XCTAssertEqual(viewModel.exerciseGroups[exercise]?.count, 1)
    }

    func testDeleteExerciseFromWorkout_removesLinkedExerciseSets() throws {
        // Given
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let targetExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let keepExercise = Exercise(name: "Row", category: .compound, primaryMuscleGroups: [.lats])

        let targetSet1 = workout.addSet(exercise: targetExercise, weight: 185, reps: 6)
        let targetSet2 = workout.addSet(exercise: targetExercise, weight: 170, reps: 8)
        _ = workout.addSet(exercise: keepExercise, weight: 155, reps: 10)

        let viewModel = ActiveWorkoutViewModel(workout: workout)

        // When
        try viewModel.deleteExerciseFromWorkout(targetExercise)

        // Then
        XCTAssertFalse(workout.sets.contains(where: { $0.exercise?.id == targetExercise.id }))
        XCTAssertFalse(targetExercise.sets.contains(where: { $0.id == targetSet1.id || $0.id == targetSet2.id }), "Deleting an exercise from workout should delete its linked ExerciseSet records")
        XCTAssertTrue(workout.sets.contains(where: { $0.exercise?.id == keepExercise.id }), "Deleting one exercise should not remove unrelated exercise sets")
    }

    func testDeleteExerciseFromWorkout_failedSaveRestoresExerciseSetsAndOrder() {
        let workout = workoutManager.createWorkout(name: "Test Workout")
        let targetExercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        let keepExercise = Exercise(name: "Row", category: .compound, primaryMuscleGroups: [.lats])

        let targetSet1 = workout.addSet(exercise: targetExercise, weight: 185, reps: 6)
        let targetSet2 = workout.addSet(exercise: targetExercise, weight: 170, reps: 8)
        _ = workout.addSet(exercise: keepExercise, weight: 155, reps: 10)

        let failingWorkoutManager = WorkoutManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            userManager: UserManager.shared
        )
        let viewModel = ActiveWorkoutViewModel(workout: workout, workoutManager: failingWorkoutManager)

        XCTAssertThrowsError(try viewModel.deleteExerciseFromWorkout(targetExercise))
        XCTAssertEqual(viewModel.exerciseOrder.map(\.id), [targetExercise.id, keepExercise.id])
        XCTAssertTrue(workout.sets.contains(where: { $0.id == targetSet1.id }))
        XCTAssertTrue(workout.sets.contains(where: { $0.id == targetSet2.id }))
        XCTAssertTrue(targetExercise.sets.contains(where: { $0.id == targetSet1.id || $0.id == targetSet2.id }))
        XCTAssertEqual(viewModel.exerciseGroups[targetExercise]?.count, 2)
    }

    func testDeleteExerciseFromWorkoutSafely_failureUsesNamedExerciseAlertTitle() {
        let workout = workoutManager.createWorkout(name: "Push")
        let exercise = Exercise(name: "Bench Press", category: .compound, primaryMuscleGroups: [.chest])
        _ = workout.addSet(exercise: exercise, weight: 185, reps: 6)
        let failingWorkoutManager = WorkoutManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            userManager: UserManager.shared
        )
        let viewModel = ActiveWorkoutViewModel(workout: workout, workoutManager: failingWorkoutManager)

        XCTAssertFalse(viewModel.deleteExerciseFromWorkoutSafely(exercise))
        XCTAssertEqual(viewModel.errorAlertTitle, "Couldn’t Delete “Bench Press”")
        XCTAssertEqual(viewModel.errorMessage, "Failed to delete exercise: saveFailed")
    }

    func testDeleteExerciseFromWorkoutSafely_failureUsesGenericExerciseFallbackForBlankNames() {
        let workout = workoutManager.createWorkout(name: "Push")
        let exercise = Exercise(name: "   ", category: .compound, primaryMuscleGroups: [.chest])
        _ = workout.addSet(exercise: exercise, weight: 185, reps: 6)
        let failingWorkoutManager = WorkoutManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            userManager: UserManager.shared
        )
        let viewModel = ActiveWorkoutViewModel(workout: workout, workoutManager: failingWorkoutManager)

        XCTAssertFalse(viewModel.deleteExerciseFromWorkoutSafely(exercise))
        XCTAssertEqual(viewModel.errorAlertTitle, "Couldn’t Delete This Exercise")
        XCTAssertEqual(viewModel.errorMessage, "Failed to delete exercise: saveFailed")
    }

    func testSaveAndCompleteFailuresUseSpecificWorkoutNameWhenAvailable() {
        let workout = workoutManager.createWorkout(name: "Upper A")
        let failingWorkoutManager = WorkoutManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            userManager: UserManager.shared
        )
        let viewModel = ActiveWorkoutViewModel(workout: workout, workoutManager: failingWorkoutManager)

        XCTAssertFalse(viewModel.saveWorkoutSafely())
        XCTAssertEqual(viewModel.errorAlertTitle, "Couldn’t Save “Upper A”")
        XCTAssertEqual(viewModel.errorMessage, "Couldn’t save “Upper A” right now. Keep it open, then try again.")

        XCTAssertFalse(viewModel.completeWorkoutSafely())
        XCTAssertEqual(viewModel.errorAlertTitle, "Couldn’t Complete “Upper A”")
        XCTAssertEqual(viewModel.errorMessage, "Couldn’t complete “Upper A” right now. Keep it open, then try again.")

        XCTAssertFalse(viewModel.discardWorkoutSafely())
        XCTAssertEqual(viewModel.errorAlertTitle, "Couldn’t Discard “Upper A”")
        XCTAssertEqual(viewModel.errorMessage, "Couldn’t discard “Upper A” right now. Keep it open, then try again.")
    }

    func testSaveAndCompleteFailuresUseCurrentWorkoutFallbackForBlankNames() {
        let workout = workoutManager.createWorkout(name: " \n ")
        let failingWorkoutManager = WorkoutManager(
            dataManager: FailingDataManager(context: DataManager.shared.getModelContext()),
            userManager: UserManager.shared
        )
        let viewModel = ActiveWorkoutViewModel(workout: workout, workoutManager: failingWorkoutManager)

        XCTAssertFalse(viewModel.saveWorkoutSafely())
        XCTAssertEqual(viewModel.errorAlertTitle, "Couldn’t Save Current Workout")
        XCTAssertEqual(viewModel.errorMessage, "Couldn’t save the current workout right now. Keep it open, then try again.")

        XCTAssertFalse(viewModel.completeWorkoutSafely())
        XCTAssertEqual(viewModel.errorAlertTitle, "Couldn’t Complete Current Workout")
        XCTAssertEqual(viewModel.errorMessage, "Couldn’t complete the current workout right now. Keep it open, then try again.")

        XCTAssertFalse(viewModel.discardWorkoutSafely())
        XCTAssertEqual(viewModel.errorAlertTitle, "Couldn’t Discard Current Workout")
        XCTAssertEqual(viewModel.errorMessage, "Couldn’t discard the current workout right now. Keep it open, then try again.")
    }
}
