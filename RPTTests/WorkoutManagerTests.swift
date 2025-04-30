//
//  WorkoutManagerTests.swift
//  RPTTests
//
//  Created by Michael Moore on 4/30/25.
//

import XCTest
@testable import RPT

@MainActor
final class WorkoutManagerTests: XCTestCase {

    func testCalculateRPTWeights_withSimpleDrops() {
        // Given
        let firstSetWeight: Double = 200
        let drops: [Double] = [0.10, 0.20, 0.30]
        
        // When
        let weights = WorkoutManager.shared.calculateRPTWeights(
            firstSetWeight: firstSetWeight,
            percentageDrops: drops
        )
        
        // Then
        XCTAssertEqual(weights.count, drops.count)
        XCTAssertEqual(weights[0], 200 * (1.0 - 0.10), accuracy: 1e-6)
        XCTAssertEqual(weights[1], 200 * (1.0 - 0.20), accuracy: 1e-6)
        XCTAssertEqual(weights[2], 200 * (1.0 - 0.30), accuracy: 1e-6)
    }

    func testCalculateRPTWeights_withNoDrops() {
        // Given
        let firstSetWeight: Double = 150
        let drops: [Double] = []
        
        // When
        let weights = WorkoutManager.shared.calculateRPTWeights(
            firstSetWeight: firstSetWeight,
            percentageDrops: drops
        )
        
        // Then
        XCTAssertTrue(weights.isEmpty)
    }
}
