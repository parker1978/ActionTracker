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
    var isFavorite: Bool = false
    
    // Many-to-many relationship with skills - made optional for CloudKit compatibility
    var blueSkills: [String] = []
    var orangeSkills: [String] = []
    var redSkills: [String] = []
    
    // Active skills per power level 
    var activeBlueSkills: [String] = []
    var activeOrangeSkills: [String] = []
    var activeRedSkills: [String] = []
    
    // Optional relationship for CloudKit compatibility
    @Relationship(deleteRule: .cascade)
    var skills: [Skill]? = []
    
    init(name: String, set: String? = nil, notes: String? = nil, isFavorite: Bool = false, blueSkills: [String] = [], orangeSkills: [String] = [], redSkills: [String] = []) {
        self.name = name
        self.set = set
        self.notes = notes
        self.isFavorite = isFavorite
        
        print("CHARACTER INITIALIZATION")
        print("Creating new character: \(name) with blue: \(blueSkills.count), orange: \(orangeSkills.count), red: \(redSkills.count) skills")
        
        // Store skill lists exactly as provided - no modification
        self.blueSkills = blueSkills
        self.orangeSkills = orangeSkills
        self.redSkills = redSkills
        
        // Blue skills start active by default
        self.activeBlueSkills = self.blueSkills
        
        // Make sure skills array is empty to start with
        skills = []
        
        // Only create skill objects if we have actual skills
        if !blueSkills.isEmpty || !orangeSkills.isEmpty || !redSkills.isEmpty {
            // Create a brand new skills array for this character
            // with absolutely no existing entries
            skills = []
            
            // Convert string skills to Skill objects
            var skillPosition = 0
            
            // Create skills in color order - blue, orange, red
            // Use the exact lists provided with no deduplication
            for skillName in blueSkills {
                let skill = Skill(name: skillName, position: skillPosition, manual: true, color: .blue)
                skills?.append(skill)
                print("Created skill: \(skillName) (Color: blue, Position: \(skillPosition))")
                skillPosition += 1
            }
    
            for skillName in orangeSkills {
                let skill = Skill(name: skillName, position: skillPosition, manual: true, color: .orange)
                skills?.append(skill)
                print("Created skill: \(skillName) (Color: orange, Position: \(skillPosition))")
                skillPosition += 1
            }
    
            for skillName in redSkills {
                let skill = Skill(name: skillName, position: skillPosition, manual: true, color: .red)
                skills?.append(skill)
                print("Created skill: \(skillName) (Color: red, Position: \(skillPosition))")
                skillPosition += 1
            }
            
            print("Created \(skills?.count ?? 0) skills for character \(name)")
        }
        
        // Verify skills
        if let skillList = skills {
            print("Found \(skillList.count) skills for character \(name)")
            for skill in skillList {
                print("Loaded skill: \(skill.name) (Color: \(String(describing: skill.color)), Position: \(skill.position))")
            }
        }
    }
    
    // Returns all active skills in proper order (blue, orange, red) - optimized version
    func allActiveSkills() -> [String] {
        // Pre-allocate capacity to avoid multiple array resizing operations
        var result = [String]()
        result.reserveCapacity(activeBlueSkills.count + activeOrangeSkills.count + activeRedSkills.count)
        
        // Append using a single operation for each color
        result.append(contentsOf: activeBlueSkills)
        result.append(contentsOf: activeOrangeSkills)
        result.append(contentsOf: activeRedSkills)
        
        return result
    }
    
    // Activates a skill based on experience level
    func activateSkill(name: String, color: SkillColor) -> Bool {
        switch color {
        case .blue:
            // Blue skills are always active by default
            if !activeBlueSkills.contains(name) && blueSkills.contains(name) {
                activeBlueSkills.append(name)
                return true
            }
        case .orange:
            if !activeOrangeSkills.contains(name) && orangeSkills.contains(name) {
                activeOrangeSkills.append(name)
                return true
            }
        case .red:
            if !activeRedSkills.contains(name) && redSkills.contains(name) {
                activeRedSkills.append(name)
                return true
            }
        }
        return false
    }
    
    // Deactivates a skill
    func deactivateSkill(name: String, color: SkillColor) -> Bool {
        switch color {
        case .blue:
            if let index = activeBlueSkills.firstIndex(of: name) {
                activeBlueSkills.remove(at: index)
                return true
            }
        case .orange:
            if let index = activeOrangeSkills.firstIndex(of: name) {
                activeOrangeSkills.remove(at: index)
                return true
            }
        case .red:
            if let index = activeRedSkills.firstIndex(of: name) {
                activeRedSkills.remove(at: index)
                return true
            }
        }
        return false
    }
    
    // Returns skills that can be activated based on experience level
    func availableSkillsForExperience(_ experience: Int) -> (blue: [String], orange: [String], red: [String]) {
        // Blue skills are always available
        let availableBlueSkills = blueSkills.filter { !activeBlueSkills.contains($0) }
        
        // Orange skills become available at XP 19
        var availableOrangeSkills: [String] = []
        
        // Calculate how many orange skills can be activated based on XP
        if experience >= 19 {
            let cyclesPast19 = (experience - 19) / 43
            let maxActiveOrange = 1 + cyclesPast19
            if activeOrangeSkills.count < maxActiveOrange {
                availableOrangeSkills = orangeSkills.filter { !activeOrangeSkills.contains($0) }
            }
        }
        
        // Red skills become available at XP 43
        var availableRedSkills: [String] = []
        
        // Calculate how many red skills can be activated based on XP
        if experience >= 43 {
            let cyclesPast43 = (experience - 43) / 43 + 1
            let maxActiveRed = cyclesPast43
            if activeRedSkills.count < maxActiveRed {
                availableRedSkills = redSkills.filter { !activeRedSkills.contains($0) }
            }
        }
        
        return (availableBlueSkills, availableOrangeSkills, availableRedSkills)
    }
}
