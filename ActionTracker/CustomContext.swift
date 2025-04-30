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
                
                // We're going to completely avoid looking up or creating relationships 
                // with existing skills to prevent cross-contamination issues
                
                // Just to be safe, make sure each character has their own independent skills with no shared references
                print("IMPORT: Character \(newChar.name) has \(newChar.skills?.count ?? 0) skills")
                
                // Delete any skills that this character shouldn't have (sanity check)
                // If the skill's name is not in any of the color lists, remove it
                if let skills = newChar.skills {
                    var skillsToRemove = [UUID]()
                    
                    for skill in skills {
                        let skillName = skill.name
                        let skillColor = skill.color
                        
                        // Check if this skill should belong to this character
                        var shouldKeep = false
                        
                        switch skillColor {
                        case .blue:
                            shouldKeep = newChar.blueSkills.contains(skillName)
                        case .orange:
                            shouldKeep = newChar.orangeSkills.contains(skillName)
                        case .red:
                            shouldKeep = newChar.redSkills.contains(skillName)
                        case .none:
                            shouldKeep = false
                        }
                        
                        if !shouldKeep {
                            print("REMOVING INVALID SKILL: \(skillName) (\(String(describing: skillColor))) from \(newChar.name)")
                            skillsToRemove.append(skill.id)
                        }
                    }
                    
                    // Remove invalid skills
                    for skillID in skillsToRemove {
                        if let index = newChar.skills?.firstIndex(where: { $0.id == skillID }) {
                            let skillToRemove = newChar.skills?[index]
                            newChar.skills?.remove(at: index)
                            if let skillToRemove = skillToRemove {
                                context.delete(skillToRemove)
                            }
                        }
                    }
                }
                
                // Final verification
                print("IMPORT: After cleanup, \(newChar.name) has \(newChar.skills?.count ?? 0) skills")
                
                if let skills = newChar.skills {
                    for skill in skills {
                        print("IMPORT: \(newChar.name) has skill: \(skill.name) (color: \(String(describing: skill.color)), position: \(skill.position))")
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
