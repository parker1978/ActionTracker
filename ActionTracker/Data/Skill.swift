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
    
    init(name: String, skillDescription: String = "", position: Int = 0, manual: Bool = false, importedFlag: Bool = false) {
        self.name = name
        self.skillDescription = skillDescription
        self.position = position
        self.manual = manual
        self.importedFlag = importedFlag
        self.characters = [] // Initialize as empty array for CloudKit compatibility
    }
}