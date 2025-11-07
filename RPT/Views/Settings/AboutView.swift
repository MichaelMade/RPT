//
//  AboutView.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI
import SwiftData

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("RPT Trainer")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Your personal reverse pyramid training assistant")
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            
            Section(header: Text("About Reverse Pyramid Training")) {
                Text("Reverse Pyramid Training (RPT) is a training method where you start with your heaviest set first, then reduce the weight and increase the reps for subsequent sets.")
            }
            
            Section(header: Text("How to Use This App")) {
                Text("1. Create workout templates for your RPT routines")
                Text("2. Track your workouts and rest periods")
                Text("3. Monitor your progress over time")
                Text("4. Use the RPT calculator for ideal weight drops")
            }
            
            Section(header: Text("Support")) {
                if let emailURL = URL(string: "mailto:moore.m@me.com") {
                    Link("Send Feedback", destination: emailURL)
                }
                if let privacyURL = URL(string: "https://www.rpttrainer.com/privacy") {
                    Link("Privacy Policy", destination: privacyURL)
                }
                if let termsURL = URL(string: "https://www.rpttrainer.com/terms") {
                    Link("Terms of Service", destination: termsURL)
                }
            }
            
            Section(header: Text("Credits")) {
                Text("Developed by: Michael Moore")
                Text("© 2025 RPT Trainer. All rights reserved.")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
