//
//  CharacterListView.swift
//  ZombicideCharacters
//
//  Created by Stephen Parker on 4/11/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct CharacterListView: View {
    @Query(sort: \Character.name) var characters: [Character]
    @Environment(\.modelContext) private var context
    @State private var searchText = ""
    @State private var isShowingAddCharacter = false
    @State private var addWiggle: Bool = false

    var filteredCharacters: [Character] {
        guard !searchText.isEmpty else { return characters }
        return characters.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.allSkills.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Navigation link to skill search
                NavigationLink(destination: SkillSearchView()) {
                    Label("Search by Skills", systemImage: "magnifyingglass")
                }

                // Main list of characters
                ForEach(filteredCharacters) { character in
                    VStack(alignment: .leading) {
                        Text(character.set?.isEmpty == false ? "\(character.name) (\(character.set!))" : character.name)
                            .font(.headline)
                        Text(character.allSkills.joined(separator: ", ")).font(.caption)
                    }
                }
            }
            .navigationTitle("Characters")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddCharacter = true
                        addWiggle.toggle()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolEffect(.wiggle, value: addWiggle)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Import Characters") {
                            importCharacters()
                        }
                        Button("Export Characters") {
                            exportCharacters()
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .searchable(text: $searchText)
            .modifier(CharacterSeeder())
        }
        .sheet(isPresented: $isShowingAddCharacter) {
            AddCharacterView()
        }
    }

    private func exportCharacters() {
        var csvString = "Name,Set,Notes,Skills\n"
        for character in characters {
            let name = character.name.replacingOccurrences(of: "\"", with: "\"\"")
            let set = (character.set ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let notes = (character.notes ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let skills = character.allSkills.joined(separator: ";").replacingOccurrences(of: "\"", with: "\"\"")
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
        Context.configure(with: context)
        
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
            documentPicker.delegate = Context.shared
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
}

#Preview {
    ContentView()
}
