//
//  SkillCharactersView.swift
//  SkillsFeature
//

import SwiftUI
import SwiftData
import CoreDomain
import SharedUI

public struct SkillCharactersView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allCharacters: [CoreDomain.Character]

    let skill: Skill

    @State private var showDeleteAlert = false

    public init(skill: Skill) {
        self.skill = skill
    }

    var charactersWithSkill: [CoreDomain.Character] {
        allCharacters.filter { character in
            character.allSkillsList.contains(skill.name)
        }.sorted { c1, c2 in
            // Sort by favorite first, then alphabetically
            if c1.isFavorite == c2.isFavorite {
                return c1.name < c2.name
            }
            return c1.isFavorite && !c2.isFavorite
        }
    }

    func skillTiers(for character: Character) -> [SkillTier] {
        var tiers: [SkillTier] = []

        if character.blueSkillsList.contains(skill.name) {
            tiers.append(.blue)
        }
        if character.orangeSkillsList.contains(skill.name) {
            tiers.append(.orange)
        }
        if character.redSkillsList.contains(skill.name) {
            tiers.append(.red)
        }

        return tiers
    }

    public var body: some View {
        Group {
            if charactersWithSkill.isEmpty {
                ContentUnavailableView {
                    Label("No Characters Found", systemImage: "person.slash")
                } description: {
                    Text("No characters have the '\(skill.name)' skill")
                } actions: {
                    // Optional: Could add a button to navigate to add character
                }
            } else {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(skill.name)
                                .font(.title3)
                                .fontWeight(.semibold)

                            Text(skill.skillDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }

                    Section {
                        ForEach(charactersWithSkill) { character in
                            NavigationLink {
                                CharacterDetailView(character: character)
                            } label: {
                                CharacterSkillRowView(
                                    character: character,
                                    skillTiers: skillTiers(for: character)
                                )
                            }
                        }
                    } header: {
                        Text("\(charactersWithSkill.count) \(charactersWithSkill.count == 1 ? "Character" : "Characters")")
                    }
                }
            }
        }
        .navigationTitle("Characters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !skill.isBuiltIn {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .alert("Delete Skill?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSkill()
            }
        } message: {
            Text(deleteAlertMessage)
        }
    }

    private var deleteAlertMessage: String {
        let count = charactersWithSkill.count
        if count == 0 {
            return "This skill is not used by any characters."
        } else if count == 1 {
            return "This skill is used by 1 character: \(charactersWithSkill[0].name). It will be removed from this character."
        } else if count <= 5 {
            let names = charactersWithSkill.map { $0.name }.joined(separator: ", ")
            return "This skill is used by \(count) characters: \(names). It will be removed from all of them."
        } else {
            let firstFive = charactersWithSkill.prefix(5).map { $0.name }.joined(separator: ", ")
            return "This skill is used by \(count) characters including: \(firstFive), and \(count - 5) more. It will be removed from all of them."
        }
    }

    private func deleteSkill() {
        // Remove skill from all characters that have it
        for character in charactersWithSkill {
            // Remove from blue skills
            if character.blueSkillsList.contains(skill.name) {
                let updatedSkills = character.blueSkillsList.filter { $0 != skill.name }
                character.blueSkills = updatedSkills.joined(separator: ";")
            }

            // Remove from yellow skills
            if character.yellowSkillsList.contains(skill.name) {
                let updatedSkills = character.yellowSkillsList.filter { $0 != skill.name }
                character.yellowSkills = updatedSkills.joined(separator: ";")
            }

            // Remove from orange skills
            if character.orangeSkillsList.contains(skill.name) {
                let updatedSkills = character.orangeSkillsList.filter { $0 != skill.name }
                character.orangeSkills = updatedSkills.joined(separator: ";")
            }

            // Remove from red skills
            if character.redSkillsList.contains(skill.name) {
                let updatedSkills = character.redSkillsList.filter { $0 != skill.name }
                character.redSkills = updatedSkills.joined(separator: ";")
            }
        }

        // Delete the skill
        modelContext.delete(skill)

        // Save changes
        do {
            try modelContext.save()
        } catch {
            print("Error deleting skill: \(error)")
        }

        // Dismiss the view
        dismiss()
    }
}

#Preview {
    NavigationStack {
        SkillCharactersView(skill: Skill(name: "+1 Free Action: Move", skillDescription: "Once per Turn, perform a Move Action for free."))
            .modelContainer(for: [Character.self], inMemory: true)
    }
}
