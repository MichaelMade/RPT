//
//  WorkoutProgressViewTests.swift
//  RPTTests
//

import XCTest
@testable import RPT

final class WorkoutProgressViewTests: XCTestCase {
    func testProgress_whenTotalExercisesIsZero_returnsZero() {
        let view = WorkoutProgressView(completedExercises: 3, totalExercises: 0)
        XCTAssertEqual(view.progress, 0)
    }

    func testProgress_whenValuesAreNormal_returnsRatio() {
        let view = WorkoutProgressView(completedExercises: 2, totalExercises: 4)
        XCTAssertEqual(view.progress, 0.5)
    }

    func testProgress_whenCompletedExceedsTotal_clampsToOne() {
        let view = WorkoutProgressView(completedExercises: 6, totalExercises: 4)
        XCTAssertEqual(view.progress, 1)
    }

    func testProgress_whenCompletedIsNegative_clampsToZero() {
        let view = WorkoutProgressView(completedExercises: -1, totalExercises: 4)
        XCTAssertEqual(view.progress, 0)
    }

    func testProgress_whenTotalExercisesIsNegative_returnsZero() {
        let view = WorkoutProgressView(completedExercises: 2, totalExercises: -4)
        XCTAssertEqual(view.progress, 0)
    }

    func testProgressLabel_whenInputsAreNegative_showsEmptyStateCopy() {
        let view = WorkoutProgressView(completedExercises: -2, totalExercises: -4)
        XCTAssertEqual(view.progressLabel, "No exercises yet")
    }

    func testProgressLabel_whenCompletedExceedsTotal_clampsDisplayToTotal() {
        let view = WorkoutProgressView(completedExercises: 6, totalExercises: 4)
        XCTAssertEqual(view.progressLabel, "4/4 Exercises")
    }

    func testProgressLabel_whenTotalExercisesIsZero_showsEmptyStateCopy() {
        let view = WorkoutProgressView(completedExercises: 3, totalExercises: 0)
        XCTAssertEqual(view.progressLabel, "No exercises yet")
    }

    func testProgressLabel_whenTotalIsOne_usesSingularGrammar() {
        let view = WorkoutProgressView(completedExercises: 1, totalExercises: 1)
        XCTAssertEqual(view.progressLabel, "1/1 Exercise")
    }
}
