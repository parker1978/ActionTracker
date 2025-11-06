import SwiftUI
import SwiftData
import CoreDomain
import SharedUI

struct CharacterDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var character: Character

    // Edit mode state
    @State private var isEditing = false
    @State private var showDeleteAlert = false
    @State private var showCancelAlert = false

    // Temporary edit state
    @State private var editedName = ""
    @State private var editedSet = ""
    @State private var editedNotes = ""
    @State private var editedBlueSkills: [String] = []
    @State private var editedOrangeSkills: [String] = []
    @State private var editedRedSkills: [String] = []

    var body: some View {
        List {
            // MARK: - Character Info Section
            Section {
                // Name field (editable for custom characters only)
                if isEditing && !character.isBuiltIn {
                    HStack {
                        Text("Name")
                            .foregroundStyle(.secondary)
                        TextField("Character Name", text: $editedName)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // Set field (read-only for user-created characters)
                HStack {
                    Text("Set")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(character.set.isEmpty ? "Core" : character.set)
                }

                // Favorite toggle (always enabled, even when not editing)
                Toggle("Favorite", isOn: $character.isFavorite)
                    .onChange(of: character.isFavorite) {
                        character.updatedAt = Date()
                        try? modelContext.save()
                    }
            }

            // MARK: - Skills Section
            if isEditing && !character.isBuiltIn {
                // Edit mode for custom characters - show all tiers
                SkillEditSection(
                    title: "Blue Skills",
                    skills: $editedBlueSkills,
                    color: .blue,
                    colorTier: "Blue"
                )

                SkillEditSection(
                    title: "Orange Skills",
                    skills: $editedOrangeSkills,
                    color: .orange,
                    colorTier: "Orange"
                )

                SkillEditSection(
                    title: "Red Skills",
                    skills: $editedRedSkills,
                    color: .red,
                    colorTier: "Red"
                )
            } else {
                // View mode - show only non-empty skill tiers
                if !character.blueSkillsList.isEmpty {
                    SkillTierSection(
                        title: "Blue Skills",
                        skills: character.blueSkillsList,
                        color: .blue
                    )
                }

                if !character.orangeSkillsList.isEmpty {
                    SkillTierSection(
                        title: "Orange Skills",
                        skills: character.orangeSkillsList,
                        color: .orange
                    )
                }

                if !character.redSkillsList.isEmpty {
                    SkillTierSection(
                        title: "Red Skills",
                        skills: character.redSkillsList,
                        color: .red
                    )
                }
            }

            // MARK: - Notes Section (at bottom)
            Section("Notes") {
                if isEditing {
                    TextEditor(text: $editedNotes)
                        .frame(minHeight: 100)
                } else {
                    if !character.notes.isEmpty {
                        Text(character.notes)
                    } else {
                        Text("No notes")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(isEditing ? editedName : character.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            // Delete button (only for custom characters)
            if !character.isBuiltIn && !isEditing {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            // Cancel button (when editing)
            if isEditing {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasChanges() {
                            showCancelAlert = true
                        } else {
                            cancelEditing()
                        }
                    }
                }
            }

            // Edit/Done button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        saveChanges()
                    } else {
                        startEditing()
                    }
                }
            }
        }
        .alert("Delete Character?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteCharacter()
            }
        } message: {
            Text("This will permanently delete \(character.name). This action cannot be undone.")
        }
        .alert("Discard Changes?", isPresented: $showCancelAlert) {
            Button("Keep Editing", role: .cancel) { }
            Button("Discard", role: .destructive) {
                cancelEditing()
            }
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
    }

    // MARK: - Helper Functions

    private func startEditing() {
        editedName = character.name
        editedSet = character.set
        editedNotes = character.notes
        editedBlueSkills = character.blueSkillsList
        editedOrangeSkills = character.orangeSkillsList
        editedRedSkills = character.redSkillsList
        isEditing = true
    }

    private func saveChanges() {
        // Only update fields if character is custom (not built-in)
        if !character.isBuiltIn {
            character.name = editedName.trimmingCharacters(in: .whitespaces)
            // Note: Set is not editable for user-created characters
            character.blueSkills = editedBlueSkills.joined(separator: "; ")
            character.orangeSkills = editedOrangeSkills.joined(separator: "; ")
            character.redSkills = editedRedSkills.joined(separator: "; ")
        }

        // Notes are editable for all characters
        character.notes = editedNotes.trimmingCharacters(in: .whitespaces)
        character.updatedAt = Date()

        do {
            try modelContext.save()
        } catch {
            print("Error saving character: \(error)")
        }

        isEditing = false
    }

    private func cancelEditing() {
        isEditing = false
        // State will be reset when entering edit mode again
    }

    private func hasChanges() -> Bool {
        if character.isBuiltIn {
            // For built-in characters, only notes can change
            return editedNotes.trimmingCharacters(in: .whitespaces) != character.notes
        } else {
            // For custom characters, check all fields except set (which is not editable)
            return editedName.trimmingCharacters(in: .whitespaces) != character.name ||
                   editedNotes.trimmingCharacters(in: .whitespaces) != character.notes ||
                   editedBlueSkills != character.blueSkillsList ||
                   editedOrangeSkills != character.orangeSkillsList ||
                   editedRedSkills != character.redSkillsList
        }
    }

    private func deleteCharacter() {
        modelContext.delete(character)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Skill Edit Section Component (for editing mode)

struct SkillEditSection: View {
    let title: String
    @Binding var skills: [String]
    let color: Color
    let colorTier: String
    @Query private var allSkills: [Skill]

    @State private var showSkillPicker = false

    var body: some View {
        Section {
            ForEach(skills, id: \.self) { skillName in
                HStack {
                    Circle()
                        .fill(color.gradient)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(skillName)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        // Show skill description if available
                        if let skill = allSkills.first(where: { $0.name == skillName }),
                           !skill.skillDescription.isEmpty {
                            Text(skill.skillDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button(role: .destructive) {
                        withAnimation {
                            skills.removeAll { $0 == skillName }
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }

            Button {
                showSkillPicker = true
            } label: {
                Label("Add Skill", systemImage: "plus.circle.fill")
            }
        } header: {
            Text(title)
        }
        .sheet(isPresented: $showSkillPicker) {
            SkillPickerView(
                currentSkills: skills,
                colorTier: colorTier,
                allSkills: allSkills,
                onSelect: { skillName in
                    withAnimation {
                        skills.append(skillName)
                    }
                }
            )
        }
    }
}

// MARK: - Skill Tier Section Component (for viewing mode)

struct SkillTierSection: View {
    let title: String
    let skills: [String]
    let color: Color
    @Query private var allSkills: [Skill]

    var body: some View {
        Section {
            ForEach(skills, id: \.self) { skillName in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(color.gradient)
                            .frame(width: 8, height: 8)

                        Text(skillName)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()
                    }

                    // Show skill description if available
                    if let skill = allSkills.first(where: { $0.name == skillName }),
                       !skill.skillDescription.isEmpty {
                        Text(skill.skillDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 16)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text(title)
        }
    }
}

#Preview {
    let character = Character(
        name: "Amy",
        blueSkills: "+1 Free Action: Move",
        orangeSkills: "+1 Free Action: Melee;+1 Free Action: Ranged",
        redSkills: "+1 Die: Combat;+1 To Dice Roll: Combat;Medic"
    )
    return NavigationStack {
        CharacterDetailView(character: character)
    }
}
