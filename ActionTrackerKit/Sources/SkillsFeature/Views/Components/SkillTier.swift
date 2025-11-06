//
//  SkillTier.swift
//  SkillsFeature
//
//  Created by Stephen Parker on 6/6/25.
//

import SwiftUI

public enum SkillTier: String, Identifiable {
    case blue
    case orange
    case red

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.capitalized
    }

    public var color: Color {
        switch self {
        case .blue: return .blue
        case .orange: return .orange
        case .red: return .red
        }
    }
}
