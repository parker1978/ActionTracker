//
//  AddCharacterView.swift
//  ZombicideCharacters
//
//  Created by Stephen Parker on 4/11/25.
//

import SwiftUI
import SwiftData
import Foundation

struct AddCharacterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode

    @State private var name: String = ""
    @State private var set: String = ""
    @State private var notes: String = ""
    @State private var isFavorite: Bool = false
    @State private var skillInputs: [(id: UUID, name: String, skillDescription: String, color: SkillColor, position: Int, showDescription: Bool)] = [(UUID(), "", "", .blue, 0, false)]
    @State private var showingValidationAlert = false
    @State private var errorMessage = ""
    @State private var isDragging = false
    @State private var editModeState: EditMode = .inactive
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
            _isFavorite = State(initialValue: character.isFavorite)
            
            // Get skills from the character, including duplicates, sorted by position
            if let skills = character.skills, !skills.isEmpty {
                // Convert skills to our tuple format
                let skillsData = skills.map { skill in
                    (
                        id: UUID(),                   // Unique ID for this skill input
                        name: skill.name,             // Skill name 
                        skillDescription: skill.skillDescription, // Description
                        color: skill.color ?? .blue,  // Default to blue if nil
                        position: skill.position,     // Preserve position
                        showDescription: false        // Start with descriptions hidden
                    )
                }.sorted { $0.position < $1.position } // Sort by position
                
                _skillInputs = State(initialValue: skillsData)
                
                // Print debug info
                print("CHARACTER INITIALIZATION")
                print("Found \(skills.count) skills for character \(character.name)")
                for skill in skillsData {
                    print("Loaded skill: \(skill.name) (Color: \(skill.color), Position: \(skill.position))")
                }
            } else {
                // Default empty skill if no skills found
                _skillInputs = State(initialValue: [(UUID(), "", "", .blue, 0, false)])
                print("No skills found for character \(character.name)")
            }
        } else {
            // Default single empty skill for new character
            _skillInputs = State(initialValue: [(UUID(), "", "", .blue, 0, false)])
            print("Creating new character with default empty skill")
        }
    }
    
    // Swift compiler requires this workaround for proper preview
    init() {
        self.character = nil
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
//                // DEBUG: show current editMode
//                Text("DEBUG editMode: \(String(describing: editMode?.wrappedValue))")
//                    .font(.caption2)
//                    .foregroundColor(.orange)
//                    .padding(.vertical, 4)
//                
                Form {
                    characterInfoSection
                    skillsSection
                }
                .navigationTitle(isEditing ? "Edit Character" : "Add Character")
                .navigationBarTitleDisplayMode(.inline)
                .keyboardToolbar(
                    onInsertText: { insertTextAtCursor($0) },
                    onDone: { focusField = nil }
                )
            }
            .toolbar {
                // Edit mode button in leading position
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                
                cancelButton
                saveButton
            }
            .environment(\.editMode, $editModeState)
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
                // Only set initial focus if we're adding a new character (not editing)
                if !isEditing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        focusField = .name
                    }
                }
                
                // Make sure positions are normalized when view appears
                normalizePositions()
            }
            .onChange(of: editModeState) { old, new in
                print("⚙️ editMode changed from \(old) to \(new)")
                if new == .inactive {
                  withAnimation { normalizePositions() }
                }
              }
            // log every change to the console
            .onChange(of: editMode?.wrappedValue, initial: false) { oldMode, newMode in
                print("⚙️ editMode changed from \(String(describing: oldMode)) to \(String(describing: newMode))")
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
                .textInputAutocapitalization(.never)
                .focused($focusField, equals: .notes)
                .submitLabel(.done)
                .onSubmit {
                    focusField = nil
                }
            
            Toggle(isOn: $isFavorite) {
                HStack {
                    Text("Favorite")
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }
                }
            }
        }
    }
    
    private var isEditModeEditing: Bool {
      editMode?.wrappedValue.isEditing == true
    }
    
    // MARK: Skills Section
    private var skillsSection: some View {
        Section {
            // All skills in one list, sorted by position
            ForEach(skillInputs.sorted(by: { $0.position < $1.position }), id: \.id) { skill in
                let index = skillInputs.firstIndex { $0.id == skill.id } ?? 0
                skillRow(for: index)
                    .id("\(skill.id)-\(isEditModeEditing)") // Force redraw when edit mode changes
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            withAnimation(.spring(duration: 0.3)) {
                                if index > 0 { // Prevent deleting the first skill
                                    removeSkill(at: index)
                                }
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .onMove(perform: moveSkill)
            
            // Add skill button
            addSkillButton
        } header: {
            Text("Skills")
        }
    }
    
    // Helper to get color based on skill color enum
    private func colorForSkill(_ skill: (id: UUID, name: String, skillDescription: String, color: SkillColor, position: Int, showDescription: Bool)) -> Color {
        switch skill.color {
        case .blue:
            return .skillBlue
        case .orange:
            return .skillOrange
        case .red:
            return .skillRed
        }
    }
    
    // Helper to determine if we're in edit mode
    private var isEditModeActive: Bool {
        return editMode?.wrappedValue == .active
    }
    
    // MARK: Skill Row
    @ViewBuilder
    private func skillRow(for index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Skill name field with dot indicator
            HStack {
                Circle()
                    .fill(colorForSkill(skillInputs[index]))
                    .frame(width: 8, height: 8)
                TextField("Skill Name", text: $skillInputs[index].name)
                    .textInputAutocapitalization(.words)
                    .focused($focusField, equals: .skillName(index))
                    .submitLabel(.done)
            }
            
            // ONLY include the picker while editing
            if editModeState == .active {
                Picker("Power Level", selection: $skillInputs[index].color) {
                    Text("Blue").tag(SkillColor.blue)
                    Text("Orange").tag(SkillColor.orange)
                    Text("Red").tag(SkillColor.red)
                }
                .pickerStyle(.segmented)
                .onChange(of: skillInputs[index].color) { _, newValue in
                    withAnimation { normalizePositionsByColor() }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.1), value: editModeState)
            }
        }
        .padding(.vertical, 2)
        .animation(.spring(duration: 0.3), value: editMode?.wrappedValue)
    }
    
    private var addSkillButton: some View {
        Button {
            withAnimation {
                // Find the highest position value and add 1
                let nextPosition = (skillInputs.map { $0.position }.max() ?? -1) + 1
                
                // Add the new skill
                skillInputs.append((UUID(), "", "", .blue, nextPosition, false))
                
                // Ensure positions are normalized
                normalizePositionsByColor()
                
                // Focus the new field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusField = .skillName(skillInputs.count - 1)
                }
            }
        } label: {
            HStack {
                Image(systemName: "plus.circle")
                    .foregroundColor(.blue)
                Text("Add Skill")
                    .foregroundColor(.blue)
            }
        }
        .disabled(editMode?.wrappedValue == .active) // Disable adding skills while in edit mode
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
    
    private func removeSkill(at index: Int) {
        if index < skillInputs.count {
            skillInputs.remove(at: index)
            normalizePositions()
        }
    }
    
    // Move skills within a color section
    private func moveSkillWithinSection(source: IndexSet, destination: Int, section: SkillColor) {
        // Get all skills of this color
        var skillsInSection = skillInputs.filter { $0.color == section }
        
        // Move the items within this filtered array
        skillsInSection.move(fromOffsets: source, toOffset: destination)
        
        // Update positions within this section
        for (index, skill) in skillsInSection.enumerated() {
            if let actualIndex = skillInputs.firstIndex(where: { $0.id == skill.id }) {
                // Find position based on the color
                var basePosition = 0
                
                if section == .orange {
                    basePosition = skillInputs.filter { $0.color == .blue }.count
                } else if section == .red {
                    basePosition = skillInputs.filter { $0.color == .blue }.count + 
                                  skillInputs.filter { $0.color == .orange }.count
                }
                
                // Set the new position
                withAnimation {
                    skillInputs[actualIndex].position = basePosition + index
                }
            }
        }
        
        // Normalize all positions to ensure consistency
        normalizePositionsByColor()
    }
    
    // Improved move skills function
    private func moveSkill(from source: IndexSet, to destination: Int) {
        // Get a sorted array of skills by position
        var sortedSkills = skillInputs.sorted(by: { $0.position < $1.position })
        
        // Move the items within this sorted array
        sortedSkills.move(fromOffsets: source, toOffset: destination)
        
        // Update all positions based on the new order
        for (newPosition, skill) in sortedSkills.enumerated() {
            if let index = skillInputs.firstIndex(where: { $0.id == skill.id }) {
                // Update position in the original array
                skillInputs[index].position = newPosition
                
                // Print for debugging
                print("Moved skill '\(skill.name)' to position \(newPosition)")
            }
        }
        
        // Force an immediate context save when in edit mode
        if editMode?.wrappedValue == .active {
            do {
                try context.save()
                print("Saved context after skill reordering")
            } catch {
                print("Failed to save context after reordering: \(error)")
            }
        }
    }
    
    // Simple position normalization (kept for compatibility)
    private func normalizePositions() {
        // Sort by current order in the array
        for i in 0..<skillInputs.count {
            skillInputs[i].position = i
        }
    }
    
    // Normalize positions by color group
    private func normalizePositionsByColor() {
        withAnimation(.spring(duration: 0.2)) {
            // Group skills by color
            let blueSkills = skillInputs.filter { $0.color == .blue }
                .sorted { $0.position < $1.position }
            let orangeSkills = skillInputs.filter { $0.color == .orange }
                .sorted { $0.position < $1.position }
            let redSkills = skillInputs.filter { $0.color == .red }
                .sorted { $0.position < $1.position }
            
            // Update positions by color group
            var currentPosition = 0
            
            // Process blue skills first
            for skill in blueSkills {
                if let index = skillInputs.firstIndex(where: { $0.id == skill.id }) {
                    skillInputs[index].position = currentPosition
                    currentPosition += 1
                }
            }
            
            // Then orange skills
            for skill in orangeSkills {
                if let index = skillInputs.firstIndex(where: { $0.id == skill.id }) {
                    skillInputs[index].position = currentPosition
                    currentPosition += 1
                }
            }
            
            // Finally red skills
            for skill in redSkills {
                if let index = skillInputs.firstIndex(where: { $0.id == skill.id }) {
                    skillInputs[index].position = currentPosition
                    currentPosition += 1
                }
            }
        }
    }
    
    private func saveCharacter() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Process skill inputs, cleaning names and preserving descriptions, colors, and positions
        let cleanedSkills = skillInputs
            .map { (name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines), 
                   skillDescription: $0.skillDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                   color: $0.color,
                   position: $0.position) }
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
        
        // Debug start - log save character
        print("SAVE CHARACTER - Saving \(cleanedSkills.count) skills:")
        for skill in cleanedSkills {
            print("- \(skill.name) (Color: \(skill.color), Position: \(skill.position))")
        }
        
        if let existingCharacter = character {
            // Update existing character basic info
            existingCharacter.name = trimmedName
            existingCharacter.set = trimmedSet
            existingCharacter.notes = trimmedNotes
            existingCharacter.isFavorite = isFavorite
            
            // SIMPLIFIED SKILL UPDATE - Don't try to reuse existing skills from the database
            // First, clear existing skills array to avoid duplicates
            if let existingSkills = existingCharacter.skills {
                print("Clearing \(existingSkills.count) existing skills")
                
                // Remove this character from each skill's characters array
                for skill in existingSkills {
                    skill.characters?.removeAll { $0.id == existingCharacter.id }
                }
                
                // Clear the character's skills array
                existingCharacter.skills?.removeAll()
            }
            
            // Now add all skills fresh
            for skillData in cleanedSkills {
                // Create a new skill with the cleaned data - ensure position is preserved
                let newSkill = Skill(
                    name: skillData.name,
                    skillDescription: skillData.skillDescription,
                    position: skillData.position,
                    manual: true,
                    color: skillData.color
                )
                
                // Debug position info
                print("Creating skill \(skillData.name) with position \(skillData.position)")
                
                // Insert the new skill
                context.insert(newSkill)
                
                // Initialize the characters array if needed
                if newSkill.characters == nil {
                    newSkill.characters = []
                }
                
                // Add this character to the skill's characters
                newSkill.characters?.append(existingCharacter)
                
                // Add the skill to the character's skills
                if existingCharacter.skills == nil {
                    existingCharacter.skills = []
                }
                
                existingCharacter.skills?.append(newSkill)
                
                print("Added new skill: \(newSkill.name) with position \(newSkill.position)")
            }
        } else {
            // Create new character
            let newCharacter = Character(
                name: trimmedName,
                set: trimmedSet,
                notes: trimmedNotes,
                isFavorite: isFavorite
            )
            context.insert(newCharacter)
            
            // Initialize the skills array
            newCharacter.skills = []
            
            // Add all skills
            for skillData in cleanedSkills {
                // Create a new skill with the cleaned data - ensure position is preserved
                let newSkill = Skill(
                    name: skillData.name,
                    skillDescription: skillData.skillDescription,
                    position: skillData.position,
                    manual: true,
                    color: skillData.color
                )
                
                // Debug position info
                print("Creating skill \(skillData.name) with position \(skillData.position)")
                
                // Insert the new skill
                context.insert(newSkill)
                
                // Initialize the characters array
                newSkill.characters = [newCharacter]
                
                // Add the skill to character's skills
                newCharacter.skills?.append(newSkill)
                
                print("Added new skill: \(newSkill.name) with position \(newSkill.position)")
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
