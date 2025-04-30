//
//  Array+Extensions.swift
//  RPT
//
//  Created by Michael Moore on 4/27/25.
//

import Foundation

// MARK: - Helper Extensions

extension Array {
    /// Safely access array elements with bounds checking
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
