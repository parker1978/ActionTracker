//
//  CharacterSeeder.swift
//  ZombicideCharacters
//
//  Created by Stephen Parker on 4/11/25.
//

import SwiftUI
import SwiftData

struct CharacterSeeder: ViewModifier {
    @Environment(\.modelContext) private var context
    @Query var existing: [Character]
    @State private var hasAttemptedSeed = false
    
    // Key for UserDefaults to track first launch
    private let hasLaunchedBeforeKey = "ActionTracker.hasLaunchedBefore"

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Check if app has been launched before
                let hasLaunchedBefore = UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)
                
                // Only proceed if this is the first launch
                if !hasLaunchedBefore {
                    print("First app launch detected, preparing to seed data...")
                    // Add a delay to ensure modelContext is properly set up
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        // Only seed if there are no existing characters AND we haven't attempted to seed yet
                        if !hasAttemptedSeed && existing.isEmpty {
                            // Check if any skills already exist - if so, don't seed
                            let skillDescriptor = FetchDescriptor<Skill>()
                            do {
                                let existingSkills = try context.fetch(skillDescriptor)
                                if existingSkills.isEmpty {
                                    hasAttemptedSeed = true
                                    seedCharacters()
                                    
                                    // Set flag that app has been launched before
                                    UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
                                } else {
                                    print("Skills already exist, skipping seeding")
                                    
                                    // Normalize existing skill names on app startup
                                    normalizeExistingSkillNames(existingSkills)
                                    
                                    hasAttemptedSeed = true
                                    UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
                                }
                            } catch {
                                print("Error checking for existing skills: \(error)")
                                // Proceed with seeding if we can't check
                                hasAttemptedSeed = true
                                seedCharacters()
                                UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
                            }
                        } else {
                            // If we have characters already, mark the app as launched
                            UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
                        }
                    }
                } else {
                    print("App has launched before, skipping initial seed data")
                }
            }
            .task {
                // Secondary attempt only if it's the first launch and the first attempt failed
                if !UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey) && !hasAttemptedSeed && existing.isEmpty {
                    try? await Task.sleep(for: .seconds(2))
                    
                    let skillDescriptor = FetchDescriptor<Skill>()
                    do {
                        let existingSkills = try context.fetch(skillDescriptor)
                        if existingSkills.isEmpty {
                            hasAttemptedSeed = true
                            seedCharacters()
                            UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
                        } else {
                            print("Skills already exist, skipping seeding")
                            
                            // Normalize existing skill names on app startup
                            normalizeExistingSkillNames(existingSkills)
                            
                            hasAttemptedSeed = true
                            UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
                        }
                    } catch {
                        print("Error checking for existing skills: \(error)")
                        // Proceed with seeding if we can't check
                        hasAttemptedSeed = true
                        seedCharacters()
                        UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
                    }
                }
            }
    }

    // Normalizes all existing skill names to ensure consistent capitalization
    private func normalizeExistingSkillNames(_ skills: [Skill]) {
        print("Normalizing existing skill names...")
        
        var changesMade = false
        
        // Go through each skill and normalize its name
        for skill in skills {
            let currentName = skill.name
            let normalizedName = Skill.normalizeSkillName(currentName)
            
            // If the name is different after normalization, update it
            if currentName != normalizedName {
                print("Normalizing skill name from '\(currentName)' to '\(normalizedName)'")
                skill.name = normalizedName
                changesMade = true
            }
        }
        
        // Save changes if needed
        if changesMade {
            do {
                try context.save()
                print("Successfully normalized skill names")
            } catch {
                print("Error saving normalized skill names: \(error)")
            }
        } else {
            print("No skill name normalization needed")
        }
    }
    
    private func seedCharacters() {
        print("Seeding initial character data...")
        // Define character data with skill names and descriptions
        let fredSkillsData: [(name: String, skillDescription: String)] = [
            ("Reaper: Combat", "Deal 1 damage to all Zombies in the same zone after combat"),
            ("+1 Free Combat Action", "Get one additional combat action per turn"),
            ("Dreadnought: Walker", "Walker attacks do not cause damage to this character"),
            ("+1 Die: Combat", "Add 1 die to combat rolls"),
            ("+1 Free Combat Action", "Get one additional combat action per turn"),
            ("+1 To Dice Roll: Combat", "Add 1 to each die rolled in combat")
        ]
        
        let bunnySkillsData: [(name: String, skillDescription: String)] = [
            ("Lucky", "Re-roll one failed die per turn"),
            ("+1 To Dice Roll: Melee", "Add 1 to each melee die roll"),
            ("Jump", "Move through zones with zombies without spending extra actions"),
            ("+1 Damage: Melee", "Add 1 damage to successful melee attacks"),
            ("+1 Free Combat Action", "Get one additional combat action per turn"),
            ("Roll 6: +1 Die Combat", "When rolling a 6 in combat, get an extra die")
        ]
        
        let tigerSkillsData: [(name: String, skillDescription: String)] = [
            ("+1 Die: Ranged", "Add 1 die to ranged attack rolls"),
            ("+1 Free Move Action", "Get one additional move action per turn"),
            ("Sniper", "Ignore range penalties when using ranged weapons"),
            ("+1 Damage: Ranged", "Add 1 damage to successful ranged attacks"),
            ("+1 Free Combat Action", "Get one additional combat action per turn"),
            ("Shove", "Push zombies to an adjacent zone once per turn")
        ]
        
        // Create characters
        let fred = Character(name: "Fred")
        let bunny = Character(name: "Bunny G")
        let tiger = Character(name: "Tiger Sam")
        
        // Initialize skills arrays if needed
        if fred.skills == nil { fred.skills = [] }
        if bunny.skills == nil { bunny.skills = [] }
        if tiger.skills == nil { tiger.skills = [] }
        
        // Create skills with positions and descriptions
        for (index, skillData) in fredSkillsData.enumerated() {
            // Check if skill already exists (case-insensitive)
            let skillName = skillData.name
            // First normalize using the static method
            let normalizedSkillName = Skill.normalizeSkillName(skillName)
            
            // For predicate, we can only use exact matching without string functions
            // Create a non-case-sensitive fetch descriptor
            var descriptor = FetchDescriptor<Skill>()
            descriptor.predicate = #Predicate<Skill> { skill in 
                skill.name == normalizedSkillName
            }
            var skill: Skill
            
            do {
                if let existingSkill = try context.fetch(descriptor).first {
                    // Use existing skill
                    skill = existingSkill
                    // Update description if empty
                    if skill.skillDescription.isEmpty {
                        skill.skillDescription = skillData.skillDescription
                    }
                } else {
                    // Create new skill
                    skill = Skill(name: skillData.name, skillDescription: skillData.skillDescription, position: index, manual: false)
                    context.insert(skill)
                }
                
                // Initialize characters array if needed
                if skill.characters == nil {
                    skill.characters = []
                }
                
                // Add relationship
                skill.characters?.append(fred)
                fred.skills?.append(skill)
            } catch {
                // Create new skill if fetch failed
                skill = Skill(name: skillData.name, skillDescription: skillData.skillDescription, position: index, manual: false)
                context.insert(skill)
                
                // Initialize characters array if needed
                if skill.characters == nil {
                    skill.characters = []
                }
                
                skill.characters?.append(fred)
                fred.skills?.append(skill)
            }
        }
        
        for (index, skillData) in bunnySkillsData.enumerated() {
            // Check if skill already exists (case-insensitive)
            let skillName = skillData.name
            // First normalize using the static method
            let normalizedSkillName = Skill.normalizeSkillName(skillName)
            
            // For predicate, we can only use exact matching without string functions
            // Create a non-case-sensitive fetch descriptor
            var descriptor = FetchDescriptor<Skill>()
            descriptor.predicate = #Predicate<Skill> { skill in 
                skill.name == normalizedSkillName
            }
            var skill: Skill
            
            do {
                if let existingSkill = try context.fetch(descriptor).first {
                    // Use existing skill
                    skill = existingSkill
                    // Update description if empty
                    if skill.skillDescription.isEmpty {
                        skill.skillDescription = skillData.skillDescription
                    }
                } else {
                    // Create new skill
                    skill = Skill(name: skillData.name, skillDescription: skillData.skillDescription, position: index, manual: false)
                    context.insert(skill)
                }
                
                // Initialize characters array if needed
                if skill.characters == nil {
                    skill.characters = []
                }
                
                // Add relationship
                skill.characters?.append(bunny)
                bunny.skills?.append(skill)
            } catch {
                // Create new skill if fetch failed
                skill = Skill(name: skillData.name, skillDescription: skillData.skillDescription, position: index, manual: false)
                context.insert(skill)
                
                // Initialize characters array if needed
                if skill.characters == nil {
                    skill.characters = []
                }
                
                skill.characters?.append(bunny)
                bunny.skills?.append(skill)
            }
        }
        
        for (index, skillData) in tigerSkillsData.enumerated() {
            // Check if skill already exists (case-insensitive)
            let skillName = skillData.name
            // First normalize using the static method
            let normalizedSkillName = Skill.normalizeSkillName(skillName)
            
            // For predicate, we can only use exact matching without string functions
            // Create a non-case-sensitive fetch descriptor
            var descriptor = FetchDescriptor<Skill>()
            descriptor.predicate = #Predicate<Skill> { skill in 
                skill.name == normalizedSkillName
            }
            var skill: Skill
            
            do {
                if let existingSkill = try context.fetch(descriptor).first {
                    // Use existing skill
                    skill = existingSkill
                    // Update description if empty
                    if skill.skillDescription.isEmpty {
                        skill.skillDescription = skillData.skillDescription
                    }
                } else {
                    // Create new skill
                    skill = Skill(name: skillData.name, skillDescription: skillData.skillDescription, position: index, manual: false)
                    context.insert(skill)
                }
                
                // Initialize characters array if needed
                if skill.characters == nil {
                    skill.characters = []
                }
                
                // Add relationship
                skill.characters?.append(tiger)
                tiger.skills?.append(skill)
            } catch {
                // Create new skill if fetch failed
                skill = Skill(name: skillData.name, skillDescription: skillData.skillDescription, position: index, manual: false)
                context.insert(skill)
                
                // Initialize characters array if needed
                if skill.characters == nil {
                    skill.characters = []
                }
                
                skill.characters?.append(tiger)
                tiger.skills?.append(skill)
            }
        }
        
        // Add characters to context
        let characters: [Character] = [fred, bunny, tiger]

        for character in characters {
            context.insert(character)
        }
        
        // Attempt to save changes immediately
        do {
            try context.save()
            print("Successfully saved \(characters.count) seed characters")
        } catch {
            print("Failed to save seed characters: \(error)")
        }
    }
}