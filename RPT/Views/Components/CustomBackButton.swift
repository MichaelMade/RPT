//
//  CustomBackButtonView.swift
//  RPT
//
//  Created by Michael Moore on 4/29/25.
//

import SwiftUI

// Custom back button component with callback instead of direct binding
struct CustomBackButton: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                Text("Back")
                    .fontWeight(.regular)
            }
            .foregroundColor(.blue)
        }
    }
}

#Preview {
    NavigationStack {
        VStack {
            HStack {
                CustomBackButton {
                    // This would handle the back action in a real app
                    print("Back button tapped")
                }
                Spacer()
            }
            .padding(.horizontal)
            
            Spacer()
            
            Text("Content View")
                .font(.title)
            
            Spacer()
        }
        .navigationTitle("Custom Back Button")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
}
