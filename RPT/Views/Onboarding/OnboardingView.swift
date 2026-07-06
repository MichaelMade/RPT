//
//  OnboardingView.swift
//  RPT
//
//  First-run education plus an activation handoff into a real next step.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @AppStorage("selectedRootTab") private var selectedRootTabRawValue = RootTab.home.rawValue
    @AppStorage("showCreateTemplateAfterOnboarding") private var showCreateTemplateAfterOnboarding = false
    @State private var currentPage = 0
    @State private var isShowingActivationChoices = false
    @State private var errorMessage: String?

    @ObservedObject private var session = WorkoutSession.shared

    private let templateManager = TemplateManager.shared
    private let workoutManager = WorkoutManager.shared

    private let pages: [(icon: String, title: String, message: String)] = [
        (
            "triangle.fill",
            "Welcome to RPT",
            "Reverse Pyramid Training: hit your heaviest set first while you're fresh, then drop the weight and chase reps."
        ),
        (
            "wand.and.stars",
            "Smart Suggestions",
            "RPT calculates your back-off weights, builds warm-up ramps, and tells you exactly what to attempt next session."
        ),
        (
            "chart.line.uptrend.xyaxis",
            "Watch Yourself Get Stronger",
            "Estimated 1RM trends, weekly volume, muscle balance, streaks, and personal records — all from the sets you log."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            if isShowingActivationChoices {
                activationChoices
            } else {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(spacing: 24) {
                            Spacer()

                            Image(systemName: page.icon)
                                .font(.system(size: 70))
                                .rotationEffect(page.icon == "triangle.fill" ? .degrees(180) : .degrees(0))
                                .foregroundStyle(Theme.brandGradient)

                            Text(page.title)
                                .font(.largeTitle.weight(.heavy))
                                .multilineTextAlignment(.center)

                            Text(page.message)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            Spacer()
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }

            Button {
                if isShowingActivationChoices {
                    completeOnboardingByBrowsing()
                } else if currentPage < pages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    withAnimation {
                        isShowingActivationChoices = true
                    }
                }
            } label: {
                Text(primaryButtonTitle)
            }
            .buttonStyle(BrandButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            if !isShowingActivationChoices && currentPage < pages.count - 1 {
                Button("Skip Intro") {
                    withAnimation {
                        isShowingActivationChoices = true
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
            }
        }
        .background(Theme.screenBackground)
        .alert("Couldn’t Start Training", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private var primaryButtonTitle: String {
        if isShowingActivationChoices {
            return "Browse the App First"
        }

        return currentPage < pages.count - 1 ? "Continue" : "Choose Your First Step"
    }

    private var activationChoices: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 68))
                .foregroundStyle(Theme.brandGradient)

            VStack(spacing: 8) {
                Text("Choose your first win")
                    .font(.largeTitle.weight(.heavy))
                    .multilineTextAlignment(.center)

                Text("Start with a proven template, build your own plan, or jump straight into your first workout.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                activationButton(
                    title: "Start Starter Template",
                    subtitle: "Launch the built-in Upper Body RPT routine"
                ) {
                    completeOnboarding(using: .starterTemplate)
                }

                activationButton(
                    title: "Build My Own Template",
                    subtitle: "Open Templates and start a custom routine"
                ) {
                    completeOnboarding(using: .createTemplate)
                }

                activationButton(
                    title: "Start Empty Workout",
                    subtitle: "Begin logging now and add structure later"
                ) {
                    completeOnboarding(using: .emptyWorkout)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func activationButton(
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func completeOnboarding(using plan: OnboardingLaunchPlan) {
        selectedRootTabRawValue = plan.rootTab.rawValue
        showCreateTemplateAfterOnboarding = plan.shouldShowTemplateComposer

        if let templateName = plan.starterTemplateName {
            guard let template = templateManager.fetchTemplateByName(templateName),
                  let workout = templateManager.createWorkoutFromTemplate(template) else {
                errorMessage = "Couldn’t launch the starter template. Open Templates and try again."
                return
            }

            hasCompletedOnboarding = true
            session.start(workout)
            return
        }

        if let workoutName = plan.emptyWorkoutName {
            guard let workout = workoutManager.createWorkoutSafely(name: workoutName) else {
                errorMessage = "Couldn’t create your first workout. Please try again."
                return
            }

            hasCompletedOnboarding = true
            session.start(workout)
            return
        }

        hasCompletedOnboarding = true
    }

    private func completeOnboardingByBrowsing() {
        selectedRootTabRawValue = RootTab.home.rawValue
        showCreateTemplateAfterOnboarding = false
        hasCompletedOnboarding = true
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
