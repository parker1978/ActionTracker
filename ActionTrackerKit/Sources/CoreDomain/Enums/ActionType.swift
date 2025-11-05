//
//  ActionType.swift
//  CoreDomain
//
//  Types of actions available in Zombicide gameplay.
//  Each type has a unique icon, color, and display name.
//

import Foundation
import SwiftUI

/// Types of actions available in Zombicide gameplay
/// Each type has a unique icon, color, and display name
public enum ActionType: String, Codable, CaseIterable {
    case action  // Generic action (default)
    case combat  // Combined melee/ranged attack
    case melee   // Close-range attack
    case ranged  // Long-range attack
    case move    // Movement between zones
    case search  // Search for equipment

    /// User-friendly display name for the action type
    public var displayName: String {
        switch self {
        case .action: return "Action"
        case .combat: return "Combat"
        case .melee: return "Melee"
        case .ranged: return "Ranged"
        case .move: return "Move"
        case .search: return "Search"
        }
    }

    /// SF Symbol icon name for the action type
    public var icon: String {
        switch self {
        case .action: return "bolt.fill"
        case .combat: return "flame.fill"
        case .melee: return "hammer.fill"
        case .ranged: return "scope"
        case .move: return "figure.walk"
        case .search: return "magnifyingglass"
        }
    }

    /// Color associated with each action type for UI consistency
    public var color: Color {
        switch self {
        case .action: return .blue
        case .combat: return .red
        case .melee: return .orange
        case .ranged: return .purple
        case .move: return .green
        case .search: return .yellow
        }
    }
}
