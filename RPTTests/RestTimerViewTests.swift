//
//  RestTimerViewTests.swift
//  RPTTests
//

import XCTest
@testable import RPT

final class RestTimerViewTests: XCTestCase {
    func testNormalizedProgress_usesCurrentTimerDuration() {
        let progress = RestTimerView.normalizedProgress(timeRemaining: 15, duration: 30)
        XCTAssertEqual(progress, 0.5, accuracy: 0.0001)
    }

    func testNormalizedProgress_clampsOutOfBoundsRemainingTime() {
        XCTAssertEqual(
            RestTimerView.normalizedProgress(timeRemaining: 120, duration: 60),
            0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            RestTimerView.normalizedProgress(timeRemaining: -5, duration: 60),
            1,
            accuracy: 0.0001
        )
    }

    func testNormalizedProgress_returnsZeroForInvalidDuration() {
        XCTAssertEqual(RestTimerView.normalizedProgress(timeRemaining: 10, duration: 0), 0)
        XCTAssertEqual(RestTimerView.normalizedProgress(timeRemaining: 10, duration: -30), 0)
    }

    func testPhase_usesCurrentTimerDurationThresholds() {
        XCTAssertEqual(RestTimerView.phase(forTimeRemaining: 25, duration: 30), .normal)
        XCTAssertEqual(RestTimerView.phase(forTimeRemaining: 8, duration: 30), .warning)
        XCTAssertEqual(RestTimerView.phase(forTimeRemaining: 3, duration: 30), .critical)
    }

    func testPhase_returnsCriticalForInvalidDuration() {
        XCTAssertEqual(RestTimerView.phase(forTimeRemaining: 10, duration: 0), .critical)
    }
}
