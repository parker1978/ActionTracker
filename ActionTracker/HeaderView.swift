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
                        exportCharacters()
                    } label: {
                        Text("Export Characters")
                        Image(systemName: "square.and.arrow.up.fill")
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
        .sheet(isPresented: $showingSkillLibrary) {
            SkillView()
        }
    }
    
    private func exportCharacters() {
        var csvString = "Name,Set,Notes,Skills\n"
        for character in characters {
            let name = character.name.replacingOccurrences(of: "\"", with: "\"\"") 
            let set = (character.set ?? "").replacingOccurrences(of: "\"", with: "\"\"") 
            let notes = (character.notes ?? "").replacingOccurrences(of: "\"", with: "\"\"") 
            let skills = (character.skills ?? []).sorted { $0.position < $1.position }.map { $0.name }.joined(separator: ";").replacingOccurrences(of: "\"", with: "\"\"") 
            let row = "\"\(name)\",\"\(set)\",\"\(notes)\",\"\(skills)\""
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
