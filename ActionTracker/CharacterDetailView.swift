import SwiftUI
import SwiftData

struct CharacterDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var character: Character

    var body: some View {
        List {
            // MARK: - Character Info Section
            Section {
                HStack {
                    Text("Set")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(character.set.isEmpty ? "Core" : character.set)
                }

                if !character.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(character.notes)
                    }
                }

                Toggle("Favorite", isOn: $character.isFavorite)
                    .onChange(of: character.isFavorite) {
                        character.updatedAt = Date()
                        try? modelContext.save()
                    }
            }

            // MARK: - Skills Section
            if !character.blueSkillsList.isEmpty {
                SkillTierSection(
                    title: "Blue Skills (XP 0-6)",
                    skills: character.blueSkillsList,
                    color: .blue
                )
            }

            if !character.orangeSkillsList.isEmpty {
                SkillTierSection(
                    title: "Orange Skills (XP 7-18)",
                    skills: character.orangeSkillsList,
                    color: .orange
                )
            }

            if !character.redSkillsList.isEmpty {
                SkillTierSection(
                    title: "Red Skills (XP 19-42)",
                    skills: character.redSkillsList,
                    color: .red
                )
            }
        }
        .navigationTitle(character.name)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Skill Tier Section Component

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
