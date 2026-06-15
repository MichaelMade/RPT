//
//  OnboardingLaunchPlan.swift
//  RPT
//
//  First-run routing choices that turn onboarding into a concrete next step.
//

import Foundation

enum RootTab: String, Hashable {
    case home
    case templates
    case exercises
    case stats
    case settings
}

enum OnboardingLaunchPlan: Equatable {
    case starterTemplate
    case createTemplate
    case emptyWorkout

    var rootTab: RootTab {
        switch self {
        case .starterTemplate, .emptyWorkout:
            return .home
        case .createTemplate:
            return .templates
        }
    }

    var shouldShowTemplateComposer: Bool {
        self == .createTemplate
    }

    var emptyWorkoutName: String? {
        self == .emptyWorkout ? "First Workout" : nil
    }

    var starterTemplateName: String? {
        self == .starterTemplate ? "Upper Body RPT" : nil
    }
}
