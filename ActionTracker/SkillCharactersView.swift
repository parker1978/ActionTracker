//
//  SkillCharactersView.swift
//  ActionTracker
//

import SwiftUI
import SwiftData

struct SkillCharactersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allCharacters: [Character]

    let skill: Skill

    var charactersWithSkill: [Character] {
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

    var body: some View {
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
    }
}

struct CharacterSkillRowView: View {
    let character: Character
    let skillTiers: [SkillTier]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if character.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }

                Text(character.name)
                    .font(.headline)
            }

            Text(character.set)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Tier badges
            if !skillTiers.isEmpty {
                HStack(spacing: 6) {
                    ForEach(skillTiers) { tier in
                        Text(tier.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(tier.color)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

enum SkillTier: String, Identifiable {
    case blue
    case orange
    case red

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .orange: return .orange
        case .red: return .red
        }
    }
}

#Preview {
    NavigationStack {
        SkillCharactersView(skill: Skill(name: "+1 Free Action: Move", skillDescription: "Once per Turn, perform a Move Action for free."))
            .modelContainer(for: [Character.self], inMemory: true)
    }
}
