//
//  HeaderView.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/12/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

enum ViewType {
    case action
    case character
}

struct HeaderView: View {
    @Binding var keepAwake: Bool
    @Binding var currentView: ViewType
    @Binding var actionItems: [ActionItem]
    @Binding var isShowingAddCharacter: Bool
    @State private var addWiggle: Bool = false
    @State private var showingSkillLibrary: Bool = false
    
    @Query(sort: \Character.name) var characters: [Character]
    @Environment(\.modelContext) private var context
    
    var body: some View {
        HStack {
            Text(currentView == .action ? "Actions" : "Characters")
                .font(.largeTitle.bold())
            
            Spacer()
            
            // Ensure skill names are always normalized when view appears
            .onAppear {
                normalizeSkillNamesIfNeeded()
            }
            
            Menu {
                Button {
                    keepAwake.toggle()
                    UIApplication.shared.isIdleTimerDisabled = keepAwake
                } label: {
                    Label(keepAwake ? "Disable Keep Awake" : "Enable Keep Awake", systemImage: keepAwake ? "moon" : "sun.max")
                }
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = keepAwake
                }

                Button {
                    withAnimation(.snappy) {
                        currentView = currentView == .action ? .character : .action
                    }
                } label: {
                    Label(currentView == .action ? "Switch to Characters" : "Switch to Actions", systemImage: "arrow.triangle.2.circlepath")
                }
                
                if currentView == .action {
                    Button(role: .destructive) {
                        withAnimation(.easeOut) {
                            actionItems = ActionItem.defaultActions()
                        }
                    } label: {
                        HStack {
                            Text("Reset Actions")
                            Image(systemName: "trash")
                        }
                        .foregroundColor(.red)
                    }
                } else {
                    Button {
                        isShowingAddCharacter = true
                        addWiggle.toggle()
                    } label: {
                        HStack {
                            Text("Add Character")
                            Image(systemName: "plus.circle.fill")
                                .symbolEffect(.wiggle, value: addWiggle)
                        }
                    }
                    
                    Button {
                        showingSkillLibrary = true
                    } label: {
                        Text("Skill Library")
                        Image(systemName: "book.fill")
                    }
                    
                    Button {
                        importCharacters()
                    } label: {
                        Text("Import Characters")
                        Image(systemName: "square.and.arrow.down.fill")
                    }
                    
                    Button {
                        importSkills()
                    } label: {
                        Text("Import Skills")
                        Image(systemName: "square.and.arrow.down.on.square.fill")
                    }
                    
                    Button {
                        exportCharacters()
                    } label: {
                        Text("Export Characters")
                        Image(systemName: "square.and.arrow.up.fill")
                    }
                    
                    Button {
                        exportSkills()
                    } label: {
                        Text("Export Skills")
                        Image(systemName: "square.and.arrow.up.on.square.fill")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        wipeAllCharacters()
                    } label: {
                        Label("Wipe All Characters", systemImage: "trash.fill")
                    }
                    
                    Button(role: .destructive) {
                        wipeAllSkills()
                    } label: {
                        Label("Wipe All Skills", systemImage: "trash.fill")
                    }
                    
                    Button(role: .destructive) {
                        wipeAllData()
                    } label: {
                        Label("Wipe All Data", systemImage: "exclamationmark.triangle.fill")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.largeTitle)
                    .padding()
            }
        }
        .padding(.horizontal)
        .onAppear {
            normalizeSkillNamesIfNeeded()
        }
        .sheet(isPresented: $showingSkillLibrary) {
            SkillView()
        }
    }
    
    private func exportCharacters() {
        // Dictionary to track processed characters by name+set to prevent duplicates
        // Key format is "name|set" in lowercase
        var processedCharacters: [String: Character] = [:]
        
        // First pass - collect unique characters by name+set combo
        for character in characters {
            // Normalize the name and set - trim and fix all whitespace issues
            let trimmedName = character.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = trimmedName.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).lowercased()
            
            let trimmedSet = (character.set ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedSet = trimmedSet.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).lowercased()
            
            // Create a composite key for uniqueness
            let key = "\(normalizedName)|\(normalizedSet)"
            
            // If this name/set combo exists, keep the one with more information
            if let existingChar = processedCharacters[key] {
                // Decide which to keep based on notes and skills
                let existingSkillCount = existingChar.skills?.count ?? 0
                let newSkillCount = character.skills?.count ?? 0
                let existingNotesLength = existingChar.notes?.count ?? 0
                let newNotesLength = character.notes?.count ?? 0
                
                // If the new character has more information, use it instead
                if newSkillCount > existingSkillCount || 
                   (newSkillCount == existingSkillCount && newNotesLength > existingNotesLength) {
                    processedCharacters[key] = character
                }
            } else {
                // First time seeing this name/set combo
                processedCharacters[key] = character
            }
        }
        
        // Generate CSV content
        var csvString = "Name,Set,Notes,Skills\n"
        
        // Sort the unique characters alphabetically by name, then by set
        let uniqueCharacters = processedCharacters.values.sorted { char1, char2 in
            if char1.name.lowercased() != char2.name.lowercased() {
                return char1.name.lowercased() < char2.name.lowercased()
            } else {
                let set1 = char1.set?.lowercased() ?? ""
                let set2 = char2.set?.lowercased() ?? ""
                return set1 < set2
            }
        }
        
        // Process each unique character for CSV export
        for character in uniqueCharacters {
            // First clean up all whitespace in both name and set
            let cleanName = character.name.trimmingCharacters(in: .whitespacesAndNewlines)
                                         .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            
            // Capitalize the name properly for a character (Title Case)
            let nameWords = cleanName.split(separator: " ")
            let capitalizedName = nameWords.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined(separator: " ")
            
            // Clean up set and notes too
            let cleanSet = (character.set ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                                              .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            
            let cleanNotes = (character.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                                                  .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            
            // Escape quotes for CSV
            let name = capitalizedName.replacingOccurrences(of: "\"", with: "\"\"") 
            let set = cleanSet.replacingOccurrences(of: "\"", with: "\"\"") 
            let notes = cleanNotes.replacingOccurrences(of: "\"", with: "\"\"") 
            
            // Sort and normalize skill names
            let normalizedSkills = (character.skills ?? [])
                .sorted { $0.position < $1.position }
                .map { Skill.normalizeSkillName($0.name) }
                .joined(separator: ";")
                .replacingOccurrences(of: "\"", with: "\"\"") 
            
            let row = "\"\(name)\",\"\(set)\",\"\(notes)\",\"\(normalizedSkills)\""
            csvString.append(row + "\n")
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("characters.csv")
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true, completion: nil)
            }
        } catch {
            print("Export failed: \(error)")
            
            // Show error alert
            let alert = UIAlertController(
                title: "Export Failed",
                message: "Failed to export characters: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    private func exportSkills() {
        // Fetch all skills
        let skillsDescriptor = FetchDescriptor<Skill>(sortBy: [SortDescriptor(\.name)])
        
        do {
            let allSkills = try context.fetch(skillsDescriptor)
            
            if allSkills.isEmpty {
                // Show alert if no skills to export
                let alert = UIAlertController(
                    title: "No Skills",
                    message: "There are no skills to export.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(alert, animated: true)
                }
                return
            }
            
            // Dictionary to track processed skills by name (lowercase) to prevent duplicates
            var processedSkills: [String: Skill] = [:]
            
            // First pass - collect unique skills by lowercase name
            for skill in allSkills {
                // Clean up whitespace before normalization
                let trimmedName = skill.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanName = trimmedName.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                let lowerName = cleanName.lowercased()
                
                // If this lowercase name exists, keep the one with more information
                if let existingSkill = processedSkills[lowerName] {
                    // Choose the one with the most information
                    if skill.skillDescription.count > existingSkill.skillDescription.count {
                        processedSkills[lowerName] = skill
                    }
                } else {
                    // First time seeing this skill name
                    processedSkills[lowerName] = skill
                }
            }
            
            // Generate CSV content
            var csvString = "Name,Description\n"
            
            // Sort the unique skills alphabetically
            let uniqueSkills = processedSkills.values.sorted { $0.name.lowercased() < $1.name.lowercased() }
            
            for skill in uniqueSkills {
                // Use normalized name to ensure consistent capitalization
                let name = Skill.normalizeSkillName(skill.name).replacingOccurrences(of: "\"", with: "\"\"")
                
                // Clean up description whitespace
                let cleanDescription = skill.skillDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                                                            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                                                            .replacingOccurrences(of: "\"", with: "\"\"")
                
                let row = "\"\(name)\",\"\(cleanDescription)\""
                csvString.append(row + "\n")
            }
            
            // Write to temporary file
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("skills.csv")
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            
            // Show share sheet
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true, completion: nil)
            }
            
        } catch {
            print("Failed to export skills: \(error)")
            
            // Show error alert
            let alert = UIAlertController(
                title: "Export Failed",
                message: "Failed to export skills: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    // Static key to store the coordinator reference to prevent it from being deallocated
    private static var coordinatorKey = "com.actiontracker.skillImportCoordinatorKey"
    
    // Coordinator class for handling skill imports
    class SkillImportCoordinator: NSObject, UIDocumentPickerDelegate {
        private let modelContext: ModelContext
        
        init(modelContext: ModelContext) {
            self.modelContext = modelContext
            super.init()
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security-scoped resource.")
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                // Read the CSV file
                let content = try String(contentsOf: url, encoding: .utf8)
                let rows = content.components(separatedBy: CharacterSet.newlines).dropFirst() // Skip header
                
                var importedCount = 0
                var skippedCount = 0
                
                // Process each row
                for line in rows {
                    guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                    
                    // Parse the CSV line (assuming no commas in quoted values for simplicity)
                    let columns = parseCSVLine(line)
                    guard columns.count >= 2 else { continue }
                    
                    // Clean up name and description - trim spaces and normalize internal spacing
                    let rawName = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanName = rawName.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    
                    let rawDescription = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanDescription = rawDescription.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    
                    // Skip if empty name
                    if cleanName.isEmpty { continue }
                    
                    // Check if skill with the same name (case-insensitive) already exists
                    // First normalize the name using our helper
                    let normalizedName = Skill.normalizeSkillName(cleanName)
                    
                    // For predicate, we can only use exact matching without string functions
                    var skillDescriptor = FetchDescriptor<Skill>()
                    skillDescriptor.predicate = #Predicate<Skill> { skill in 
                        skill.name == normalizedName
                    }
                    
                    do {
                        let existingSkills = try modelContext.fetch(skillDescriptor)
                        
                        if existingSkills.isEmpty {
                            // Create new skill - Note: Skill initializer will normalize the name automatically
                            let newSkill = Skill(name: cleanName, skillDescription: cleanDescription, manual: true, importedFlag: true)
                            modelContext.insert(newSkill)
                            importedCount += 1
                        } else {
                            // Skill already exists, skip
                            skippedCount += 1
                            
                            // Optionally update description if the existing one is empty
                            if let existingSkill = existingSkills.first, existingSkill.skillDescription.isEmpty && !cleanDescription.isEmpty {
                                existingSkill.skillDescription = cleanDescription
                            }
                        }
                    } catch {
                        print("Error checking for existing skill: \(error)")
                    }
                }
                
                // Save changes
                try modelContext.save()
                
                // Show success alert
                DispatchQueue.main.async {
                    self.showResultAlert(imported: importedCount, skipped: skippedCount)
                }
                
            } catch {
                print("Import failed: \(error)")
                
                // Show error alert
                DispatchQueue.main.async {
                    self.showErrorAlert(error: error)
                }
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
        
        private func showResultAlert(imported: Int, skipped: Int) {
            let alert = UIAlertController(
                title: "Import Complete",
                message: "Successfully imported \(imported) new skills. \(skipped) existing skills were skipped.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
        
        private func showErrorAlert(error: Error) {
            let alert = UIAlertController(
                title: "Import Failed",
                message: "Failed to import skills: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    private func importSkills() {
        let alert = UIAlertController(
            title: "Import Skills",
            message: """
            Import will add new skills to your library.
            Existing skills with the same name will be skipped.
            
            Make sure your CSV has this format:
            
            Name,Description
            "+1 Die: Combat","Add 1 die to combat rolls"
            "Lucky","Re-roll one failed die per turn"
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.commaSeparatedText])
            documentPicker.allowsMultipleSelection = false
            
            // Using a coordinator for the document picker
            let coordinator = SkillImportCoordinator(modelContext: self.context)
            documentPicker.delegate = coordinator
            
            // Keep a reference to the coordinator to prevent it from being deallocated
            objc_setAssociatedObject(documentPicker, HeaderView.coordinatorKey, coordinator, .OBJC_ASSOCIATION_RETAIN)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(documentPicker, animated: true, completion: nil)
            }
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true, completion: nil)
        }
    }
    
    private func importCharacters() {
        // Configure with context and completion handler
        CustomContext.shared.configure(with: context) {
            // This will be called after successful import
            print("Import completed, refreshing view...")
            try? context.save()
        }
        
        let alert = UIAlertController(
            title: "Import Format",
            message: """
            Import will replace all existing characters.
            
            Make sure your CSV has this format:
            
            Name,Set,Notes,Skills
            "Dean Winchester","Supernatural","Some notes","Brother In Arms: Tough;Is That All You Got?;Taunt;+1 Free Ranged Action;Bloodlust: Melee;Regeneration"
            """,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.commaSeparatedText])
            documentPicker.allowsMultipleSelection = false
            documentPicker.delegate = CustomContext.shared
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(documentPicker, animated: true, completion: nil)
            }
        })
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true, completion: nil)
        }
        return
    }
    
    // Ensures that all skill names are consistently capitalized
    private func normalizeSkillNamesIfNeeded() {
        // Check if we've already normalized skill names this session
        let normalizedKey = "ActionTracker.skillsNormalizedThisSession"
        if UserDefaults.standard.bool(forKey: normalizedKey) {
            return  // Already normalized this session
        }
        
        // Fetch all skills
        let skillsDescriptor = FetchDescriptor<Skill>()
        
        do {
            let allSkills = try context.fetch(skillsDescriptor)
            var changesMade = false
            
            // Normalize each skill name
            for skill in allSkills {
                let currentName = skill.name
                let normalizedName = Skill.normalizeSkillName(currentName)
                
                // Check if the name needs normalization
                if currentName != normalizedName {
                    print("Normalizing skill name from '\(currentName)' to '\(normalizedName)'")
                    skill.name = normalizedName
                    changesMade = true
                }
            }
            
            // Save changes if needed
            if changesMade {
                try context.save()
                print("Successfully normalized skill names")
            }
            
            // Mark as normalized for this session
            UserDefaults.standard.set(true, forKey: normalizedKey)
        } catch {
            print("Error normalizing skill names: \(error)")
        }
    }
    
    // MARK: - Data Wiping Functions
    
    private func wipeAllCharacters() {
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Delete All Characters",
            message: "This will delete ALL characters in the database. Skills will remain but will be orphaned. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete All", style: .destructive) { _ in
            self.executeWipeAllCharacters()
        })
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    private func executeWipeAllCharacters() {
        do {
            // 1. Fetch all characters
            let allCharacters = try context.fetch(FetchDescriptor<Character>())
            
            // 2. Delete all characters
            for character in allCharacters {
                context.delete(character)
            }
            
            // 3. Save changes
            try context.save()
        } catch {
            print("Error wiping characters: \(error)")
            
            // Show error alert
            let alert = UIAlertController(
                title: "Error",
                message: "Failed to delete characters: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    private func wipeAllSkills() {
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Delete All Skills",
            message: "This will delete ALL skills in the database and remove them from all characters. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete All", style: .destructive) { _ in
            self.executeWipeAllSkills()
        })
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    private func executeWipeAllSkills() {
        do {
            // 1. First, clear skills from all characters
            for character in characters {
                character.skills = []
            }
            
            // 2. Fetch all skills
            let allSkills = try context.fetch(FetchDescriptor<Skill>())
            
            // 3. Delete all skills
            for skill in allSkills {
                context.delete(skill)
            }
            
            // 4. Save changes
            try context.save()
        } catch {
            print("Error wiping skills: \(error)")
            
            // Show error alert
            let alert = UIAlertController(
                title: "Error",
                message: "Failed to delete skills: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    private func wipeAllData() {
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Delete ALL Data",
            message: "This will delete ALL characters AND skills in the database. The database will be completely empty. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete Everything", style: .destructive) { _ in
            self.executeWipeAllData()
        })
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    private func executeWipeAllData() {
        do {
            // 1. First, delete all characters
            let allCharacters = try context.fetch(FetchDescriptor<Character>())
            for character in allCharacters {
                context.delete(character)
            }
            
            // 2. Then, delete all skills
            let allSkills = try context.fetch(FetchDescriptor<Skill>())
            for skill in allSkills {
                context.delete(skill)
            }
            
            // 3. Save changes
            try context.save()
        } catch {
            print("Error wiping all data: \(error)")
            
            // Show error alert
            let alert = UIAlertController(
                title: "Error",
                message: "Failed to delete all data: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
}

#Preview {
    ContentView()
}
