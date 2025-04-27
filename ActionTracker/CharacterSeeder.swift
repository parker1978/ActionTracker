//
//  CharacterSeeder.swift
//  ActionTracker
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
        // For each character, we'll group skills by color
        
        // Fred's skills by color
        let fredBlueSkills: [(name: String, description: String)] = [
            ("Reaper: Combat", "Deal 1 damage to all Zombies in the same zone after combat"),
            ("+1 Free Combat Action", "Get one additional combat action per turn")
        ]
        
        let fredOrangeSkills: [(name: String, description: String)] = [
            ("Dreadnought: Walker", "Walker attacks do not cause damage to this character"),
            ("+1 Die: Combat", "Add 1 die to combat rolls")
        ]
        
        let fredRedSkills: [(name: String, description: String)] = [
            ("+1 Free Combat Action", "Get one additional combat action per turn"),
            ("+1 To Dice Roll: Combat", "Add 1 to each die rolled in combat")
        ]
        
        // Bunny's skills by color
        let bunnyBlueSkills: [(name: String, description: String)] = [
            ("Lucky", "Re-roll one failed die per turn"),
            ("+1 To Dice Roll: Melee", "Add 1 to each melee die roll")
        ]
        
        let bunnyOrangeSkills: [(name: String, description: String)] = [
            ("Jump", "Move through zones with zombies without spending extra actions"),
            ("+1 Damage: Melee", "Add 1 damage to successful melee attacks")
        ]
        
        let bunnyRedSkills: [(name: String, description: String)] = [
            ("+1 Free Combat Action", "Get one additional combat action per turn"),
            ("Roll 6: +1 Die Combat", "When rolling a 6 in combat, get an extra die")
        ]
        
        // Tiger's skills by color
        let tigerBlueSkills: [(name: String, description: String)] = [
            ("+1 Die: Ranged", "Add 1 die to ranged attack rolls"),
            ("+1 Free Move Action", "Get one additional move action per turn")
        ]
        
        let tigerOrangeSkills: [(name: String, description: String)] = [
            ("Sniper", "Ignore range penalties when using ranged weapons"),
            ("+1 Damage: Ranged", "Add 1 damage to successful ranged attacks")
        ]
        
        let tigerRedSkills: [(name: String, description: String)] = [
            ("+1 Free Combat Action", "Get one additional combat action per turn"),
            ("Shove", "Push zombies to an adjacent zone once per turn")
        ]
        
        // Extract skill names for Character initialization
        let fredBlueSkillNames = fredBlueSkills.map { $0.name }
        let fredOrangeSkillNames = fredOrangeSkills.map { $0.name }
        let fredRedSkillNames = fredRedSkills.map { $0.name }
        
        let bunnyBlueSkillNames = bunnyBlueSkills.map { $0.name }
        let bunnyOrangeSkillNames = bunnyOrangeSkills.map { $0.name }
        let bunnyRedSkillNames = bunnyRedSkills.map { $0.name }
        
        let tigerBlueSkillNames = tigerBlueSkills.map { $0.name }
        let tigerOrangeSkillNames = tigerOrangeSkills.map { $0.name }
        let tigerRedSkillNames = tigerRedSkills.map { $0.name }
        
        // Create characters with their skills
        let fred = Character(
            name: "Fred",
            blueSkills: fredBlueSkillNames,
            orangeSkills: fredOrangeSkillNames,
            redSkills: fredRedSkillNames
        )
        
        let bunny = Character(
            name: "Bunny G",
            blueSkills: bunnyBlueSkillNames,
            orangeSkills: bunnyOrangeSkillNames,
            redSkills: bunnyRedSkillNames
        )
        
        let tiger = Character(
            name: "Tiger Sam",
            blueSkills: tigerBlueSkillNames,
            orangeSkills: tigerOrangeSkillNames,
            redSkills: tigerRedSkillNames
        )
        
        // Insert characters into context
        context.insert(fred)
        context.insert(bunny)
        context.insert(tiger)
        
        // Skill creation helper function
        func createSkillIfNeeded(name: String, description: String, color: SkillColor, position: Int, character: Character) {
            // First normalize using the static method
            let normalizedName = Skill.normalizeSkillName(name)
            
            // Check if skill already exists
            var descriptor = FetchDescriptor<Skill>()
            descriptor.predicate = #Predicate<Skill> { skill in
                skill.name == normalizedName
            }
            
            do {
                if let existingSkill = try context.fetch(descriptor).first {
                    // Use existing skill
                    if existingSkill.skillDescription.isEmpty {
                        existingSkill.skillDescription = description
                    }
                    
                    // Ensure character relationship
                    if existingSkill.characters == nil {
                        existingSkill.characters = []
                    }
                    
                    if !existingSkill.characters!.contains(where: { $0.id == character.id }) {
                        existingSkill.characters?.append(character)
                    }
                } else {
                    // Create new skill
                    let newSkill = Skill(
                        name: name,
                        skillDescription: description,
                        position: position,
                        manual: false,
                        color: color
                    )
                    context.insert(newSkill)
                    
                    // Set up relationship
                    if newSkill.characters == nil {
                        newSkill.characters = []
                    }
                    newSkill.characters?.append(character)
                    
                    // The Character init has already created the skills,
                    // but we need to ensure our new skill objects are linked
                    // Back-reference not needed since Character already has the skills
                }
            } catch {
                print("Error checking for existing skill '\(name)': \(error)")
                
                // Create new skill as fallback
                let newSkill = Skill(
                    name: name, 
                    skillDescription: description,
                    position: position,
                    manual: false,
                    color: color
                )
                context.insert(newSkill)
                
                // Set up relationship
                if newSkill.characters == nil {
                    newSkill.characters = []
                }
                newSkill.characters?.append(character)
            }
        }
        
        // Process Fred's skills
        var position = 0
        for (name, description) in fredBlueSkills {
            createSkillIfNeeded(name: name, description: description, color: .blue, position: position, character: fred)
            position += 1
        }
        for (name, description) in fredOrangeSkills {
            createSkillIfNeeded(name: name, description: description, color: .orange, position: position, character: fred)
            position += 1
        }
        for (name, description) in fredRedSkills {
            createSkillIfNeeded(name: name, description: description, color: .red, position: position, character: fred)
            position += 1
        }
        
        // Process Bunny's skills
        position = 0
        for (name, description) in bunnyBlueSkills {
            createSkillIfNeeded(name: name, description: description, color: .blue, position: position, character: bunny)
            position += 1
        }
        for (name, description) in bunnyOrangeSkills {
            createSkillIfNeeded(name: name, description: description, color: .orange, position: position, character: bunny)
            position += 1
        }
        for (name, description) in bunnyRedSkills {
            createSkillIfNeeded(name: name, description: description, color: .red, position: position, character: bunny)
            position += 1
        }
        
        // Process Tiger's skills
        position = 0
        for (name, description) in tigerBlueSkills {
            createSkillIfNeeded(name: name, description: description, color: .blue, position: position, character: tiger)
            position += 1
        }
        for (name, description) in tigerOrangeSkills {
            createSkillIfNeeded(name: name, description: description, color: .orange, position: position, character: tiger)
            position += 1
        }
        for (name, description) in tigerRedSkills {
            createSkillIfNeeded(name: name, description: description, color: .red, position: position, character: tiger)
            position += 1
        }
        
        // Save changes
        do {
            try context.save()
            print("Successfully saved seed characters with their skills")
        } catch {
            print("Failed to save seed characters: \(error)")
        }
    }
}