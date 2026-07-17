import XCTest
@testable import RPT

final class OnboardingLaunchPlanTests: XCTestCase {
    func testStarterTemplateTargetsHomeWithoutComposer() {
        XCTAssertEqual(OnboardingLaunchPlan.starterTemplate.rootTab, .home)
        XCTAssertEqual(OnboardingLaunchPlan.starterTemplate.starterTemplateName, "RPT Day 1 - Deadlift")
        XCTAssertFalse(OnboardingLaunchPlan.starterTemplate.shouldShowTemplateComposer)
        XCTAssertNil(OnboardingLaunchPlan.starterTemplate.emptyWorkoutName)
    }

    func testCreateTemplateTargetsTemplatesAndShowsComposer() {
        XCTAssertEqual(OnboardingLaunchPlan.createTemplate.rootTab, .templates)
        XCTAssertTrue(OnboardingLaunchPlan.createTemplate.shouldShowTemplateComposer)
        XCTAssertNil(OnboardingLaunchPlan.createTemplate.starterTemplateName)
        XCTAssertNil(OnboardingLaunchPlan.createTemplate.emptyWorkoutName)
    }

    func testEmptyWorkoutStartsNamedFirstWorkout() {
        XCTAssertEqual(OnboardingLaunchPlan.emptyWorkout.rootTab, .home)
        XCTAssertEqual(OnboardingLaunchPlan.emptyWorkout.emptyWorkoutName, "First Workout")
        XCTAssertFalse(OnboardingLaunchPlan.emptyWorkout.shouldShowTemplateComposer)
        XCTAssertNil(OnboardingLaunchPlan.emptyWorkout.starterTemplateName)
    }
}
