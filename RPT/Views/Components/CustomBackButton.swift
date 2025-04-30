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
