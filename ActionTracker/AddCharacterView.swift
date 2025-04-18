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
    @State private var showingValidationAlert = false
    @State private var errorMessage = ""
    @FocusState private var focusField: Field?
    
    var character: Character?
    
    enum Field: Hashable {
        case name
        case set
        case notes
        case skill(Int)
    }
    
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        !skillInputs.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.isEmpty
    }
    
    var isEditing: Bool {
        character != nil
    }
    
    init(character: Character? = nil) {
        self.character = character
        
        if let character = character {
            _name = State(initialValue: character.name)
            _set = State(initialValue: character.set ?? "")
            _notes = State(initialValue: character.notes ?? "")
            _skillInputs = State(initialValue: character.allSkills.isEmpty ? [""] : character.allSkills)
        }
    }
    
    // Swift compiler requires this workaround for proper preview
    init() {
        self.character = nil
    }
    
    var body: some View {
        Form {
            characterInfoSection
            skillsSection
        }
        .navigationTitle(isEditing ? "Edit Character" : "Add Character")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            keyboardToolbar
            cancelButton
            saveButton
        }
        .alert("Missing Information", isPresented: $showingValidationAlert) {
            Button("OK") {
                if errorMessage.contains("name") {
                    focusField = .name
                } else {
                    focusField = .skill(0)
                }
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusField = .name
            }
        }
    }
    
    // MARK: - View Components
    
    private var characterInfoSection: some View {
        Section("Name") {
            TextField("Character Name", text: $name)
                .textInputAutocapitalization(.words)
                .focused($focusField, equals: .name)
                .submitLabel(.next)
                .onSubmit {
                    focusField = .set
                }
            
            TextField("Set (optional)", text: $set)
                .textInputAutocapitalization(.words)
                .focused($focusField, equals: .set)
                .submitLabel(.next)
                .onSubmit {
                    focusField = .notes
                }
            
            TextField("Notes (optional)", text: $notes)
                .textInputAutocapitalization(.words)
                .focused($focusField, equals: .notes)
                .submitLabel(.done)
                .onSubmit {
                    focusField = nil
                }
        }
    }
    
    private var skillsSection: some View {
        Section("Skills") {
            ForEach(0..<skillInputs.count, id: \.self) { index in
                skillRow(for: index)
            }

            addSkillButton
        }
    }
    
    private func skillRow(for index: Int) -> some View {
        HStack {
            TextField("Skill \(index + 1)", text: Binding(
                get: { skillInputs[index] },
                set: { skillInputs[index] = $0 }
            ))
            .textInputAutocapitalization(.words)
            .focused($focusField, equals: .skill(index))
            .submitLabel(index == skillInputs.count - 1 ? .done : .next)
            .onSubmit {
                handleSkillSubmit(at: index)
            }
            
            if index > 0 {
                Button {
                    withAnimation {
                        removeSkill(at: index)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private var addSkillButton: some View {
        Button {
            withAnimation {
                skillInputs.append("")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusField = .skill(skillInputs.count - 1)
                }
            }
        } label: {
            Label("Add Another Skill", systemImage: "plus.circle")
        }
    }
    
    private var keyboardToolbar: some ToolbarContent {
        Group {
            // +1 button on the left
            ToolbarItem(placement: .keyboard) {
                Button("+1") {
                    insertTextAtCursor("+1 ")
                }
            }
            
            // Colon button on the left center
            ToolbarItem(placement: .keyboard) {
                Button(":") {
                    insertTextAtCursor(": ")
                }
            }
            
            // Spacer to push Done button to the right
            ToolbarItem(placement: .keyboard) {
                Spacer()
            }
            
            // Done button on the right
            ToolbarItem(placement: .keyboard) {
                Button("Done") {
                    focusField = nil
                }
            }
        }
    }
    
    // Helper method to insert text at the cursor position
    private func insertTextAtCursor(_ text: String) {
        // Determine which field has focus and insert text there
        if let field = focusField {
            switch field {
            case .name:
                name.append(text)
            case .set:
                set.append(text)
            case .notes:
                notes.append(text)
            case .skill(let index):
                if index < skillInputs.count {
                    skillInputs[index].append(text)
                }
            }
        }
    }
    
    private var cancelButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
        }
    }
    
    private var saveButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                saveCharacter()
            }
            .disabled(!canSave)
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleSkillSubmit(at index: Int) {
        if index == skillInputs.count - 1 {
            skillInputs.append("")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusField = .skill(index + 1)
            }
        } else {
            focusField = .skill(index + 1)
        }
    }
    
    private func removeSkill(at index: Int) {
        if index < skillInputs.count {
            skillInputs.remove(at: index)
        }
    }
    
    private func saveCharacter() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedSkills = skillInputs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if trimmedName.isEmpty {
            errorMessage = "Please enter a character name"
            showingValidationAlert = true
            return
        }
        
        if cleanedSkills.isEmpty {
            errorMessage = "Please add at least one skill"
            showingValidationAlert = true
            return
        }
        
        let trimmedSet = set.isEmpty ? nil : set.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let existingCharacter = character {
            // Update existing character
            existingCharacter.name = trimmedName
            existingCharacter.set = trimmedSet
            existingCharacter.allSkills = cleanedSkills
            existingCharacter.notes = trimmedNotes
        } else {
            // Create new character
            let newCharacter = Character(
                name: trimmedName,
                set: trimmedSet,
                allSkills: cleanedSkills,
                notes: trimmedNotes
            )
            context.insert(newCharacter)
        }
        
        dismiss()
    }
}

#Preview {
    NavigationStack {
        AddCharacterView()
    }
}