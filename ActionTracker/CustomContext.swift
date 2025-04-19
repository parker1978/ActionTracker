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
            // Delete existing characters first
            for character in try context.fetch(FetchDescriptor<Character>()) {
                context.delete(character)
            }

            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = content.components(separatedBy: CharacterSet.newlines).dropFirst()
            
            // Parse and insert new characters
            for line in rows {
                guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                let columns = parseCSVLine(line)
                guard columns.count >= 4 else { continue }

                // Clean and normalize input data
                let rawName = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let name = rawName.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                
                let rawSet = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let set = rawSet.isEmpty ? nil : rawSet.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                
                let rawNotes = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                let notes = rawNotes.isEmpty ? nil : rawNotes.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                
                // Clean each skill name by trimming and normalizing whitespace
                let skills = columns[3].split(separator: ";").map { skillName -> String in
                    let trimmed = skillName.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                }

                // Create the character first
                let newChar = Character(name: name, set: set, notes: notes)
                context.insert(newChar)
                
                // Create skills with the import flag set to true
                for (index, skillName) in skills.enumerated() {
                    // Check if skill already exists in the database
                    let skillDescriptor = FetchDescriptor<Skill>(predicate: #Predicate<Skill> { skill in skill.name == skillName })
                    var existingSkill: Skill?
                    
                    do {
                        existingSkill = try context.fetch(skillDescriptor).first
                    } catch {
                        print("Error fetching skill: \(error)")
                    }
                    
                    // Use existing skill or create a new one
                    if let skill = existingSkill {
                        // Add relationship to the character
                        if skill.characters == nil {
                            skill.characters = []
                        }
                        if newChar.skills == nil {
                            newChar.skills = []
                        }
                        
                        if !((skill.characters ?? []).contains(where: { $0.id == newChar.id })) {
                            skill.characters?.append(newChar)
                            // Set the proper position for this character
                            if let characterSkill = (newChar.skills ?? []).first(where: { $0.id == skill.id }) {
                                characterSkill.position = index
                            }
                        }
                    } else {
                        // Create a new skill with the import flag
                        let newSkill = Skill(name: skillName, position: index, importedFlag: true)
                        
                        // Initialize arrays if needed
                        if newSkill.characters == nil {
                            newSkill.characters = []
                        }
                        if newChar.skills == nil {
                            newChar.skills = []
                        }
                        
                        newSkill.characters?.append(newChar)
                        newChar.skills?.append(newSkill)
                        context.insert(newSkill)
                    }
                }
            }
            
            // Save changes immediately
            try context.save()
            
            // Call completion handler if provided
            DispatchQueue.main.async {
                self.importCompletionHandler?()
            }
            
            print("Import successful: \(rows.count) characters")
        } catch {
            print("Import failed: \(error)")
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
