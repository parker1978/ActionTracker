//
//  Color+DifficultyLevel.swift
//  SharedUI
//
//  Color extension for DifficultyLevel.
//  Maps difficulty levels to their corresponding colors.
//

import SwiftUI
import CoreDomain

public extension DifficultyLevel {
    /// Returns the color associated with this difficulty level
    var color: Color {
        switch self {
        case .blue:
            return .blue
        case .yellow:
            return .yellow
        case .orange:
            return .orange
        case .red:
            return .red
        }
    }
}
