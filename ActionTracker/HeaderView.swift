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
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.largeTitle)
                    .padding()
            }
        }
        .padding(.horizontal)
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
        CustomContext.configure(with: context)
        
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
}

#Preview {
    ContentView()
}
