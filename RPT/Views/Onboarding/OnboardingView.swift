//
//  OnboardingView.swift
//  RPT
//
//  Three-page welcome explaining reverse pyramid training and the app.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

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

            Button {
                if currentPage < pages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    hasCompletedOnboarding = true
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "Continue" : "Start Training")
            }
            .buttonStyle(BrandButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            if currentPage < pages.count - 1 {
                Button("Skip") {
                    hasCompletedOnboarding = true
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
            }
        }
        .background(Theme.screenBackground)
    }
}
