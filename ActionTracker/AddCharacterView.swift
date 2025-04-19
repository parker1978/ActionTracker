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
    @State private var skillInputs: [(name: String, skillDescription: String)] = [("", "")]
    @State private var showingValidationAlert = false
    @State private var errorMessage = ""
    @FocusState private var focusField: Field?
    
    var character: Character?
    
    enum Field: Hashable {
        case name
        case set
        case notes
        case skillName(Int)
        case skillDesc(Int)
    }
    
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        !skillInputs.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.isEmpty
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
            
            // Get skills from the character, sorted by position
            let sortedSkills = (character.skills ?? []).sorted { $0.position < $1.position }
            _skillInputs = State(initialValue: sortedSkills.isEmpty ? [("", "")] : sortedSkills.map { ($0.name, $0.skillDescription) })
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
                    focusField = .skillName(0)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Skill \(index + 1)", text: Binding(
                    get: { skillInputs[index].name },
                    set: { skillInputs[index].name = $0 }
                ))
                .textInputAutocapitalization(.words)
                .focused($focusField, equals: .skillName(index))
                .submitLabel(.next)
                .onSubmit {
                    focusField = .skillDesc(index)
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
            
            TextField("Description (optional)", text: Binding(
                get: { skillInputs[index].skillDescription },
                set: { skillInputs[index].skillDescription = $0 }
            ))
            .textInputAutocapitalization(.sentences)
            .font(.caption)
            .focused($focusField, equals: .skillDesc(index))
            .submitLabel(index == skillInputs.count - 1 ? .done : .next)
            .onSubmit {
                handleSkillSubmit(at: index)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var addSkillButton: some View {
        Button {
            withAnimation {
                skillInputs.append(("", ""))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusField = .skillName(skillInputs.count - 1)
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
            case .skillName(let index):
                if index < skillInputs.count {
                    skillInputs[index].name.append(text)
                }
            case .skillDesc(let index):
                if index < skillInputs.count {
                    skillInputs[index].skillDescription.append(text)
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
            skillInputs.append(("", ""))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusField = .skillName(index + 1)
            }
        } else {
            focusField = .skillName(index + 1)
        }
    }
    
    private func removeSkill(at index: Int) {
        if index < skillInputs.count {
            skillInputs.remove(at: index)
        }
    }
    
    private func saveCharacter() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Process skill inputs, cleaning names and preserving descriptions
        let cleanedSkills = skillInputs
            .map { (name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines), 
                   skillDescription: $0.skillDescription.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.name.isEmpty }
        
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
            existingCharacter.notes = trimmedNotes
            
            // Get new skill names to determine what to keep
            let newSkillNames = cleanedSkills.map { $0.name }
            let newSkillsSet = Set(newSkillNames)
            
            // Create dictionary to store existing skills by name
            var skillsByName: [String: Skill] = [:]
            for skill in (existingCharacter.skills ?? []) {
                skillsByName[skill.name] = skill
            }
            
            // Create skills array if nil
            if existingCharacter.skills == nil {
                existingCharacter.skills = []
            }
            
            // Remove skills that are no longer in the list
            existingCharacter.skills?.removeAll { !newSkillsSet.contains($0.name) }
            
            // Add or update skills
            for (index, skillData) in cleanedSkills.enumerated() {
                let skillName = skillData.name
                let skillDescription = skillData.skillDescription
                
                if let existingSkill = skillsByName[skillName] {
                    // Update the position of the existing skill
                    existingSkill.position = index
                    
                    // Only update description if it's not empty and the existing one is empty
                    if !skillDescription.isEmpty && existingSkill.skillDescription.isEmpty {
                        existingSkill.skillDescription = skillDescription
                    }
                } else {
                    // Check if the skill already exists in the database (case-insensitive)
                    // First normalize the name
                    let normalizedSkillName = Skill.normalizeSkillName(skillName)
                    
                    // For predicate, we can only use exact matching without string functions
                    var skillDescriptor = FetchDescriptor<Skill>()
                    skillDescriptor.predicate = #Predicate<Skill> { skill in 
                        skill.name == normalizedSkillName
                    }
                    var skill: Skill
                    
                    do {
                        // Try to find the skill in the database
                        if let existingSkill = try context.fetch(skillDescriptor).first {
                            skill = existingSkill
                            
                            // Update description if provided and existing is empty
                            if !skillDescription.isEmpty && existingSkill.skillDescription.isEmpty {
                                existingSkill.skillDescription = skillDescription
                            }
                        } else {
                            // Create a new skill if it doesn't exist
                            skill = Skill(name: skillName, skillDescription: skillDescription, position: index, manual: true)
                            context.insert(skill)
                        }
                        
                        // Add the skill to the character
                        if skill.characters == nil {
                            skill.characters = []
                        }
                        skill.characters?.append(existingCharacter)
                        existingCharacter.skills?.append(skill)
                    } catch {
                        print("Error fetching or creating skill: \(error)")
                        // Create a new skill anyway if there was an error
                        skill = Skill(name: skillName, skillDescription: skillDescription, position: index, manual: true)
                        context.insert(skill)
                        if skill.characters == nil {
                            skill.characters = []
                        }
                        skill.characters?.append(existingCharacter)
                        existingCharacter.skills?.append(skill)
                    }
                }
            }
        } else {
            // Create new character
            let newCharacter = Character(
                name: trimmedName,
                set: trimmedSet,
                notes: trimmedNotes
            )
            context.insert(newCharacter)
            
            // Initialize skills array if needed
            if newCharacter.skills == nil {
                newCharacter.skills = []
            }
            
            // Create or reference skills
            for (index, skillData) in cleanedSkills.enumerated() {
                let skillName = skillData.name
                let skillDescription = skillData.skillDescription
                
                // Check if the skill already exists in the database (case-insensitive)
                // First normalize the name
                let normalizedSkillName = Skill.normalizeSkillName(skillName)
                
                // For predicate, we can only use exact matching without string functions
                var skillDescriptor = FetchDescriptor<Skill>()
                skillDescriptor.predicate = #Predicate<Skill> { skill in 
                    skill.name == normalizedSkillName
                }
                var skill: Skill
                
                do {
                    // Try to find the skill in the database
                    if let existingSkill = try context.fetch(skillDescriptor).first {
                        skill = existingSkill
                        
                        // Update description if provided and existing is empty
                        if !skillDescription.isEmpty && existingSkill.skillDescription.isEmpty {
                            existingSkill.skillDescription = skillDescription
                        }
                    } else {
                        // Create a new skill if it doesn't exist
                        skill = Skill(name: skillName, skillDescription: skillDescription, position: index, manual: true)
                        context.insert(skill)
                    }
                    
                    // Initialize characters array if needed
                    if skill.characters == nil {
                        skill.characters = []
                    }
                    
                    // Add the skill to the character
                    skill.characters?.append(newCharacter)
                    newCharacter.skills?.append(skill)
                } catch {
                    print("Error fetching or creating skill: \(error)")
                    // Create a new skill anyway if there was an error
                    skill = Skill(name: skillName, skillDescription: skillDescription, position: index, manual: true)
                    context.insert(skill)
                    if skill.characters == nil {
                        skill.characters = []
                    }
                    skill.characters?.append(newCharacter)
                    newCharacter.skills?.append(skill)
                }
            }
        }
        
        // Try to save changes to persist the data
        do {
            try context.save()
            print("Successfully saved character data")
        } catch {
            print("Failed to save character data: \(error)")
        }
        
        dismiss()
    }
}

#Preview {
    NavigationStack {
        AddCharacterView()
    }
}