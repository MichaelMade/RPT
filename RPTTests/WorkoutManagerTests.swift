//
//  WorkoutManagerTests.swift
//  RPTTests
//
//  Created by Michael Moore on 4/30/25.
//

import XCTest
@testable import RPT

@MainActor
final class WorkoutManagerLogicTests: XCTestCase {
    var manager: WorkoutManager!

    override func setUp() {
        super.setUp()
        // Use the shared singleton for logic tests
        manager = WorkoutManager.shared
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - RPT Weight Calculation

    func testCalculateRPTWeights_withMultipleDrops() {
        // Given
        let firstSetWeight: Double = 250.0
        let drops: [Double] = [0.05, 0.15, 0.25]
        // When
        let weights = manager.calculateRPTWeights(
            firstSetWeight: firstSetWeight,
            percentageDrops: drops
        )
        // Then
        XCTAssertEqual(weights.count, drops.count)
        XCTAssertEqual(weights[0], 250 * 0.95, accuracy: 1e-6)
        XCTAssertEqual(weights[1], 250 * 0.85, accuracy: 1e-6)
        XCTAssertEqual(weights[2], 250 * 0.75, accuracy: 1e-6)
    }

    func testCalculateRPTWeights_withEmptyDrops() {
        // Given
        let firstSetWeight: Double = 180.0
        let drops: [Double] = []
        // When
        let weights = manager.calculateRPTWeights(
            firstSetWeight: firstSetWeight,
            percentageDrops: drops
        )
        // Then
        XCTAssertTrue(weights.isEmpty)
    }

    // MARK: - Weight & Volume Formatting

    func testFormatWeight_displaysOneDecimal() {
        // Given
        let weight: Double = 200.456
        // When
        let formatted = manager.formatWeight(weight)
        // Then
        XCTAssertEqual(formatted, "200.5 lb")
    }

    func testFormatVolume_belowThreshold() {
        // Given
        let volume: Double = 750.0
        // When
        let formatted = manager.formatVolume(volume)
        // Then
        XCTAssertEqual(formatted, "750.0 lb")
    }

    func testFormatVolume_aboveThreshold() {
        // Given
        let volume: Double = 2500.0
        // When
        let formatted = manager.formatVolume(volume)
        // Then
        XCTAssertEqual(formatted, "2.5k lb")
    }

    // MARK: - Workout Statistics Formatting

    func testCalculateWorkoutStatsFormatted_emptyState() {
        // Given: No workouts saved in context
        // When
        let result = manager.calculateWorkoutStatsFormatted(timeframe: .week)
        // Then
        XCTAssertEqual(result.count, 0)
        XCTAssertEqual(result.totalVolume, "0.0 lb")
        XCTAssertEqual(result.averageDuration, "0:00")
    }

    func testCalculateWorkoutStatsFormatted_allTime_emptyState() {
        // Given: Still no workouts
        // When
        let result = manager.calculateWorkoutStatsFormatted(timeframe: .allTime)
        // Then
        XCTAssertEqual(result.count, 0)
        XCTAssertEqual(result.totalVolume, "0.0 lb")
        XCTAssertEqual(result.averageDuration, "0:00")
    }
}
