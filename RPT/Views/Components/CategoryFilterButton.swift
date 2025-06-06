//
//  CategoryFilterButton.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import SwiftUI
import SwiftData

struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        // Unselected filter
        CategoryFilterButton(
            title: "Compound",
            isSelected: false
        ) {
            // Action would go here
        }
        
        // Selected filter
        CategoryFilterButton(
            title: "Isolation",
            isSelected: true
        ) {
            // Action would go here
        }
    }
    .padding()
}
