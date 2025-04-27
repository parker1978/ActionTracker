//
//  Context.swift
//  ZombicideCharacters
//
//  Created by Stephen Parker on 4/12/25.
//

import SwiftUI
import SwiftData

class CustomContext: NSObject, UIDocumentPickerDelegate {
    static let shared = CustomContext()
    private var modelContext: ModelContext?
    private var importCompletionHandler: (() -> Void)?

    func configure(with context: ModelContext, completion: (() -> Void)? = nil) {
        self.modelContext = context
        self.importCompletionHandler = completion
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let context = self.modelContext else { 
            print("ModelContext not available")
            return 
        }

        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access security-scoped resource.")
            return
        }

        defer { url.stopAccessingSecurityScopedResource() } // 🧹 Clean up after

        do {
            print("==== IMPORT STARTED: Current context = \(context) ====")
            
            // Delete existing characters first - handle with care
            let existingCharacters = try context.fetch(FetchDescriptor<Character>())
            print("Found \(existingCharacters.count) existing characters to delete")
            
            for character in existingCharacters {
                context.delete(character)
            }
            
            // Save the deletion before continuing
            try context.save()
            print("Deleted all existing characters")

            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = content.components(separatedBy: CharacterSet.newlines).dropFirst()
            
            // Create a single test character with no skills first to verify basic persistence
            print("Creating a minimal test character for verification")
            let minimalCharacter = Character(name: "MINIMAL TEST")
            context.insert(minimalCharacter)
            try context.save()
            
            // Verify the test character was saved
            let testVerify = try context.fetch(FetchDescriptor<Character>())
            print("After minimal character insertion: \(testVerify.count) characters, name: \(testVerify.first?.name ?? "none")")
            
            // Parse and insert new characters
            for line in rows {
                guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                let columns = parseCSVLine(line)
                guard columns.count >= 6 else { continue } // New format requires 6 columns (Name,Set,Notes,Blue,Orange,Red)

                // Clean and normalize input data
                let rawName = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let name = rawName.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                
                let rawSet = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let set = rawSet.isEmpty ? nil : rawSet.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                
                let rawNotes = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                let notes = rawNotes.isEmpty ? nil : rawNotes.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                
                // Process each color of skills separately
                let blueSkills = parseSkillList(columns[3])
                let orangeSkills = parseSkillList(columns[4])
                let redSkills = parseSkillList(columns[5])

                // Create the character with all its skills
                let newChar = Character(name: name, set: set, notes: notes, 
                                        blueSkills: blueSkills, 
                                        orangeSkills: orangeSkills, 
                                        redSkills: redSkills)
                
                context.insert(newChar)
                
                // Blue skills are already marked as active in the Character initializer
                
                // Process and create the actual Skill objects - this is now handled in the Character initializer,
                // but we need to ensure the skills exist in the database
                for skill in (newChar.skills ?? []) {
                    // Check if the same skill (by name) already exists without predicate
                    // Fetch all skills and filter manually
                    let skillDescriptor = FetchDescriptor<Skill>()
                    
                    do {
                        let allSkills = try context.fetch(skillDescriptor)
                        if let existingSkill = allSkills.first(where: { $0.name == skill.name && $0.id != skill.id }) {
                            // If the skill already exists with a different ID, use the existing one
                            // and update its relationship to include this character
                            if existingSkill.characters == nil {
                                existingSkill.characters = []
                            }
                            
                            // Add this character to the existing skill's relationships
                            if !((existingSkill.characters ?? []).contains(where: { $0.id == newChar.id })) {
                                existingSkill.characters?.append(newChar)
                            }
                            
                            // Remove the new skill from the character and replace with existing one
                            if let skills = newChar.skills, let index = skills.firstIndex(where: { $0.id == skill.id }) {
                                newChar.skills?.remove(at: index)
                                newChar.skills?.append(existingSkill)
                                
                                // Delete the duplicate skill
                                context.delete(skill)
                            }
                        }
                    } catch {
                        print("Error checking for existing skill: \(error)")
                    }
                }
            }
            
            // Save changes immediately
            try context.save()
            
            // Double-check the fetch after save to verify persistence
            let verifyDescriptor = FetchDescriptor<Character>()
            let verifyResults = try context.fetch(verifyDescriptor)
            let verifyCount = verifyResults.count
            
            print("Verified after save: \(verifyCount) characters in context")
            if verifyCount > 0 {
                // Print the first 5 character names to verify content
                let names = verifyResults.prefix(5).map { $0.name }.joined(separator: ", ")
                print("First 5 character names: \(names)")
            }
            
            // Call completion handler if provided
            DispatchQueue.main.async {
                self.importCompletionHandler?()
                
                // Post a notification for any observers that data has changed
                NotificationCenter.default.post(name: NSNotification.Name("RefreshCharacterData"), object: nil)
            }
            
            print("Import successful: \(rows.count) characters")
        } catch {
            print("Import failed: \(error)")
        }
    }
    
    // Helper function to parse a semicolon-separated list of skills
    private func parseSkillList(_ skillsString: String) -> [String] {
        return skillsString.split(separator: ";").map { skillName -> String in
            let trimmed = skillName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        }
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var results: [String] = []
        var value = ""
        var insideQuotes = false

        var iterator = line.makeIterator()
        while let char = iterator.next() {
            switch char {
            case "\"":
                insideQuotes.toggle()
            case ",":
                if insideQuotes {
                    value.append(char)
                } else {
                    results.append(value)
                    value = ""
                }
            default:
                value.append(char)
            }
        }
        results.append(value)
        return results.map { $0.replacingOccurrences(of: "\"\"", with: "\"") }
    }
}
