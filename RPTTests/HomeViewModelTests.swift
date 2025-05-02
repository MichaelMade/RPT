//
//  HomeViewModelTests.swift
//  RPTTests
//
//  Created by Michael Moore on 5/2/25.
//

import XCTest
@testable import RPT

@MainActor
final class HomeViewModelTests: XCTestCase {
    var viewModel: HomeViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = HomeViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Format Total Volume Tests
    
    func testFormatTotalVolume_nil() {
        // Given - no user stats
        viewModel.userStats = nil
        
        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()
        
        // Then - should return "0"
        XCTAssertEqual(formattedVolume, "0", "Format should return '0' when userStats is nil")
    }
    
    func testFormatTotalVolume_zero() {
        // Given - user stats with zero volume
        viewModel.userStats = (totalWorkouts: 0, totalVolume: 0.0, workoutStreak: 0)
        
        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()
        
        // Then - should return "0"
        XCTAssertEqual(formattedVolume, "0", "Format should return '0' for zero volume")
    }
    
    func testFormatTotalVolume_wholeNumber() {
        // Given - user stats with whole number volume
        viewModel.userStats = (totalWorkouts: 10, totalVolume: 5000.0, workoutStreak: 5)
        
        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()
        
        // Then - should return "5k" (no decimal)
        XCTAssertEqual(formattedVolume, "5k", "Format should return whole number for round thousands")
    }
    
    func testFormatTotalVolume_belowThreshold() {
        // Given - user stats with volume below 1000
        viewModel.userStats = (totalWorkouts: 5, totalVolume: 950.0, workoutStreak: 3)
        
        // When - format total volume
        let formattedVolume = viewModel.formatTotalVolume()
        
        // Then - should return "950" (no decimal, no 'k')
        XCTAssertEqual(formattedVolume, "950", "Format should return integer without decimal for volume below 1000")
    }
    
    // MARK: - Weekly Progress Tests
    
    func testCalculateWeeklyProgress_noWorkouts() {
        // This test requires a mock WorkoutManager to control the returned stats
        // For now, we'll just verify the method exists and returns a valid value
        let progress = viewModel.calculateWeeklyProgress()
        
        // Progress should be in range 0-1
        XCTAssertGreaterThanOrEqual(progress, 0.0, "Progress should be at least 0")
        XCTAssertLessThanOrEqual(progress, 1.0, "Progress should be at most 1.0")
    }
}
