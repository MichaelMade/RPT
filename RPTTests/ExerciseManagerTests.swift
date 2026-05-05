import XCTest
@testable import RPT

@MainActor
final class ExerciseManagerTests: XCTestCase {
    func testValidateDraft_requiresNonEmptyName() {
        let result = ExerciseManager.shared.validateDraft(
            name: "   \n  ",
            primaryMuscleGroups: [.chest]
        )

        XCTAssertEqual(result, .missingName)
    }

    func testValidateDraft_requiresAtLeastOnePrimaryMuscle() {
        let result = ExerciseManager.shared.validateDraft(
            name: "Bench Press",
            primaryMuscleGroups: []
        )

        XCTAssertEqual(result, .noPrimaryMuscles)
    }

    func testValidateDraft_acceptsEditableExistingExerciseName() {
        guard let exercise = ExerciseManager.shared.fetchAllExercises().first else {
            XCTFail("Expected seeded exercise data")
            return
        }

        let result = ExerciseManager.shared.validateDraft(
            name: " \(exercise.name) ",
            primaryMuscleGroups: exercise.primaryMuscleGroups,
            excludingExerciseId: exercise.id
        )

        XCTAssertEqual(result, .valid)
    }

    func testValidateDraft_rejectsDuplicateNormalizedName() {
        let result = ExerciseManager.shared.validateDraft(
            name: "  Ｂｅｎｃｈ   Ｐｒｅｓｓ  ",
            primaryMuscleGroups: [.chest]
        )

        XCTAssertEqual(result, .duplicateName)
    }

    func testMutationResult_duplicateNameUsesSpecificAlertCopy() {
        XCTAssertEqual(ExerciseManager.MutationResult.duplicateName.alertTitle, "Exercise Already Exists")
        XCTAssertEqual(
            ExerciseManager.MutationResult.duplicateName.alertMessage,
            "An exercise with this name already exists. Please choose a different name."
        )
    }

    func testMutationResult_persistenceFailureUsesRetryAlertCopy() {
        XCTAssertEqual(ExerciseManager.MutationResult.persistenceFailure.alertTitle, "Unable to Save Exercise")
        XCTAssertEqual(
            ExerciseManager.MutationResult.persistenceFailure.alertMessage,
            "Your changes could not be saved right now. Please try again."
        )
    }
}
