//
//  SkillColorExtension.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/27/25.
//

import SwiftUI

extension Color {
    // Skill colors as constants
    static let skillBlue = Color(red: 0.0, green: 0.5, blue: 1.0)
    static let skillOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let skillRed = Color(red: 1.0, green: 0.2, blue: 0.2)
    
    // Get color from SkillColor enum
    static func forSkill(_ color: SkillColor) -> Color {
        switch color {
        case .blue:
            return skillBlue
        case .orange:
            return skillOrange
        case .red:
            return skillRed
        }
    }
}