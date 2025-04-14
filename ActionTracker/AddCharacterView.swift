//
//  AddCharacterView.swift
//  ZombicideCharacters
//
//  Created by Stephen Parker on 4/11/25.
//

import SwiftUI
import SwiftData

struct AddCharacterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name: String = ""
    @State private var set: String = ""
    @State private var notes: String = ""
    @State private var skillInputs: [String] = [""]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Character Name", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Set (optional)", text: $set)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Notes (optional)", text: $notes)
                        .textInputAutocapitalization(.words)
                }

                Section("Skills") {
                    ForEach(0..<skillInputs.count, id: \.self) { index in
                        TextField("Skill \(index + 1)", text: Binding(
                            get: { skillInputs[index] },
                            set: { skillInputs[index] = $0 }
                        ))
                        .textInputAutocapitalization(.words)
                    }

                    Button("Add Another Skill") {
                        skillInputs.append("")
                    }
                }
            }
            .navigationTitle("Add Character")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let cleanedSkills = skillInputs
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }

                        guard !name.isEmpty, !cleanedSkills.isEmpty else { return }

                        let newCharacter = Character(
                            name: name,
                            set: set.isEmpty ? nil : set,
                            allSkills: cleanedSkills,
                            notes: notes.isEmpty ? nil : notes
                        )
                        context.insert(newCharacter)
                        dismiss()
                    }
                }
            }
        }
    }
}
