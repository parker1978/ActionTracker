//
//  Skill.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/19/25.
//

import Foundation
import SwiftData

@Model
class Skill {
    // Unique identifier for the skill - removed unique constraint for CloudKit compatibility
    var id: UUID = UUID()
    
    // The name of the skill - added default empty string for CloudKit compatibility
    var name: String = ""
    
    // Description of how the skill is used
    var skillDescription: String = ""
    
    // Position in the character's skill list (for maintaining order)
    var position: Int = 0
    
    // Flag to indicate if the skill was manually created
    var manual: Bool = false
    
    // Flag to indicate if the skill was created during a CSV import
    var importedFlag: Bool = false
    
    // Relationship to characters - made optional for CloudKit compatibility
    var characters: [Character]? = []
    
    // Normalizes skill names to be consistent regardless of original case
    static func normalizeSkillName(_ name: String) -> String {
        // First trim leading/trailing spaces
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Then capitalize each word
        return trimmed.capitalized
    }
    
    // Lowercase version of name for case-insensitive comparison
    @Transient
    var normalizedName: String {
        // Get lowercase version for comparison
        return name.lowercased()
    }
    
    init(name: String, skillDescription: String = "", position: Int = 0, manual: Bool = false, importedFlag: Bool = false) {
        // Store the name with consistent capitalization (each word capitalized)
        self.name = Skill.normalizeSkillName(name)
        self.skillDescription = skillDescription
        self.position = position
        self.manual = manual
        self.importedFlag = importedFlag
        self.characters = [] // Initialize as empty array for CloudKit compatibility
    }
}