//
//  SkillLevel.swift
//  CoreDomain
//
//  Four skill tiers in Zombicide based on experience points.
//  Characters unlock higher tiers as they gain XP within each cycle.
//

import Foundation

/// Four skill tiers in Zombicide based on experience points
/// Characters unlock higher tiers as they gain XP within each cycle
public enum SkillLevel: String, Codable, CaseIterable {
    case blue    // Starting tier (0-6 XP)
    case yellow  // Second tier (7-18 XP)
    case orange  // Third tier (19-42 XP)
    case red     // Final tier (43+ XP)

    /// User-friendly display name (capitalized color)
    public var displayName: String {
        rawValue.capitalized
    }

    /// XP range for this skill level within a single cycle
    public var xpRange: ClosedRange<Int> {
        switch self {
        case .blue: return 0...6
        case .yellow: return 7...18
        case .orange: return 19...42
        case .red: return 43...Int.max
        }
    }
}
