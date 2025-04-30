//
//  OnboardingView.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    
    var body: some View {
        TabView(selection: $currentPage) {
            OnboardingPage(
                title: "Welcome to RPT Trainer",
                description: "Your all-in-one app for Reverse Pyramid Training",
                imageName: "dumbbell.fill",
                buttonText: "Next",
                buttonAction: {
                    withAnimation {
                        currentPage = 1
                    }
                }
            )
            .tag(0)
            
            OnboardingPage(
                title: "Track Your Workouts",
                description: "Log your weights, reps, and sets with our easy-to-use interface",
                imageName: "list.bullet.clipboard.fill",
                buttonText: "Next",
                buttonAction: {
                    withAnimation {
                        currentPage = 2
                    }
                }
            )
            .tag(1)
            
            OnboardingPage(
                title: "Monitor Your Progress",
                description: "Visualize your strength gains over time with detailed charts",
                imageName: "chart.line.uptrend.xyaxis.circle.fill",
                buttonText: "Next",
                buttonAction: {
                    withAnimation {
                        currentPage = 3
                    }
                }
            )
            .tag(2)
            
            OnboardingPage(
                title: "Ready to Start?",
                description: "Begin your journey to increased strength with Reverse Pyramid Training",
                imageName: "figure.strengthtraining.traditional",
                buttonText: "Get Started",
                buttonAction: {
                    hasCompletedOnboarding = true
                }
            )
            .tag(3)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .animation(.default, value: currentPage)
    }
}

// Individual onboarding page
struct OnboardingPage: View {
    let title: String
    let description: String
    let imageName: String
    let buttonText: String
    let buttonAction: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: imageName)
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: buttonAction) {
                Text(buttonText)
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
    }
}
