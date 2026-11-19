//
//  HostedTestEnvironmentTests.swift
//  RPTTests
//
//  Unit tests run inside the app and share its container. These check that
//  what the simulator was last used for cannot change what the suite
//  computes.
//

import XCTest
@testable import RPT

final class HostedTestEnvironmentTests: XCTestCase {
    func testUnitTestsRunInPoundsWhateverTheSimulatorHolds() {
        XCTAssertEqual(
            WeightUnit.overrideForTesting,
            .pounds,
            "RPTTrainerApp pins the unit when it hosts a test run"
        )
        XCTAssertEqual(WeightUnit.current, .pounds)
        XCTAssertEqual(OneRepMax.formatted(233.4), "233 lb")
    }

    // The stored choice is deliberately not written here: the host app is
    // on screen during a test run and would rebuild its tabs in response.

    func testATestCanStillAskForTheOtherUnit() {
        let original = WeightUnit.overrideForTesting
        defer { WeightUnit.overrideForTesting = original }

        WeightUnit.overrideForTesting = .kilograms

        XCTAssertEqual(WeightUnit.current, .kilograms)
        XCTAssertEqual(OneRepMax.formatted(233.4), "105.9 kg")
    }
}
