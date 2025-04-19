//
//  Character.swift
//  ZombicideCharacters
//
//  Created by Stephen Parker on 4/11/25.
//

import Foundation
import SwiftData

@Model
class Character {
    // Remove unique constraint as it's not supported with CloudKit
    var name: String = ""
    var set: String?
    var notes: String?
    
    // Many-to-many relationship with skills - made optional for CloudKit compatibility
    var skills: [Skill]? = []
    
    // Deprecated: Kept for migration purposes only
    @Transient
    var allSkills: [String] {
        get {
            return (skills ?? []).sorted { $0.position < $1.position }.map { $0.name }
        }
        set {
            // Migration support: This will be used when loading old data
            // Convert string skills to Skill objects
            let existingSkillNames = Set((skills ?? []).map { $0.name })
            let newSkillsSet = Set(newValue)
            
            // Create skills array if nil
            if skills == nil {
                skills = []
            }
            
            // Remove skills that are no longer present
            skills?.removeAll { !newSkillsSet.contains($0.name) }
            
            // Add new skills
            for (index, skillName) in newValue.enumerated() {
                if !existingSkillNames.contains(skillName) {
                    // Create a new skill
                    let newSkill = Skill(name: skillName, position: index, manual: true)
                    skills?.append(newSkill)
                } else {
                    // Update position of existing skill
                    if let skill = skills?.first(where: { $0.name == skillName }) {
                        skill.position = index
                    }
                }
            }
        }
    }
    
    init(name: String, set: String? = nil, allSkills: [String] = [], notes: String? = nil) {
        self.name = name
        self.set = set
        self.notes = notes
        self.skills = [] // Initialize with empty array
        
        // Convert string skills to Skill objects
        for (index, skillName) in allSkills.enumerated() {
            let skill = Skill(name: skillName, position: index, manual: true)
            
            // Add the relationship
            skills?.append(skill)
        }
    }
}